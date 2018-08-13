package main

import (
	"encoding/json"
	"math/big"
	"net/http"

	log "github.com/thinkboy/log4go"
)

type HttpHandler struct {
	contract *Contract
	db       *DBHandler
	account  *AccountCenter
}

func NewHttpHandler() *HttpHandler {
	db, err := NewDBHandler(gconf.MysqlDSN)
	if err != nil {
		panic(err)
	}
	return &HttpHandler{
		contract: NewContract(gconf.WalletApiUrl, gconf.ServiceID, gconf.Key, gconf.ContractAddr),
		account:  NewAccountCenter(),
		db:       db,
	}
}

// 准备提交订单交易数据
func (h *HttpHandler) handlePrepareSetOrder(w http.ResponseWriter, r *http.Request) {
	reqByte, err := ReadHttpRequest(r)
	if err != nil {
		log.Error("readHttpRequest err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	var postOrderReq PostOrderRequest
	if err := json.Unmarshal(reqByte, postOrderReq); err != nil {
		log.Error("json.Unmarshal err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	//检验SessionID
	if err := h.account.CheckAccess(postOrderReq.SessionID, UserAdmin); err != nil {
		log.Error("h.account.CheckAccess err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	//生成订单ID
	orderid := new(big.Int)
	orderid.SetString(NewOrderID(), 0)
	postOrderReq.OrderID = orderid

	// 打包交易
	txData, err := h.contract.PrepareTxSetOrder(&postOrderReq)
	if err != nil {
		log.Error("h.contract.PrepareTxSetOrder err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	// 获取PrepayId,打包交易
	tx, err := h.contract.jsonrpc.PackTx(txData)
	if err != nil {
		log.Error("h.contract.jsonrpc.PackTx err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	// 订单数据保存到数据库
	if err := h.db.InsertOrderInfo(&postOrderReq); err != nil {
		log.Error("h.db.SubmitOrder err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}
	// 返回已打包交易数据
	WriteHttpResponse(w, 0, "", tx)
}

// 查看订单
func (h *HttpHandler) handleQueryOrder(w http.ResponseWriter, r *http.Request) {
	reqByte, err := ReadHttpRequest(r)
	if err != nil {
		log.Error("readHttpRequest err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	var queryOrderReq QueryOrderRequest
	if err := json.Unmarshal(reqByte, queryOrderReq); err != nil {
		log.Error("json.Unmarshal err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	//检验SessionID
	if err := h.account.CheckAccess(queryOrderReq.SessionID, UserNormal); err != nil {
		log.Error("h.account.CheckAccess err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	var orderRes QueryOrderResponse
	orderID := queryOrderReq.OrderID

	// 查询订单信息
	orderInfo, err := h.contract.QueryOrderInfo(&queryOrderReq)
	if err != nil {
		log.Error("h.contract.QueryOrderInfo err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}
	orderItems := make([]*OrderItem, 0, orderInfo.Length)

	//查看订单项详情
	for i := 0; i < orderInfo.Length; i++ {
		orderItem, err := h.contract.QueryOrderItem(orderID, i)
		if err != nil {
			log.Error("h.contract.QueryOrderItem err:v", err)
			WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
			return
		}
		orderItems = append(orderItems, orderItem)
	}

	orderRes.OrderID = orderID
	orderRes.OrderPayer = orderInfo.Payer
	orderRes.OrderItems = orderItems

	//返回订单数据
	WriteHttpResponse(w, 0, "", orderRes)
}

// 查看商品
func (h *HttpHandler) handleQueryProduct(w http.ResponseWriter, r *http.Request) {
	reqByte, err := ReadHttpRequest(r)
	if err != nil {
		log.Error("readHttpRequest err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	var queryProductReq QueryProductRequest
	if err := json.Unmarshal(reqByte, queryProductReq); err != nil {
		log.Error("json.Unmarshal err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	//检验SessionID
	if err := h.account.CheckAccess(queryProductReq.SessionID, USER_NORMAL); err != nil {
		log.Error("h.account.CheckAccess err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	productID := queryProductReq.ProductID

	// 查询商品信息
	product, err := h.contract.QueryProduct(productID)
	if err != nil {
		log.Error("h.contract.QueryProduct err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	res := &QueryProductResponse{product}
	//返回商品数据
	WriteHttpResponse(w, 0, "", res)
}

// 准备设置商品交易数据
func (h *HttpHandler) handlePrepareSetProduct(w http.ResponseWriter, r *http.Request) {
	reqByte, err := ReadHttpRequest(r)
	if err != nil {
		log.Error("readHttpRequest err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	var setProductReq SetProductRequest
	if err := json.Unmarshal(reqByte, setProductReq); err != nil {
		log.Error("json.Unmarshal err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	//检验SessionID
	if err := h.account.CheckAccess(setProductReq.SessionID, USER_ADMIN); err != nil {
		log.Error("h.account.CheckAccess err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	product := setProductReq.Product

	//生成商品ID
	product.ID, _ = h.db.NewProductID()
	product.Status = 1

	//
	txData, err := h.contract.PrepareTxSetProduct(product)
	if err != nil {
		log.Error("h.contract.PrepareTxSetProduct err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	// 获取PrepayId,打包交易
	tx, err := h.contract.jsonrpc.PackTx(txData)
	if err != nil {
		log.Error("h.contract.jsonrpc.PackTx err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}

	// 商品数据保存到数据库
	if err := h.db.InsertProductInfo(product); err != nil {
		log.Error("h.db.InsertProductInfo err:%v", err)
		WriteHttpResponse(w, ERR_SYSTEM, err.Error(), nil)
		return
	}
	// 返回已打包交易数据
	WriteHttpResponse(w, 0, "", tx)
}

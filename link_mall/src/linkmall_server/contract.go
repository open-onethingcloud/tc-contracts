// 智能合约参数编码文档 http://solidity-cn.readthedocs.io/zh/develop/abi-spec.html#id3

package main

import (
	"encoding/hex"
	"fmt"
	"strconv"
	"strings"
)

const (
	FUNCHASH_SET_ORDER       = "1c444f3b" // setOrder(uint256,uint256[],uint16[])
	FUNCHASH_SET_SIMPLEORDER = "aeb4e305" // setSampleOrder(uint256,uint256,uint16)
	FUNCHASH_GET_ORDER       = "d09ef241" // getOrder(uint256)
	FUNCHASH_GET_ORDER_ITEM  = "215b7105" // getOrderItem(uint256,uint256)
	FUNCHASH_SET_PRODUCT     = "454ec581" // setProduct(uint256,bytes32,uint256,uint8)
	FUNCHASH_GET_PRODUCT     = "b9db15b4" // getProduct(uint256)

	ORDER_MAX_PRODUCT = 100        // 每个订单最多允许的商品种数
	ORDER_MAX_COUNT   = 65535      // 每个商品单个订单最多允许买多少个
	PRODUCT_MAX_PRICE = 10000000.0 // 最高允许的商品单价
)

type Contract struct {
	jsonrpc *JsonRPC
	addr    string
}

func NewContract(jsonrpcAddr string, serviceID int, key, contractAddr string) *Contract {
	return &Contract{
		jsonrpc: NewJsonRPC(jsonrpcAddr, serviceID, key),
		addr:    contractAddr,
	}
}

// 合约调用SetOrder, Transaction预处理
func (c *Contract) PrepareTxSetOrder(order *PostOrderRequest) (*Transaction, error) {
	itemCount := len(order.Items)
	if itemCount > ORDER_MAX_PRODUCT {
		return nil, ErrOrderTooManyProduct
	}

	param2pos := 3 * 32
	param3pos := param2pos + (1+itemCount)*32
	var param2, param3 string
	var value float64

	for _, item := range order.Items {
		if item.ProductCount > ORDER_MAX_COUNT {
			return nil, ErrOrderTooMuchInQuantity
		}
		param2 = param2 + fmt.Sprintf("%064x", item.ProductID)
		param3 = param3 + fmt.Sprintf("%064x", item.ProductCount)
		value += item.ProductPrice * float64(item.ProductCount)
	}
	ether := NewEther(value)

	data := fmt.Sprintf("0x%s%064s%064x%064x%064x%s%064x%s",
		FUNCHASH_SET_ORDER, order.OrderID.Text(16), param2pos,
		param3pos, itemCount, param2, itemCount, param3)

	trans := Transaction{
		To:    c.addr,
		Value: fmt.Sprintf("0x%s", ether.String()),
		Data:  data,
	}

	gas, err := c.jsonrpc.EstimateGas(&trans)
	if err != nil {
		return nil, err
	}
	trans.Gas = fmt.Sprintf("0x%x", gas+10000)

	return &trans, nil
}

// 合约调用SetProduct, Transaction预处理
func (c *Contract) PrepareTxSetProduct(product *Product) (*Transaction, error) {
	name := hex.EncodeToString([]byte(product.Name))
	if len(name) > 64 {
		return nil, ErrProductNameTooLong
	}
	if product.Price > PRODUCT_MAX_PRICE {
		return nil, ErrProductTooExpensive
	}

	// 检查精度
	priceStr := fmt.Sprintf("%v", product.Price)
	if strings.Contains(priceStr, ".") {
		suffix := strings.Split(priceStr, ".")[1]
		if len(suffix) > 8 {
			return nil, ErrProductPriceError
		}
	}
	// Data字段编码
	ether := NewEther(product.Price)
	data := fmt.Sprintf("0x%s%064x%064s%064s%064x", FUNCHASH_SET_PRODUCT, product.ID, name, ether.String(), 1)
	trans := Transaction{To: c.addr, Data: data}

	// 估算手续费
	gas, err := c.jsonrpc.EstimateGas(&trans)
	if err != nil {
		return nil, err
	}
	trans.Gas = fmt.Sprintf("0x%x", gas+1000)

	return &trans, nil

}

func (c *Contract) QueryProduct(id int64) (*Product, error) {
	data := fmt.Sprintf("0x%s%064x", FUNCHASH_GET_PRODUCT, id)
	trans := Transaction{To: c.addr, Data: data}
	rep, err := c.jsonrpc.Call(&trans, "latest")
	if err != nil {
		return nil, err
	}

	var product Product
	result := rep.Result.(string)

	if len(result) < 194 {
		return nil, ErrContractError
	}

	status, err := strconv.ParseUint(result[130:194], 16, 8)
	if err != nil {
		return nil, err
	}
	if status == 0 {
		return nil, ErrProductNotExist
	}
	product.Status = int64(status)

	product.ID = id

	name, err := hex.DecodeString(result[2:66])
	if err != nil {
		return nil, err
	}
	product.Name = strings.TrimFunc(string(name), func(r rune) bool {
		return r == 0
	})

	ether := new(Ether)
	if err := ether.Parse(result[66:130]); err != nil {
		return nil, err
	}
	product.Price = ether.Value()

	return &product, nil
}

func (c *Contract) QueryOrderInfo(order *QueryOrderRequest) (*OrderInfo, error) {
	orderInfo := &OrderInfo{}
	var buyer string
	var itemCount uint64

	data := fmt.Sprintf("0x%s%064s", FUNCHASH_GET_ORDER, order.OrderID)
	trans := Transaction{To: c.addr, Data: data}
	rep, err := c.jsonrpc.Call(&trans, "latest")
	if err != nil {
		return orderInfo, err
	}

	result := rep.Result.(string)
	if len(result) < 130 {
		return nil, ErrContractError
	}

	addr := strings.TrimLeft(result[2:66], "0")
	buyer = fmt.Sprintf("0x%040s", addr)
	if itemCount, err = strconv.ParseUint(result[66:130], 16, 64); err != nil {
		return nil, err
	}

	if itemCount == 0 {
		return nil, ErrOrderNotExist
	}
	orderInfo.Payer = buyer
	orderInfo.Length = int(itemCount)
	return orderInfo, nil
}

func (c *Contract) QueryOrderItem(orderid string, index int) (*OrderItem, error) {

	data := fmt.Sprintf("0x%s%064s%064x", FUNCHASH_GET_ORDER_ITEM, orderid, index)
	trans := Transaction{To: c.addr, Data: data}
	rep, err := c.jsonrpc.Call(&trans, "latest")
	if err != nil {
		return nil, err
	}

	var item OrderItem
	result := rep.Result.(string)
	if len(result) < 194 {
		return nil, ErrContractError
	}

	if item.ProductID, err = strconv.ParseInt(result[2:66], 16, 64); err != nil {
		return nil, err
	}

	ether := new(Ether)
	if err := ether.Parse(result[66:130]); err != nil {
		return nil, err
	}
	item.ProductPrice = ether.Value()

	if item.ProductCount, err = strconv.ParseInt(result[130:194], 10, 64); err != nil {
		return nil, err
	}
	return &item, nil
}

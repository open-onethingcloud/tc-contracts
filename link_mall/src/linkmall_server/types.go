package main

import (
	"math/big"
)

type PostOrderRequest struct {
	UserID    int64       `json:"user_id"`     //用户ID
	SessionID string      `json:"session_id"`  //session_id
	OrderID   *big.Int    `json:"-"`           //订单ID
	Items     []OrderItem `json:"order_items"` //商品
}

type OrderInfo struct {
	ID     string
	Payer  string
	Length int
}

type QueryOrderRequest struct {
	UserID    int64  `json:"user_id"`    //用户ID
	SessionID string `json:"session_id"` //session_id
	OrderID   string `json:"order_id"`   //订单ID
}

type QueryProductRequest struct {
	UserID    int64  `json:"user_id"`    //用户ID
	SessionID string `json:"session_id"` //session_id
	ProductID int64  `json:"product_id"` //商品ID
}

type QueryProductResponse struct {
	Product *Product `json:"product"` //商品
}

type QueryOrderResponse struct {
	OrderID    string       `json:"order_id"`    //订单ID
	OrderPayer string       `json:"order_payer"` //订单付款方钱包地址
	OrderItems []*OrderItem `json:"order_items"` //订单项
}

type OrderItem struct {
	ProductID    int64   `json:"product_id"`    //商品ID
	ProductPrice float64 `json:"product_price"` //商品价格
	ProductCount int64   `json:"product_count"` //商品数量
}

type Product struct {
	ID     int64   `json:"id"`
	Name   string  `json:"name"`
	Price  float64 `json:"price"`
	Status int64   `json:"-"`
}

type SetProductRequest struct {
	UserID    int64    `json:"user_id"`    //用户ID
	SessionID string   `json:"session_id"` //session_id
	Product   *Product `json:"product"`    //商品信息
}

type TxData struct {
	Desc     string `json:"desc"`               //合约执行描述，必须带上“合约执行-”前缀
	Callback string `json:"callback,omitempty"` //做url编码，后台回调链接
	To       string `json:"to"`                 //转出钱包地址
	Value    string `json:"value"`              //玩客币数量（单位 wei）
	//OrderID   string `json:"order_id"`           //服务号(向后台获取)
	PrePayID  string `json:"prepay_id"`  //预支付订单号
	ServiceID int    `json:"service_id"` //业务id，找交易中心申请service_id和签名秘钥(向后台获取) 预留字段(app提交到geth 时转化为整形)
	Data      string `json:"data"`       //执行的合约代码，十六进制字符串，以0x开头。包含函数地址和调用参数。只发起转账，这 个内容为空
	GasLimit  int64  `json:"gas_limit"`  //最大的支付Gas，用于计算合约执行手续费 (app提交到geth时转化为整形)
	TxType    string `json:"tx_type"`    //交易类型，取值contract标识合约，第三方交易tx_third，第三方交易支持缺失默认值，兼容 已有的客户端
	Sign      string `json:"sign"`       //交易签名 sign=md5(sha512(callback=xxx&prepay_id=xxx&service_id=xxx&to=xxx&value=xxx&key=私钥))
}

type Transaction struct {
	From     string `json:"from,omitempty"`
	To       string `json:"to,omitempty"`
	Gas      string `json:"gas,omitempty"`
	GasPrice string `json:"gasPrice,omitempty"`
	Value    string `json:"value,omitempty"`
	Data     string `json:"data,omitempty"`
	Nonce    string `json:"nonce,omitempty"`
}

type PayStatus struct {
	From   string  `json:"from"`
	To     string  `json:"to"`
	Value  float64 `json:"value"`
	Status int     `json:"status"`
	Time   string  `json:"ctime"`
}

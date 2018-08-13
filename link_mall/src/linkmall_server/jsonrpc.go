package main

import (
	"bytes"
	"crypto/md5"
	"crypto/sha512"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"math/big"
	"net"
	"net/http"
	"strconv"
	"time"

	log "github.com/thinkboy/log4go"
)

type Request struct {
	ID      uint        `json:"id"`
	Version string      `json:"jsonrpc"`
	Method  string      `json:"method"`
	Params  interface{} `json:"params"`
}

type Response struct {
	ID      uint        `json:"id"`
	Version string      `json:"jsonrpc"`
	Result  interface{} `json:"result"`
	Error   struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

type JsonRPC struct {
	Http *http.Client
	ID   uint

	Url       string
	ServiceID int
	Key       string
	fromIndex int

	CallbackUrl string
	PrePaySign  string
}

const (
	DEFAULT_GAS_PRICE   = "0x174876e800"
	DEFAULT_FROM_PREFIX = "0x19e9de19d4759ee8e0a54f9ee1551f18d2" // 0x19e9de19d4759ee8e0a54f9ee1551f18d2269895 调eth_call和eth_estimateGas时用
)

func NewJsonRPC(url string, serviceID int, key string) *JsonRPC {
	client := &http.Client{
		Transport: &http.Transport{
			Proxy: http.ProxyFromEnvironment,
			DialContext: (&net.Dialer{
				Timeout:   30 * time.Second,
				KeepAlive: 30 * time.Second,
			}).DialContext,
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 100,
			IdleConnTimeout:     time.Duration(90) * time.Second,
		},
		Timeout: 20 * time.Second,
	}
	return &JsonRPC{
		Http:      client,
		Url:       url,
		ServiceID: serviceID,
		Key:       key,
	}
}

func NewRequest(method string, params ...interface{}) *Request {
	return &Request{0, "2.0", method, params}
}

func (rpc *JsonRPC) Invoke(url string, req *Request) (*Response, error) {
	req.ID = rpc.ID
	rpc.ID++

	data, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}
	log.Trace(string(data))

	request, err := http.NewRequest("POST", rpc.Url+url, bytes.NewReader(data))
	if err != nil {
		log.Error("create http request failed: ", err)
		return nil, err
	}
	request.Header.Set("Content-Type", "application/json")

	resp, err := rpc.Http.Do(request)
	if err != nil {
		log.Error("POST failed: ", err)
		return nil, err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Error("read http response failed: ", err)
		return nil, err
	}
	log.Trace(string(body))

	var rep Response
	err = json.Unmarshal(body, &rep)
	if err != nil {
		return nil, err
	}

	if rep.Error.Code != 0 {
		return nil, errors.New(rep.Error.Message)
	}

	return &rep, nil
}

func (rpc *JsonRPC) Call(trans *Transaction, extra string) (*Response, error) {
	if trans.From == "" {
		trans.From = rpc.GetDefaultFrom()
	}
	req := NewRequest("eth_call", trans, extra)
	return rpc.Invoke("/call", req)
}

func (rpc *JsonRPC) EstimateGas(trans *Transaction) (uint64, error) {
	if trans.From == "" {
		trans.From = rpc.GetDefaultFrom()
	}
	if trans.GasPrice == "" {
		trans.GasPrice = DEFAULT_GAS_PRICE
	}
	req := NewRequest("eth_estimateGas", trans)
	rep, err := rpc.Invoke("/estimateGas", req)
	if err != nil {
		return 0, err
	}
	if gas, err := strconv.ParseUint(rep.Result.(string), 0, 64); err != nil {
		return 0, err
	} else {
		return gas, nil
	}
}

func (rpc *JsonRPC) GetDefaultFrom() string {
	rpc.fromIndex++
	if rpc.fromIndex > 999999 {
		rpc.fromIndex = 1
	}
	return fmt.Sprintf("%s%06d", DEFAULT_FROM_PREFIX, rpc.fromIndex)
}

func (rpc *JsonRPC) GetPrePaySign() string {
	if rpc.PrePaySign == "" {
		str := fmt.Sprintf("service_id=%d&key=%s", rpc.ServiceID, rpc.Key)
		step1 := sha512.Sum512([]byte(str))
		step2 := hex.EncodeToString(step1[:])
		step3 := md5.Sum([]byte(step2))
		rpc.PrePaySign = hex.EncodeToString(step3[:])
	}
	return rpc.PrePaySign
}

func (rpc *JsonRPC) GetPrePayID() (string, error) {
	params := make(map[string]interface{})
	params["service_id"] = rpc.ServiceID
	params["sign"] = rpc.GetPrePaySign()

	data := make(map[string]interface{})
	data["jsonrpc"] = "2.0"
	data["method"] = "getPrepayId"
	data["params"] = params

	buffer, err := json.Marshal(data)
	if err != nil {
		return "", err
	}
	log.Trace(string(buffer))

	req, err := http.NewRequest("POST", fmt.Sprintf("%s/getPrepayId", rpc.Url), bytes.NewReader(buffer))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := rpc.Http.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	log.Trace(string(body))

	result := make(map[string]interface{})
	err = json.Unmarshal(body, &result)
	if err != nil {
		return "", err
	}
	if result["iRet"].(float64) != 0 {
		return "", errors.New(fmt.Sprintf("%v, %v", result["sMsg"], result["data"]))
	}
	rdata := result["data"].(map[string]interface{})
	return rdata["prepay_id"].(string), nil
}

func (rpc *JsonRPC) GetSign(prepayid string, to string, value *big.Int) string {
	str := fmt.Sprintf("callback=%s&prepay_id=%s&service_id=%d&to=%s&value=%s&key=%s",
		rpc.CallbackUrl, prepayid, rpc.ServiceID, to, value.Text(10), rpc.Key)
	step1 := sha512.Sum512([]byte(str))
	step2 := hex.EncodeToString(step1[:])
	step3 := md5.Sum([]byte(step2))
	return hex.EncodeToString(step3[:])
}

func (rpc *JsonRPC) PackTx(trans *Transaction) (*TxData, error) {
	value := new(big.Int)
	value.SetString(trans.Value, 0)
	gas, _ := strconv.ParseInt(trans.Gas, 0, 64)

	prepayid, err := rpc.GetPrePayID()
	if err != nil {
		return nil, err
	}
	sign := rpc.GetSign(prepayid, trans.To, value)

	var txdata TxData
	txdata.Desc = "合约执行-链克商城"
	txdata.Callback = rpc.CallbackUrl
	txdata.To = trans.To
	txdata.Value = value.Text(10)
	//txdata.OrderID = orderid
	txdata.PrePayID = prepayid
	txdata.ServiceID = rpc.ServiceID
	txdata.Data = trans.Data
	txdata.GasLimit = gas
	txdata.TxType = "contract"
	txdata.Sign = sign

	return &txdata, nil
}

func (rpc *JsonRPC) Callback(w http.ResponseWriter, r *http.Request) {
	var code int
	var message string

	if r.Method != "POST" {
		code = -1
		message = "support post only"
	} else {
		prepayid := r.PostFormValue("prepay_id")
		from := r.PostFormValue("from")
		to := r.PostFormValue("to")
		value := r.PostFormValue("value")
		status := r.PostFormValue("status") // 订单状态，1成功
		timestamp := r.PostFormValue("timestamp")
		sign := r.PostFormValue("sign")

		str := fmt.Sprintf("from=%s&prepay_id=%s&status=%s&timestamp=%s&to=%s&value=%s&key=%s", from, prepayid, status, timestamp, to, value, rpc.Key)
		step1 := sha512.Sum512([]byte(str))
		step2 := hex.EncodeToString(step1[:])
		step3 := md5.Sum([]byte(step2))
		sign1 := hex.EncodeToString(step3[:])

		if sign != sign1 {
			code = -1
			message = "sign error"
		} else {
			// TODO
			//log.Info("prepay_id: %s, to: %s, status: %s", prepayid, to, status)
			code = 0
			message = "ok"
		}
	}

	log.Debug("callback message: ", message)
	str := fmt.Sprintf("return_code=%d&return_msg=%s", code, message)
	w.Write([]byte(str))
}

package main

import (
	"fmt"
	"math/big"
	"math/rand"
	"strconv"
	"strings"
	"time"
)

var (
	_WEI1 = float64(1e8)
	_WEI2 = big.NewInt(1e10)
)

// 只做标价用，ether精确到小数点后8位
type Ether struct {
	Wei *big.Int
}

func NewEther(v float64) *Ether {
	step1 := v * _WEI1
	step2 := fmt.Sprintf("%.0f", step1)
	step3, _ := strconv.ParseInt(step2, 10, 64)
	step4 := big.NewInt(step3)
	step4.Mul(step4, _WEI2)
	return &Ether{step4}
}

func (ether *Ether) Parse(w string) error {
	wei := new(big.Int)
	if !strings.HasPrefix(w, "0x") {
		w = "0x" + w
	}
	_, err := fmt.Sscan(w, wei)
	if err != nil {
		return err
	}
	ether.Wei = wei
	return nil
}

func (ether *Ether) Value() float64 {
	value := new(big.Int)
	value.Div(ether.Wei, _WEI2)
	return float64(value.Int64()) / _WEI1
}

func (ether *Ether) String() string {
	return ether.Wei.Text(16)
}

func NewOrderID() string {
	nowtime := time.Now()
	id := nowtime.Format("20060102150405")
	rand_num := rand.Int31n(99999)
	order_id := fmt.Sprintf("1%s%05v", id, rand_num)
	return order_id
}

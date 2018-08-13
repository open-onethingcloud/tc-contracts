package main

import (
	"encoding/json"
	"io/ioutil"
	"net"
	"net/http"
	"time"

	"github.com/codegangsta/negroni"
	log "github.com/thinkboy/log4go"
)

var (
	h *HttpHandler
)

func StartHttpServer() error {

	h = NewHttpHandler()

	httpServeMux := http.NewServeMux()
	httpServeMux.HandleFunc("/order/prepare_set", h.handlePrepareSetOrder)
	httpServeMux.HandleFunc("/order/query", h.handleQueryOrder)
	httpServeMux.HandleFunc("/product/prepare_set", h.handlePrepareSetProduct)
	httpServeMux.HandleFunc("/product/query", h.handleQueryProduct)

	n := negroni.New()
	n.Use(negroni.HandlerFunc(logMiddleware))
	n.Use(negroni.HandlerFunc(checkMethodMiddleware))
	n.UseHandler(httpServeMux)
	go httpListen(n)

	return nil
}

func httpListen(h http.Handler) {
	httpServer := &http.Server{
		Handler:      h,
		ReadTimeout:  time.Duration(gconf.HTTPReadTimeout),
		WriteTimeout: time.Duration(gconf.HTTPWriteTimeout),
	}
	httpServer.SetKeepAlivesEnabled(true)
	l, err := net.Listen("tcp", gconf.HttpAddr)
	if err != nil {
		log.Error("net.Listen err:%v", err)
		panic(err)
	}
	if err := httpServer.Serve(l); err != nil {
		log.Error("server.Serve err:%v", err)
		panic(err)
	}
}

type HttpReply struct {
	IRet int         `json:"iRet"`
	SMsg string      `json:"sMsg"`
	Data interface{} `json:"data"`
}

func WriteHttpResponse(w http.ResponseWriter, IRet int, SMsg string, Data interface{}) []byte {
	var ret HttpReply
	ret.IRet = IRet
	ret.SMsg = SMsg
	if Data != nil {
		ret.Data = Data
	}
	retBytes, err := json.Marshal(ret)
	if err != nil {
		ret.Data = nil
		retBytes, err = json.Marshal(ret)
		if err != nil {
			log.Error("json marshal err:%v", err)
		}
	}
	w.Write(retBytes)
	return retBytes
}

func ReadHttpRequest(r *http.Request) ([]byte, error) {
	defer r.Body.Close()
	content, err := ioutil.ReadAll(r.Body)
	if err != nil {
		return nil, err
	}
	return content, nil
}

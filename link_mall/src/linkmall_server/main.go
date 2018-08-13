package main

import (
	"flag"

	log "github.com/thinkboy/log4go"
)

var (
	flgConfFile = flag.String("conf", "../conf/server.conf", "linkmall service config file")
)

func init() {
	flag.Parse()
}

func main() {
	flag.Parse()
	if err := InitConfig(*flgConfFile); err != nil {
		panic(err)
	}

	log.LoadConfiguration(gconf.Log)
	defer log.Close()

	log.Info("server start...")
	if err := StartHttpServer(); err != nil {
		log.Error("start http server err:%v", err)
		return
	}
	InitSignal()
}

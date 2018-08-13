package main

import (
	"os"
	"os/signal"
	"syscall"

	log "github.com/thinkboy/log4go"
)

func InitSignal() {
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGHUP, syscall.SIGQUIT, syscall.SIGTERM, syscall.SIGINT, syscall.SIGSTOP)
	for {
		s := <-c
		log.Info("server get a signal %s", s.String())
		switch s {
		case syscall.SIGQUIT, syscall.SIGTERM, syscall.SIGSTOP, syscall.SIGINT:
			return
		case syscall.SIGHUP:
			if err := ReloadConfig(*flgConfFile); err != nil {
				log.Error("reload config err:%v", err)
			}
		default:
			return
		}
	}
}

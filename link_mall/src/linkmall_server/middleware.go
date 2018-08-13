package main

import (
	"net/http"
	"time"

	log "github.com/thinkboy/log4go"
)

func logMiddleware(w http.ResponseWriter, r *http.Request, next http.HandlerFunc) {
	start := time.Now()
	next(w, r)
	log.Info("[%dms] %-10s", time.Since(start).Nanoseconds()/1e6, r.URL)
}

func checkMethodMiddleware(w http.ResponseWriter, r *http.Request, next http.HandlerFunc) {
	if r.Method != "POST" {
		WriteHttpResponse(w, ERR_SYSTEM, ErrMethod.Error(), nil)
		return
	}
	next(w, r)
}

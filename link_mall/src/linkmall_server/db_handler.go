package main

import (
	"database/sql"
	"time"

	_ "github.com/go-sql-driver/mysql"
	log "github.com/thinkboy/log4go"
)

type DBHandler struct {
	productid int64
	db        *sql.DB
}

func NewDBHandler(mysql_dsn string) (*DBHandler, error) {
	db, err := sql.Open("mysql", mysql_dsn)
	if err != nil {
		log.Error("sql.Open(%s) error(%v)", mysql_dsn, err)
		//return nil, err
	}
	db.SetMaxIdleConns(500)
	db.SetMaxOpenConns(500)
	db.SetConnMaxLifetime(300 * time.Second)
	if err := db.Ping(); err != nil {
		log.Error("db.Ping err:%v, mysql_dsn:%s", err, mysql_dsn)
		//return nil, err
	}
	return &DBHandler{
		db: db,
	}, nil
}

func (h *DBHandler) InsertOrderInfo(order *PostOrderRequest) error {
	// TODO: handle InsertOrderInfo
	// ...
	return nil
}

func (h *DBHandler) InsertProductInfo(product *Product) error {
	// TODO: handle InsertProductInfo
	// ...
	return nil
}

func (h *DBHandler) NewProductID() (int64, error) {
	// TODO: handle NewProductID
	// ...

	//only for test
	h.productid += 1
	return h.productid, nil
}

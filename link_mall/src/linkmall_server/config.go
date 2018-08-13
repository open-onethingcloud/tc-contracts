package main

import (
	"encoding/json"
	"io/ioutil"

	log "github.com/thinkboy/log4go"
)

var (
	gconf *Config
)

// define service config
type Config struct {
	Log              string `json:"log"`                //服务日志文件目录
	HttpAddr         string `json:"http_addr"`          //服务地址 IP:PORT
	HTTPReadTimeout  int    `json:"http_read_timeout"`  //服务读超时时间 单位：秒
	HTTPWriteTimeout int    `json:"http_write_timeout"` //服务写超时时间 单位：秒

	//service_id, key通过注册迅雷链开放平台获取
	ServiceID int    `json:"service_id"` // service_id
	Key       string `json:"key"`        // key

	ContractAddr string `json:"contract_addr"`  //链克商城合约地址
	WalletApiUrl string `json:"wallet_api_url"` //迅雷链开放平台URL

	MysqlDSN string `json:"mysql_dsn"` //MYSQL DSN
}

// init config while starting service
func InitConfig(configFile string) error {
	conf := new(Config)
	content, err := ioutil.ReadFile(configFile)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(content, conf); err != nil {
		return err
	}
	gconf = conf
	return nil
}

// reload config when config file updated
func ReloadConfig(configFile string) error {
	err := InitConfig(configFile)
	if err != nil {
		return err
	}
	configJson, err := json.Marshal(gconf)
	if err != nil {
		return err
	}
	log.Info("reload config %s", configJson)
	return nil
}

package main

import (
	"errors"
)

var (
	ErrSystem                 = errors.New("error system")
	ErrOrderTooManyProduct    = errors.New("error order too many product")
	ErrOrderTooMuchInQuantity = errors.New("error order too much in quantity")
	ErrOrderNotExist          = errors.New("error order not exist")
	ErrContractError          = errors.New("error contract error")
	ErrMethod                 = errors.New("error method")
	ErrProductNameTooLong     = errors.New("error product name too long")
	ErrProductTooExpensive    = errors.New("error product too expensive")
	ErrProductPriceError      = errors.New("error product price error")
	ErrProductNotExist        = errors.New("error product not exist")

	ERR_SYSTEM = -99
)

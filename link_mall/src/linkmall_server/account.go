package main

const (
	// user role
	UserNormal = 0
	UserAdmin  = 1
)

// account manage center
type AccountCenter struct {
}

// new an account manage center instance
func NewAccountCenter() *AccountCenter {
	return &AccountCenter{}
}

// check user access while requesting
func (ac *AccountCenter) CheckAccess(sessionid string, role int) error {
	// TODO: handle check access
	// ...
	return nil
}

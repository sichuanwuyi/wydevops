package global

import (
	"go-demo/config"

	"github.com/spf13/viper"
)

type Application struct {
	ConfigViper *viper.Viper
	Config      config.Configuration
}

var App = new(Application)

package config

type Configuration struct {
	App App `mapstructure:"app" json:"app" yaml:"app"`
}

type App struct {
	Env     string `mapstructure: "env" json:"env" yaml:"env"`
	Port    string `mapstructure: "port" json:"port" yaml:"port"`
	AppName string `mapstructure: "appName" json:"appName" yaml:"appName"`
	AppUrl  string `mapstructure: "appUrl" json:"appUrl" yaml:"appUrl"`
}

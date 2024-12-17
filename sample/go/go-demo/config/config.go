package config

type Configuration struct {
	App App `mapstructure:"app" json:"app" yaml:"app"`
}

type Mysql struct {
	Host      string `mapstructure: "host" json:"host" yaml:"host"`
	Username  string `mapstructure: "username" json:"username" yaml:"username"`
	Password  string `mapstructure: "password" json:"password" yaml:"password"`
}

type App struct {
	Env     string `mapstructure: "env" json:"env" yaml:"env"`
	Port    string `mapstructure: "port" json:"port" yaml:"port"`
	AppName string `mapstructure: "appName" json:"appName" yaml:"appName"`
	AppUrl  string `mapstructure: "appUrl" json:"appUrl" yaml:"appUrl"`
    ApiUrlPrefix  string `mapstructure: "apiUrlPrefix" json:"apiUrlPrefix" yaml:"apiUrlPrefix"`
	Version  string `mapstructure: "version" json:"version" yaml:"version"`
	Mysql Mysql `mapstructure:"mysql" json:"mysql" yaml:"mysql"`
}

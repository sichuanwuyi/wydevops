package main

import (
	"fmt"
	"go-demo/bootstrap"
	"go-demo/global"
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	//初始化配置
	bootstrap.InitializeConfig()

	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	//测试路由
	r.GET("/ping", func(c *gin.Context) {
		appName := global.App.Config.App.AppName
		c.String(http.StatusOK, "pong:"+appName)
		//c.JSON(200, gin.H{"msg": "服务应答成功"})
	})

	//K8S服务存活探针
	r.GET("/health/liveness", func(c *gin.Context) {
		c.String(http.StatusOK, "true")
		//c.JSON(200, gin.H{"msg": "服务应答成功"})
	})

	//K8S服务就绪探针
	r.GET("/health/readiness", func(c *gin.Context) {
		c.String(http.StatusOK, "true")
		//c.JSON(200, gin.H{"msg": "服务应答成功"})
	})

	err := r.Run(":" + global.App.Config.App.Port)
	if err != nil {
		fmt.Println("服务器启动失败！")
	} else {
		fmt.Println("服务器启动成功！")
	}

}

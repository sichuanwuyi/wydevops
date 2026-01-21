package bootstrap

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"go-demo/global"

	"github.com/fsnotify/fsnotify"
	"github.com/gin-gonic/gin"
	"github.com/spf13/viper"
)

func InitializeConfig() *viper.Viper {

	//设置配置文件路径
	config := "config.yaml"
	if gin.Mode() == gin.ReleaseMode {
		//生产环境可以从环境变量中获取配置文件路径
		configEnv := os.Getenv("VIPER_CONFIG")
		config = getFinalConfigPath(configEnv)
	}

	v := viper.New()
	v.SetConfigFile(config)
	v.SetConfigType("yaml")
	if err := v.ReadInConfig(); err != nil {
		panic(fmt.Errorf("read config failed: %s", err))
	}

	//监听配置文件
	v.WatchConfig()
	v.OnConfigChange(func(in fsnotify.Event) {
		fmt.Println("config file changed:", in.Name)
		//重新读取配置
		if err := v.Unmarshal(&global.App.Config); err != nil {
			fmt.Println(err)
		}
	})

	//将配置赋值给全局变量
	if err := v.Unmarshal(&global.App.Config); err != nil {
		fmt.Println(err)
	}

	return v
}

// getFinalConfigPath 根据configEnv的值生成最终的配置文件路径
// 规则：
// 1. 如果configEnv以.yaml结尾（完整文件路径），替换文件名部分为config-prod.yaml
// 2. 如果configEnv是目录路径，拼接config-prod.yaml作为完整文件路径
// 3. 如果configEnv为空，返回默认的config-prod.yaml
func getFinalConfigPath(configEnv string) string {
	// 定义目标配置文件名
	targetFileName := "config-prod.yaml"

	// 如果configEnv为空，直接返回默认文件名
	if strings.TrimSpace(configEnv) == "" {
		return targetFileName
	}

	// 判断是否以.yaml结尾（完整文件路径）
	if strings.HasSuffix(strings.ToLower(configEnv), ".yaml") {
		// 获取目录部分 + 新的文件名
		dir := filepath.Dir(configEnv)
		return filepath.Join(dir, targetFileName)
	}

	// 不是.yaml结尾，视为目录路径，拼接文件名
	// 先检查目录是否存在（可选，增强健壮性）
	if _, err := os.Stat(configEnv); err != nil {
		if os.IsNotExist(err) {
			fmt.Printf("警告：目录 %s 不存在，将尝试使用该路径拼接配置文件\n", configEnv)
		}
	}

	return filepath.Join(configEnv, targetFileName)
}

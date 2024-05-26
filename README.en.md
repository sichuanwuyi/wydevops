# atom-jenkins

#### Description
本项目用来统一管理在jenkins上使用的标准的构建shell脚本

#### 重要规范
1. atom-jenkins.sh是流程的唯一入口，主要作用：接收参数，分析并更新全局变量，最后启动标准流程
2. global-params.sh用来定义全局变量
3. standard-cicd.sh用来定义标准CI/CD流程
4. 采用source方式引入其他脚本文件
5. 局部变量使用local进行定义， 使用完毕后要使用unset注销
6. 脚本中的路径都使用全路径，不要使用相对路径
7. pipeline-stages存放流程内执行的脚本文件
8. 变量规范
8.1. 模板变量 使用大写字母及"_"组成
8.2. 入参变量 使用g开头，驼峰命名
8.3. 方法内变量 使用"_"开头，驼峰命名


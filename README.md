# wydevops 介绍
本项目使用统一的标准过程来管理微服务的编译构建、docker镜像生成（多架构）、Chart镜像生成、离线发布包生成，以及自动部署等过程。
wydevops的目标是打造功能最强大的、最易扩展和维护的、使用最简单的CI/CD流水线。

## 当前V1.*版本的功能特点
1. 从设计上支持多语言项目（目前已完成了GO、JAVA、Next.js、Vue项目的适配）、单模块和多模块项目。
2. 支持构建linux/amd64和linux/arm64两种架构的docker镜像。
3. 支持K8S、docker两种微服务自动部署方式。在本地工作模式下，可直接从源码项目中完成整个CI/CD流程，
   直至微服务在docker或K8S集群中运行起来。
4. 支持微服务镜像分层打包,生产环境下部署包更小。
5. 具备向外部系统发送通知消息的机制。
6. 支持离线构建微服务部署包，本地会缓存从公网拉取的所有第三方镜像，为私网环境下的微服务开发提供了极大便利。
7. 支持单chart部署多个微服务，便于对耦合紧密的业务模块进行统一发布和卸载。
8. 支持单容器内部署多个微服务，占用最少的宝贵的Pod资源。
9. 支持nexus3、harbor(2.10+)、registry、aws-ecr(AWS亚马逊网络服务公司的ECR仓库)作为docker镜像和chart镜像仓库,不再需要helm push插件。
10. 支持与Jenkins的集成，仅使用一个入口脚本即可完成与Jenkins Pipeline流水线的整合。
11. 全部代码均采用shell开发，具备最大灵活性和用户适应性，各类语言的开发人员学习和掌握的成本最低。
12. 项目内原创开发有强大的Yaml文件的读写工具，为用户自定义扩展功能提供极大的便利。
13. 设计有公司级、开发组级、项目级三层管理模型，留有为各级人员提供了管理和控制CI/CD流程的接口。
14. 为K8S资源配置文件提供了插件机制，便于开发人员自定义配置文件。
15. 在本项目的基础上，维护团队已经开发完成了wydevops微服务管理平台,目前尚未开源。

## 运行环境
1. 可在windows下的git bash命令行中运行。
2. 可在linux下的bash命令行中运行。
3. 可通过源码中提供的Jenkinsfile文件，与Jenkins Pipeline流水线进行整合。

## 依赖的第三方库
1. git
   Ubuntu (Debian/Ubuntu 系列)下：
   更新包索引并安装： 
     sudo apt update 
     sudo apt install -y git
   验证： git --version
   基本配置： git config --global user.name "你的名字" git config --global user.email "you@example.com"
   
   Windows下采用官方安装程序：
   下载并运行：https://git-scm.com/download/win
   按安装向导完成（可保留默认选项）。
   打开 PowerShell 或 cmd，验证： git --version
   基本配置（在 PowerShell 或 Git Bash 中）： git config --global user.name "你的名字" git config --global user.email "you@example.com"

2. libxml2
   这是一个用于处理xml文件的库。需要用户自行下载安装。
    ubuntu (Debian/Ubuntu 系列)下的安装命令：sudo apt install libxml2-utils
    windows下的安装命令：choco install libxml2

3. docker
   这是用于构建和管理docker镜像的工具。需要用户自行下载安装。
   ubuntu (Debian/Ubuntu 系列)下的安装命令：sudo apt install docker-ce
   windows下可从这里下载安装：[docker desktop](https://www.docker.com/get-started)

4. helm
   这是一个用于K8S微服务部署的工具。本项目会根据系统架构的不同自动安装/tools目录下对应的helm（内置的版本为v3.15.1）命令，无需用户安装。

5. kubectl
   这是一个用于K8S资源管理的命令行工具。
   linux下本项目会根据系统架构的不同自动安装/tools目录下对应的kubectl命令，无需用户安装。
   在windows下用户可安装docker desktop工具并启动内置的K8S集群（便于本地调试），docker desktop中自带Kubectl命令；或者执行安装命令：choco install kubectl
   kubectl安装完后需要为其指定管理的K8S集群信息，方法如下：
   1) 在 Windows 搜索中输入 “环境变量”，然后选择 “编辑系统环境变量”。
   2) 在 “系统属性” 对话框中，点击 “环境变量...” 按钮。
   3) 在 “用户变量” 或 “系统变量” 部分，点击 “新建...”。
   4) 变量名 输入 KUBECONFIG。
   5) 变量值 输入您的 kubeconfig 文件的完整路径，例如 C:\Users\YourUser\.kube\my-cluster-config。
   6) 点击确定保存。您需要重新打开一个新的终端窗口来使设置生效。

6. K8S集群中需要安装好istio
   默认配置下，wydevops会采用istio sidecar模式来部署微服务。
   因此要求K8S集群中已经安装了istio(安装方法详见[这里](https://istio.io/latest/docs/setup/getting-started/))。
   特别提醒：wydevops会连接目标集群(由目标参数targetApiServer指定)动态获取所有生成的K8S资源类型的apiVersion参数，
   以便确保生成的K8S资源类型的版本与目标集群保持一致。

## 安装步骤
1. 创建一个目录作为wydevops的根目录，并定义环境变量WYDEVOPS_HOME指向这个目录。
   ubuntu (Debian/Ubuntu 系列)下：
    1) vim ~/.bashrc
    2) 在文件末尾添加：export WYDEVOPS_HOME={新建的那个目录}, 并保存退出。
    3) 执行命令：source ~/.bashrc

   windows下:
    1) 在 Windows 搜索中输入 “环境变量”，然后选择 “编辑系统环境变量”。
    2) 在 “系统属性” 对话框中，点击 “环境变量...” 按钮。
    3) 在 “用户变量” 或 “系统变量” 部分，点击 “新建...”。
    4) 变量名 输入 WYDEVOPS_HOME。
    5) 变量值 输入刚创建的那个目录。
    6) 点击确定保存。您需要重新打开一个新的终端窗口来使设置生效。
2. 在$WYDEVOPS_HOME目录下打开git bash命令行，在命令行中执行下列命令下载本项目的源码。
    git clone -b master https://github.com/sichuanwuyi/wydevops.git
    或
    git clone -b master https://gitee.com/tmt_china/wydevops.git
3. 创建$WYDEVOPS_HOME/client-config.json文件，并将下述内容写入该文件中，以便后续wydevops执行时能自动更新到最新版本。
   {
     "repoUrl": "https://gitee.com/tmt_china/wydevops.git",
     "branch": "master"
   }
4. 安装第三方的依赖库（安装方法详见前述）
5. 安装成功验证
   执行命令：bash $WYDEVOPS_HOME/wydevops/script/wydevops.sh -h
   如果没有报错，说明安装成功。

## 与需要打包部署的项目集成
1. 将$WYDEVOPS_HOME/wydevops/script/wydevops-run.sh文件复制到目标项目的根目录下。
2. 打开目标项目的根目录下wydevops-run.sh文件，在其末尾的执行wydevops.sh命令的参数行中做如下修改或确认：
   1) 指定本地的第三方docker镜像的缓存目录(-I参数)。默认值为~/.wydevops/cachedImage。
   2) 指定项目的语言类型(-L参数)，目前支持的值有：java、go、nextjs、vue。如果是其他项目类型需要自行扩展或联系wydevops运维团队。
   3) 确认本次打包的架构类型(-A参数)，可选值有：linux/amd64、linux/arm64。默认值为linux/amd64。
   4) 确认本次流程生成的离线安装包的架构类型(-O参数),可选值有：linux/amd64、linux/arm64。默认值为linux/amd64。
   5) 其他参数保持不变即可，如需修改可执行命令：bash $WYDEVOPS_HOME/wydevops/script/wydevops.sh -h，进行参数详情查询。 
3. 在目标项目的根目录下创建一个名为ci-cd-config.yaml的文件。 
   在该文件的globalParams配置节下必须添加的参数有：
   1) 微服务的名称(serviceName)  
   2) 微服务的版本(businessVersion)
   3) 微服务的主端口号(mainPort)，支持多端口配置(端口号间使用英文逗号隔开)
   4) 微服务的网关域名(gatewayHost)，默认值为*，表示任意Host。
   5) 微服务的网关路径前缀(gatewayPath)，默认值为"/${serviceName}"，这个参数可以根据实际情况进行修改。
      默认情况下，网关在转发时会将请求路径中的"/${serviceName}"丢弃(rewrite规则决定的)。
   6) 是否启用K8S服务存活探针(livenessProbeEnable)，默认值为true。
   7) 如果livenessProbeEnable=true，则必须配置K8S服务存活探针的URI(livenessUri)，默认值为"/health"。
   8) 是否启用K8S服务就绪探针(readinessProbeEnable)，默认值为true。
   9) 如果readinessProbeEnable=true，则必须配置K8S服务就绪探针的URI(readinessUri)，默认值为"/health"。
   10) 默认的K8S集群节点服务器SSH参数信息(targetApiServer)，格式为：{服务器IP地址}|{SSH端口号}|{SSH连接账号}|{SSH连接密码}
      需要提前配置好本地计算机到该节点服务器的SSH免密登录，否则会导致部署失败。
   11) 部署的目标命名空间(targetNamespace)，默认值为default。部署时会自动创建不存在的命名空间。
       例如：targetApiServer: 172.27.213.84|22|admin|admin123456
   12) K8s集群内部拉取镜像的仓库信息(targetDockerRepo)，
       格式为：{仓库类型(nexus或harbor)},{仓库实例名称(nexus)或项目名称(harbor)},{仓库访问地址({IP}:{端口})},{登录账号},{登录密码}
       例如：targetDockerRepo: registry,wydevops,192.168.1.218:30783,admin,admin123,30784
      
      上述参数是在执行后续流程前必须配置好的，否则会导致部署失败。除此之外还有很多其他配置参数，如需更全面的了解
   请参考$WYDEVOPS_HOME/wydevops/script/templates/config目录下各语言的配置模板文件_ci-cd-template.yaml。该文件中包含了所有的配置参数详情。
   
## 对部分项目类型的深度定制 
   对java项目和go项目，wydevops做了进一步的深度定制，通过params-mapping-in-yaml-file.config、params-mapping-in-xml-file.config配置文件
   将上述1)-5)的参数绑定到了目标项目自有的配置文件的某些参数上了(具体绑定规则请参考params-mapping-in-*-file.config文件中的注释)，
   wydevops运行时会根据目标项目的配置文件自动提取被绑定参数的值。这类params-mapping-in-*-file.config配置文件依赖各公司或组织机构内部的项目开发规范，
   是研发团队项目规范在wydevops中的具体体现。通过这个绑定机制可强制约束开发人员对研发规范的严格执行。
   实际开发中可灵活调整params-mapping-in-*-file.config配置文件的内容，以适配研发团队的项目开发规范。
1. java项目默认规范
   1) wydevops默认支持的Java规范中，所有的application.yaml文件都必须存放在/resources/config目录下。
   2) wydevops默认Java项目使用的生成环境配置文件为application-prod.yaml,也即生成环境打包时spring.profiles.active必须配置为prod。
   3) 在params-mapping-in-yaml-file.config文件中详细定了application*.yaml文件中哪个参数的值被绑定到了wydevops的哪些参数上。
   4) 在params-mapping-in-xml-file.config文件中详细定了pom.yaml文件又哪些自定义的参数并且这些参数的值被绑定到了wydevops的哪些参数上。
2. go项目默认规范
   1) 默认生产环境下的配置文件名称为config-prod.yaml，这个文件必须存放在项目的根目录下。
   2) 在config-prod.yaml文件中，必须存在： 
   3) app.appName——该参数值被绑定到了globalParams.serviceName、globalParams.serviceNameZh。
   4) app.version——该参数值被绑定到了globalParams.businessVersion。
   5) app.port——该参数值被绑定到了globalParams.mainPort、globalParams.containerPorts、globalParams.servicePorts
   6) app.gateway.domain——该参数值被绑定到了globalParams.gatewayHost。      
   7) app.gateway.route-prefix——该参数值被绑定到了globalParams.gatewayPath       

特别说明，凡是被params-mapping-in-*-file.config文件中定义了绑定规则的wydevops参数，可以不在ci-cd-config.yaml文件中定义。 

## 示例项目说明
   项目源码的/sample目录下包含了java、go、nextjs、vue四种类型的示例项目。每个示例都比较简单，感兴趣的开发者可以参考这些示例项目。

## wydevops微服务管理平台(V1.0.0)
   基于wydevops打包的微服务离线安装包，团队开发了一个微服务管理平台，用于管理微服务的部署、监控、日志等。
   该平台目前尚未开源，后续会在团队内部进行完善和优化。主要的核心界面展示如下：
1. 登录界面![](docs/images/登录.png)
2. 集群总览界面![](docs/images/集群总览.jpg)
3. 集群节点界面![](docs/images/集群节点详情1.jpg) ![](docs/images/集群节点详情2.jpg)
4. 应用列表界面![](docs/images/应用列表.jpg)
5. 服务列表界面![](docs/images/服务列表.jpg)
6. 用户管理界面![](docs/images/用户权限管理1.jpg) ![](docs/images/用户权限管理2.jpg)
7. 离线安装包切片上传界面![](docs/images/离线安装包上传界面.jpg) 
8. 上传后解压验证界面![](docs/images/上传后解压验证界面.jpg) 
9. 应用安装过程界面![](docs/images/部署详情1.jpg) ![](docs/images/部署详情2.jpg)
10. 配置参数动态修改界面![](docs/images/安装时参数配置界面1.jpg) ![](docs/images/安装时参数配置界面2.jpg)
11. 基于istio的灰度发布界面![](docs/images/基于istio的灰度发布配置界面.jpg) ![](docs/images/灰度发布结果界面.jpg)
12. 应用日志查看界面![](docs/images/服务运行日志查询.jpg)
13. 容器命令行界面![](docs/images/容器命令行界面.jpg)

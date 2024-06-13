# wydevops

#### 介绍
本项目使用统一的标准过程来管理微服务的编译构建、docker镜像生成（多架构）、Chart镜像生成、离线发布包生成，以及自动部署等过程。
wydevops的目标是打造功能最强大的、最易扩展和维护的、使用最简单的CI/CD流水线。
V1.0.0具备以下特点：
1. 从设计上支持多语言项目（目前仅完成了JAVA项目的适配）、单模块和多模块项目。
2. 支持构建linux/amd64和linux/arm64两种架构的docker镜像。
3. 支持K8S、docker两种微服务自动部署方式。在本地工作模式下，可直接从源码项目中完成整个CI/CD流程，
   直至微服务在docker或K8S集群中运行起来。
4. 支持微服务镜像分层打包,生产环境下部署包更小。
5. 具备向外部系统发送通知消息的机制。
6. 支持离线构建微服务部署包，本地会缓存从公网拉取的所有第三方镜像，为私网环境下的微服务开发提供了极大便利。
7. 支持单chart部署多个微服务，便于对耦合紧密的业务模块进行统一发布和卸载。
8. 支持单容器内部署多个微服务，占用最少的宝贵的Pod资源。
9. 支持nexus3和harbor(2.10+)作为docker镜像和chart镜像仓库,不再需要helm push插件。
10. 支持与Jenkins的集成，仅使用一个入口脚本即可完成与Jenkins Pipeline流水线的整合。
11. 全部代码均采用shell开发，具备最大灵活性和用户适应性，各类语言的开发人员学习和掌握的成本最低。
12. 项目内原创开发有强大的Yaml文件的读写工具，为用户自定义扩展功能提供极大的便利。
13. 设计有公司级、开发组级、项目级三层管理模型，留有为各级人员提供了管理和控制CI/CD流程的接口。
14. 为K8S资源配置文件提供了插件机制，便于开发人员自定义配置文件。
15. 后续会在本项目的基础上，开发K8S环境下的面对客户和用户（而非维护人员）的微服务管理平台。

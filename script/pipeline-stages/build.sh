#!/usr/bin/env bash

function executeBuildStage() {
  export gDefaultRetVal
  export gPipelineScriptsDir
  export gCiCdYamlFile
  export gCurrentStage
  export gServiceName
  export gCurrentStageResult

  info "加载公共${gCurrentStage}阶段功能扩展文件：${gCurrentStage}-extend-point.sh"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForBuildStage" "执行${gCurrentStage}阶段全局参数初始化前扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForBuildStage" "执行${gCurrentStage}阶段全局参数初始化扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForBuildStage" "执行${gCurrentStage}阶段全局参数初始化后扩展..." "${gCiCdYamlFile}"

  invokeExtendPointFunc "onBeforeProjectBuilding" "项目编译前扩展" "${gCiCdYamlFile}"
  #调用buildProject扩展，各个语言可按自己的要求完成项目编译过程。
  #对于Java语言可以直接在本地系统中构建异构镜像。（需要在docker.json配置文件中设置"experimental": true)
  #对于C++或Go这类需要在目标架构系统中才能完成构建的项目：
  #首先，需要预先搭建好一个目标架构节点。
  #其次，需要预先构建一个用于特定语言项目编译的镜像，并安装到目标架构节点中。
  #最后，通过SSH连接到目标架构节点上，通过docker run命令运行这个项目编译镜像，
  #至少需要向该镜像输入目标项目Git的地址和编译输出路径（外挂的）。
  #在该镜像运行起来后会先使用Git拉取源码,再使用gcc或go build完成源码编译，最后将编译结果输出到指定的目录中。
  invokeExtendPointFunc "buildProject" "执行项目编译扩展" "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterProjectBuilding" "执行项目编译后扩展" "${gCiCdYamlFile}"
  #向外部管理平台发送通知
  invokeExtendPointFunc "sendNotify" "向外部接口发送${gServiceName}项目编译结果通知" "${gCurrentStageResult}"
}

executeBuildStage
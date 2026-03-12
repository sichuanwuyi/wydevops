#!/usr/bin/env bash

function executeBuildStage() {
  export gDefaultRetVal
  export gPipelineScriptsDir
  export gCiCdYamlFile
  export gCurrentStage
  export gServiceName
  export gCurrentStageResult
  export gLanguage

  if [ "${gLanguage}" == "other" ];then
    return
  fi

  info "build.sh.loading.common.extend.file" "${gCurrentStage}#${gCurrentStage}"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForBuildStage" "build.sh.before.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForBuildStage" "build.sh.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForBuildStage" "build.sh.after.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"

  invokeExtendPointFunc "onBeforeProjectBuilding" "build.sh.before.project.building" "" "${gCiCdYamlFile}"
  #调用buildProject扩展，各个语言可按自己的要求完成项目编译过程。
  #对于Java语言可以直接在本地系统中构建异构镜像。（需要在docker.json配置文件中设置"experimental": true)
  #对于C++或Go这类需要在目标架构系统中才能完成构建的项目：
  #首先，需要预先搭建好一个目标架构节点。
  #其次，需要预先构建一个用于特定语言项目编译的镜像，并安装到目标架构节点中。
  #最后，通过SSH连接到目标架构节点上，通过docker run命令运行这个项目编译镜像，
  #至少需要向该镜像输入目标项目Git的地址和编译输出路径（外挂的）。
  #在该镜像运行起来后会先使用Git拉取源码,再使用gcc或go build完成源码编译，最后将编译结果输出到指定的目录中。
  invokeExtendPointFunc "buildProject" "build.sh.build.project" "" "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterProjectBuilding" "build.sh.after.project.building" "" "${gCiCdYamlFile}"
  #向外部管理平台发送通知
  invokeExtendPointFunc "sendNotify" "build.sh.send.notify" "${gServiceName}" "${gCurrentStageResult}"
}

executeBuildStage
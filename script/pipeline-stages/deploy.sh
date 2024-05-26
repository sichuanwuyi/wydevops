#!/usr/bin/env bash

function executePackageStage() {
  export gDefaultRetVal
  export gPipelineScriptsDir
  export gCiCdYamlFile
  export gCurrentStage
  export gServiceName
  export gCurrentStageResult
  export gHelmBuildOutDir

  local l_i
  local l_packageName

  info "加载公共${gCurrentStage}阶段功能扩展文件：${gCurrentStage}-extend-point.sh"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForDeployStage" "执行${gCurrentStage}阶段全局参数初始化前扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForDeployStage" "执行${gCurrentStage}阶段全局参数初始化扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForDeployStage" "执行${gCurrentStage}阶段全局参数初始化后扩展..." "${gCiCdYamlFile}"

  ((l_i = 0))
  while true; do
    #读取需要发布的离线安装包名称
    readParam "${gCiCdYamlFile}" "deploy[${l_i}].packageName"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      if [ "${l_i}" -eq 0 ];then
        error "${gCiCdYamlFile##*/}文件中deploy[${l_i}].packageName参数是空的"
      else
        break
      fi
    fi
    l_packageName="${gDefaultRetVal}"

    invokeExtendPointFunc "onBeforeDeployingServicePackage" "服务安装包部署扩展" "${l_i}" "${l_packageName}"
    #发布服务安装包
    invokeExtendPointFunc "deployServicePackage" "服务安装包部署扩展" "${l_i}" "${l_packageName}"
    invokeExtendPointFunc "onAfterCreatingOfflinePackage" "服务安装包部署后扩展" "${l_i}" "${l_packageName}"
    #向外部管理平台发送通知
    invokeExtendPointFunc "sendNotify" "向外部接口发送${gServiceName}服务安装包部署结果通知" "${gCurrentStageResult}"

    ((l_i = l_i + 1))
  done
}

executePackageStage
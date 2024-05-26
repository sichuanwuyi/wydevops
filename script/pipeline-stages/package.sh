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
  local l_chartName

  info "加载公共${gCurrentStage}阶段功能扩展文件：${gCurrentStage}-extend-point.sh"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForPackageStage" "执行${gCurrentStage}阶段全局参数初始化前扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForPackageStage" "执行${gCurrentStage}阶段全局参数初始化扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForPackageStage" "执行${gCurrentStage}阶段全局参数初始化后扩展..." "${gCiCdYamlFile}"

  ((l_i = 0))
  while true; do
    #读取chart名称
    readParam "${gCiCdYamlFile}" "package[${l_i}].chartName"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      break
    fi
    l_chartName="${gDefaultRetVal}"

    invokeExtendPointFunc "onBeforeCreatingOfflinePackage" "离线安装包打包前扩展" "${l_i}" "${l_chartName}"
    #安装离线安装包打包规则制作离线安装包
    invokeExtendPointFunc "createOfflinePackage" "离线安装包打包扩展" "${l_i}" "${l_chartName}"
    invokeExtendPointFunc "onAfterCreatingOfflinePackage" "离线安装包打包后扩展" "${l_i}" "${l_chartName}"
    #向外部管理平台发送通知
    invokeExtendPointFunc "sendNotify" "向外部接口发送${gServiceName}项目离线安装包打包结果通知" "${gCurrentStageResult}"

    ((l_i = l_i + 1))
  done
}

executePackageStage
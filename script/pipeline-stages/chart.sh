#!/usr/bin/env bash
function executeChartStage() {
  export gDefaultRetVal
  export gPipelineScriptsDir
  export gCiCdYamlFile
  export gCurrentStage
  export gChartBuildDir
  export gCurrentStageResult
  export gChartNames

  local l_chartNameList
  local l_chartName
  local l_chartPath
  local l_curDir

  info "加载公共${gCurrentStage}阶段功能扩展文件：${gCurrentStage}-extend-point.sh"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForChartStage" "执行${gCurrentStage}阶段全局参数初始化前扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForChartStage" "执行${gCurrentStage}阶段全局参数初始化扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForChartStage" "执行${gCurrentStage}阶段全局参数初始化后扩展..." "${gCiCdYamlFile}"

  l_curDir=$(pwd)

  # shellcheck disable=SC2206
  l_chartNameList=(${gChartNames})
  # shellcheck disable=SC2068
  for l_chartName in ${l_chartNameList[@]};do
    l_chartPath="${gChartBuildDir}/${l_chartName}"
    invokeExtendPointFunc "onBeforeCreatingChartImage" "创建Chart镜像前扩展" "${l_chartPath}"

    #获取当前chart镜像实际构建目录（可能会遇到自定义chart构建目录）
    l_chartPath="${gDefaultRetVal}"
    invokeExtendPointFunc "createChartImage" "创建Chart镜像扩展" "${l_chartPath}"

    invokeExtendPointFunc "onAfterCreatingChartImage" "创建Chart镜像后扩展" "${l_chartPath}"
    #向外部管理平台发送通知
    invokeExtendPointFunc "sendNotify" "调用通知接口发送Chart镜像构建结果" "${gCurrentStageResult}"
  done

  # shellcheck disable=SC2164
  cd "${l_curDir}"
}

#是否是自定义的Helm打包目录。
export gCustomizedHelm
#需要构建的Chart镜像名称, 多个名称间使用空格隔离
export gChartNames

export gTargetNamespace
export gCurrentChartName
export gCurrentChartVersion
#应用的当前版本号
export gCurrentAppVersion
#当前服务(Deployment/DaemonSet/StatefulSet)的版本
export gCurrentServiceVersion

executeChartStage
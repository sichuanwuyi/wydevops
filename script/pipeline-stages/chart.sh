#!/usr/bin/env bash
function executeChartStage() {
  export gDefaultRetVal
  export gBuildScriptRootDir
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

  info "chart.sh.loading.common.extend.file" "${gCurrentStage}#${gCurrentStage}"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  info "chart.sh.loading.k8s.api.reader" "${gCurrentStage}"
  source "${gBuildScriptRootDir}/plugins/k8s-api-resources-reader.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForChartStage" "chart.sh.before.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForChartStage" "chart.sh.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForChartStage" "chart.sh.after.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"

  l_curDir=$(pwd)

  # shellcheck disable=SC2206
  l_chartNameList=(${gChartNames})
  # shellcheck disable=SC2068
  for l_chartName in ${l_chartNameList[@]};do
    l_chartPath="${gChartBuildDir}/${l_chartName}"
    invokeExtendPointFunc "onBeforeCreatingChartImage" "chart.sh.before.creating.chart.image" "" "${l_chartPath}"

    #获取当前chart镜像实际构建目录（可能会遇到自定义chart构建目录）
    l_chartPath="${gDefaultRetVal}"
    invokeExtendPointFunc "createChartImage" "chart.sh.create.chart.imag" "" "${l_chartPath}"

    invokeExtendPointFunc "onAfterCreatingChartImage" "chart.sh.after.creating.chart.image" "" "${l_chartPath}"
    #向外部管理平台发送通知
    invokeExtendPointFunc "sendNotify" "chart.sh.send.notify" "" "${gCurrentStageResult}"
  done

  # shellcheck disable=SC2164
  cd "${l_curDir}"
}

#是否是自定义的Helm打包目录。
export gCustomizedHelm
#需要构建的Chart镜像名称, 多个名称间使用空格隔离
export gChartNames

#当前版本是否支持回滚
export gRollback
export gTargetApiServer
export gTargetNamespace
export gCurrentChartName
export gCurrentChartVersion
#应用的当前版本号
export gCurrentAppVersion
#当前服务(Deployment/DaemonSet/StatefulSet)的版本
export gCurrentServiceVersion

executeChartStage
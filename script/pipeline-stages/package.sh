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
  local l_maxIndex

  info "package.sh.loading.common.extend.file" "${gCurrentStage}#${gCurrentStage}"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForPackageStage" "package.sh.before.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForPackageStage" "package.sh.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForPackageStage" "package.sh.after.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"

  #确定最大索引值。
  getListSize "${gCiCdYamlFile}" "package"
  l_maxIndex="${gDefaultRetVal}"
  ((l_maxIndex= l_maxIndex - 1))

  for (( l_i = 0; l_i <= l_maxIndex; l_i++ )); do
    #读取chart名称
    readParam "${gCiCdYamlFile}" "package[${l_i}].chartName"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      break
    fi
    l_chartName="${gDefaultRetVal}"

    invokeExtendPointFunc "onBeforeCreatingOfflinePackage" "package.sh.before.creating.offline.package" "" "${l_i}" "${l_chartName}"
    #安装离线安装包打包规则制作离线安装包
    invokeExtendPointFunc "createOfflinePackage" "package.sh.create.offline.package" "" "${l_i}" "${l_chartName}" "${l_maxIndex}"
    invokeExtendPointFunc "onAfterCreatingOfflinePackage" "package.sh.after.creating.offline.package" "" "${l_i}" "${l_chartName}"
    #向外部管理平台发送通知
    invokeExtendPointFunc "sendNotify" "package.sh.send.notify" "${gServiceName}" "${gCurrentStageResult}"
   done
}

executePackageStage
#!/usr/bin/env bash

function initialGlobalParamsForBuildStage_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gLanguage

  local l_content
  local l_archTypes
  local l_archType
  local l_paramName
  local l_subParamNames
  local l_subParamName

  if [ "${gLanguage}" != "java" ];then
    l_subParamNames=("nodeIP" "sshAccount" "sshPassword" "buildImage")
    #初始化C++项目编译阶段需要的全局变量
    readParam "${gCiCdYamlFile}" "build"
    l_content="${gDefaultRetVal}"
    l_archTypes=$(echo "${l_content}" | grep -oP "^[a-zA-Z_]+.*$")
    # shellcheck disable=SC2068
    for l_archType in ${l_archTypes[@]};do
      l_archType="${l_archType%%:*}"
      for l_subParamName in ${l_subParamNames[@]};do
        l_paramName="build.${l_archType}.${l_subParamName}"
        readParam "${gCiCdYamlFile}" "${l_paramName}"
        l_content="${gDefaultRetVal}"
        gBuildStageParamMap["${l_subParamName^}_${l_archType}"]="${l_content}"
        debug "设置${l_subParamName^}_${l_archType}=${l_content}"
      done
    done
  fi

}

function buildProject_ex() {
  export gCurrentStageResult
  export gServiceName

  gCurrentStageResult="INFO|项目${gServiceName}编译成功"
}

#加载build阶段脚本库文件
loadExtendScriptFileForLanguage "build"

declare -A gBuildStageParamMap
export gBuildStageParamMap
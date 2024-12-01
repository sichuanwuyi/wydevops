#!/usr/bin/env bash

function _onAfterInitialingGlobalParamsForDockerStage_ex() {

  export gDockerFileTemplateParamMap

  local l_distDir
  local l_output

  #获取nextjs项目next.config.ts文件中distDir参数的值。
  _getNextJsParamValue "${gBuildPath}/next.config.ts" "distDir" ".next" "false"
  l_distDir="${gDefaultRetVal}"
  gDockerFileTemplateParamMap["_DOT-NEXT_"]="${l_distDir}"

  #获取nextjs项目next.config.ts文件中output参数的值。
  _getNextJsParamValue "${gBuildPath}/next.config.ts" "output" "standalone" "true"
  l_output="${gDefaultRetVal}"
  gDockerFileTemplateParamMap["_OUTPUT_"]="${l_output}"

}

function _onBeforeCreatingDockerImage_ex() {
  export gBuildPath
  export gDockerBuildDir
  export gDefaultRetVal

  local l_dockerfile=$3

  cp -rf "${gBuildPath}/app" "${gDockerBuildDir}/"
  cp -rf "${gBuildPath}/public" "${gDockerBuildDir}/"
  cp -f "${gBuildPath}"/.env* "${gDockerBuildDir}/"
  cp -f "${gBuildPath}/pnpm-lock.yaml" "${gDockerBuildDir}/"
  cp "${gBuildPath}"/*.ts "${gDockerBuildDir}/"
  cp "${gBuildPath}"/*.js "${gDockerBuildDir}/"
  cp "${gBuildPath}"/*.json "${gDockerBuildDir}/"
}

function _getNextJsParamValue() {
  export gDefaultRetVal

  local l_nextConfigFile=$1
  local l_paramName=$2
  local l_defaultValue=$3
  local l_insertOnNotExist=$4

  local l_rowNumber
  local l_rowContent
  local l_content
  local l_paramValue

  #使用默认值初始化l_paramValue
  l_paramValue=""
  # shellcheck disable=SC2002
  l_content=$(cat "${l_nextConfigFile}" | grep -noP "^(.*):[ ]*NextConfig[ ]*=[ ]*\{[ ]*$")
  if [ "${l_content}" ];then
    l_rowNumber=${l_content%%:*}
    l_content=$(awk "NR==${l_rowNumber},NR==-1" "${l_nextConfigFile}" | grep -m 1 -noP "^[ ]*${l_paramName}:.*$")
    if [ "${l_content}" ];then
      #提取行号。
      (( l_rowNumber=l_rowNumber - 1 + ${l_content%%:*} ))
      #提取行内容
      l_rowContent=${l_content#*:}
      #获取行中第一个冒号后的内容。
      l_content="${l_rowContent##*:}"
      #去掉获取内容的前后空格
      l_content=$(echo -e "${l_content}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      #获取逗号左边的内容。
      l_content="${l_content%,*}"
      #删除单引号
      l_content="${l_content//\'/}"
      #删除双引号
      l_content="${l_content//\"/}"
      if [ "${l_content}" ];then
        l_paramValue="${l_content}"
      #如果参数值为空，则判断是否需要强行用默认值替换。
      else
        if [ "${l_insertOnNotExist}" == "true" ];then
          warn "检测到项目配置文件中${l_paramName}参数的值为空，强制更新为默认值：${l_defaultValue}"
          #替换l_rowNumber行的内容。
          sed -i "${l_rowNumber}c\\${l_rowContent%%:*}: '${l_defaultValue}'," "${l_nextConfigFile}"
        fi
        l_paramValue="${l_defaultValue}"
      fi
    #如果参数值为空，则判断是否需要强行插入默认值。
    else
      if [ "${l_insertOnNotExist}" == "true" ];then
        warn "检测到项目配置文件中不存在${l_paramName}参数，强制插入该参数并设置默认值为：${l_defaultValue}"
        #在l_rowNumber行的下一行插入参数。
        sed -i "${l_rowNumber}a\\    ${l_paramName}: '${l_defaultValue}'," "${l_nextConfigFile}"
      fi
      l_paramValue="${l_defaultValue}"
    fi
  fi

  gDefaultRetVal="${l_paramValue}"
}

#!/usr/bin/env bash

function _onAfterInitialingGlobalParamsForDockerStage_ex() {

  export gDockerFileTemplateParamMap

  local l_distDir

  #获取nextjs项目build输出目录。
  _getNextJsBuildOutDir "${l_dockerfile}"
  l_distDir="${gDefaultRetVal}"

  gDockerFileTemplateParamMap["_DOT-NEXT_"]="${l_distDir}"
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

function _getNextJsBuildOutDir() {
  export gDefaultRetVal

  local l_dockerfile=$1
  local l_rowNumber
  local l_content
  local l_distDir

  #从next.config.ts文件中读取distDir参数的值,默认值为distDir。
  l_distDir=".next"
  # shellcheck disable=SC2002
  l_content=$(cat "${gBuildPath}/next.config.ts" | grep -noP "^(.*):[ ]*NextConfig[ ]*=[ ]*\{[ ]*$")
  if [ "${l_content}" ];then
    l_rowNumber=${l_content%%:*}
    l_content=$(awk "NR==${l_rowNumber},NR==-1" "${gBuildPath}/next.config.ts" | grep -m 1 -oP "^[ ]*distDir:.*$")
    if [ "${l_content}" ];then
      l_content="${l_content##*:}"
      l_content=$(echo -e "${l_content}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      l_content="${l_content%,*}"
      l_content="${l_content//\'/}"
      l_content="${l_content//\"/}"
      l_distDir="${l_content}"
    fi
  fi

  gDefaultRetVal="${l_distDir}"
}
#!/usr/bin/env bash

function _onAfterInitialingGlobalParamsForDockerStage_ex() {
  export gDefaultRetVal
  export gDockerFileTemplateParamMap

  local l_distDir
  local l_output
  local l_startRowRegex="^(.*):[ ]*NextConfig[ ]*=[ ]*\{[ ]*$"

  #获取nextjs项目next.config.ts文件中distDir参数的值。
  getParamValueInJsonConfigFile "${gBuildPath}/next.config.ts" "${l_startRowRegex}" "distDir" ".next" "false"
  l_distDir="${gDefaultRetVal}"
  gDockerFileTemplateParamMap["_DOT-NEXT_"]="${l_distDir}"

  #获取nextjs项目next.config.ts文件中output参数的值。
  getParamValueInJsonConfigFile "${gBuildPath}/next.config.ts" "${l_startRowRegex}" "output" "standalone" "true"
  l_output="${gDefaultRetVal}"
  gDockerFileTemplateParamMap["_OUTPUT_"]="${l_output}"

}

function _onBeforeCreatingDockerImage_ex() {
  export gBuildPath
  export gDockerBuildDir

  local l_dockerfile=$3

  cp -rf "${gBuildPath}/app" "${gDockerBuildDir}/"
  cp -rf "${gBuildPath}/public" "${gDockerBuildDir}/"
  cp -f "${gBuildPath}"/.env* "${gDockerBuildDir}/"
  cp -f "${gBuildPath}/pnpm-lock.yaml" "${gDockerBuildDir}/"
  cp "${gBuildPath}"/*.ts "${gDockerBuildDir}/"
  cp "${gBuildPath}"/*.js "${gDockerBuildDir}/"
  cp "${gBuildPath}"/*.json "${gDockerBuildDir}/"

}

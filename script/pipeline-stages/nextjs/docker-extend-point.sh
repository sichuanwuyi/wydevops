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
  export gCiCdConfigYamlFileName

  local l_dockerfile=$3
  local l_ciCdConfigFile="${gBuildPath}/${gCiCdConfigYamlFileName}"

  info "将项目根目录下的必要的文件和目录复制到Docker构建目录中..."
  cp -rf "${gBuildPath}/app" "${gDockerBuildDir}/" || true
  cp -rf "${gBuildPath}/public" "${gDockerBuildDir}/" || true
  cp -f "${gBuildPath}"/.env* "${gDockerBuildDir}/" || true
  cp "${gBuildPath}"/*.ts "${gDockerBuildDir}/" || true
  cp "${gBuildPath}"/*.mjs "${gDockerBuildDir}/" || true
  cp "${gBuildPath}"/*.json "${gDockerBuildDir}/" || true
  info "复制结束"

  readParam "${l_ciCdConfigFile}" "globalParams.envFile"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    warn "删除${gDockerBuildDir}/.env.production文件"
    rm -f "${gDockerBuildDir}/.env.production" || true
    warn "将${gDefaultRetVal}文件重命名为.env.production文件"
    mv -f "${gDockerBuildDir}/${gDefaultRetVal}" "${gDockerBuildDir}/.env.production" || true
  fi

}

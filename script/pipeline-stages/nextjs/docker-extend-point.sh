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

  info "nextjs.docker.extend.point.copying.files.to.docker.build.dir"
  cp -rf "${gBuildPath}/app" "${gDockerBuildDir}/" || true
  cp -rf "${gBuildPath}/public" "${gDockerBuildDir}/" || true
  cp -f "${gBuildPath}"/.env* "${gDockerBuildDir}/" || true
  cp "${gBuildPath}"/*.ts "${gDockerBuildDir}/" || true
  cp "${gBuildPath}"/*.mjs "${gDockerBuildDir}/" || true
  cp "${gBuildPath}"/*.json "${gDockerBuildDir}/" || true
  info "nextjs.docker.extend.point.copying.files.finished"

  readParam "${l_ciCdConfigFile}" "globalParams.envFile"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    warn "nextjs.docker.extend.point.deleting.env.production" "${gDockerBuildDir}"
    rm -f "${gDockerBuildDir}/.env.production" || true
    warn "nextjs.docker.extend.point.renaming.env.file" "${gDefaultRetVal}"
    mv -f "${gDockerBuildDir}/${gDefaultRetVal}" "${gDockerBuildDir}/.env.production" || true
  fi

}

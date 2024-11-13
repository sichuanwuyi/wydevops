#!/usr/bin/env bash

function _onBeforeCreatingDockerImage_ex() {
  export gBuildPath
  export gDockerBuildDir

  local l_dockerfile=$3

  if [[ "${l_dockerfile}" =~ ^(.*)_base$ ]];then
    cp -f "${gBuildPath}"/.env* "${gDockerBuildDir}/"
    cp -f "${gBuildPath}/pnpm-lock.yaml" "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.ts "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.js "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.json "${gDockerBuildDir}/"
  elif [[ "${l_dockerfile}" =~ ^(.*)_business$ ]];then
    cp -rf "${gBuildPath}/public" "${gDockerBuildDir}/"
    cp -rf "${gBuildPath}/.next" "${gDockerBuildDir}/"
  else
    cp -rf "${gBuildPath}/public" "${gDockerBuildDir}/"
    cp -rf "${gBuildPath}/.next" "${gDockerBuildDir}/"
    cp -f "${gBuildPath}"/.env* "${gDockerBuildDir}/"
    cp -f "${gBuildPath}/pnpm-lock.yaml" "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.ts "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.js "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.json "${gDockerBuildDir}/"
  fi
}
#!/usr/bin/env bash

function onBeforePushDockerImage_harbor() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  if [ "${l_dockerRepoType}" != "harbor" ];then
    gDefaultRetVal="false|"
    return
  fi

  if ! type -t "queryNexusComponentId" > /dev/null; then
    source "${gBuildScriptRootDir}/helper/harbor-api-helper.sh"
  fi

  local l_image=$2
  local l_dockerRepoHostAndPort=$3
  local l_dockerRepoInstanceName=$4
  local l_dockerRepoWebPort=$5
  local l_dockerRepoAccount=$6
  local l_dockerRepoPassword=$7

  local l_imageName
  local l_imageVersion
  local l_versionList
  local l_versionItem

  l_imageName="${l_image%:*}"
  l_imageVersion="${l_image##*:}"

  l_versionList=("${l_imageVersion}" "${l_imageVersion}-linux-amd64" "${l_imageVersion}-linux-arm64")

  # shellcheck disable=SC2068
  for l_versionItem in ${l_versionList[@]};do

    info "在${l_dockerRepoType}类型的docker仓库中查找现存的${l_imageName}:${l_versionItem}镜像..."
    existRepositoryInHarborProject "${l_dockerRepoHostAndPort}" "${l_dockerRepoInstanceName}" "${l_imageName}" "${l_versionItem}"
    if [ "${gDefaultRetVal}" == "true" ];then
      info "找到了目标镜像，开始清除..."
      deleteRepositoryInHarborProject "${l_dockerRepoHostAndPort}" "${l_dockerRepoInstanceName}" "${l_imageName}" "${l_versionItem}" \
        "${l_dockerRepoAccount}" "${l_dockerRepoPassword}"
      info "目标镜像清除成功"
    else
      warn "目标镜像不存在"
    fi

  done

  gDefaultRetVal="true|true"
}

function onBeforePushDockerImage_nexus() {
  export gDefaultRetVal
  export gBuildScriptRootDir

  local l_dockerRepoType=$1
  if [ "${l_dockerRepoType}" != "nexus" ];then
    gDefaultRetVal="false|"
    return
  fi

  if ! type -t "queryNexusComponentId" > /dev/null; then
    source "${gBuildScriptRootDir}/helper/nexus-api-helper.sh"
  fi

  local l_image=$2
  local l_dockerRepoName=$3
  local l_dockerRepoInstanceName=$4
  local l_dockerRepoWebPort=$5

  local l_imageName
  local l_imageVersion

  l_imageName="${l_image%:*}"
  l_imageVersion="${l_image##*:}"

  info "在${l_dockerRepoType}类型的docker仓库中查找现存的${l_imageName}:${l_imageVersion}镜像..."
  queryNexusComponentId "${l_dockerRepoName%%:*}" "${l_dockerRepoWebPort}" "${l_dockerRepoInstanceName}" "${l_imageName}" "${l_imageVersion}"
  if [ "${gDefaultRetVal}" ];then
    info "找到了目标镜像，开始清除..."
    deleteNexusComponentById "${l_dockerRepoName%%:*}" "${l_dockerRepoWebPort}" "${gDefaultRetVal}"
    info "目标镜像清除成功"
  else
    warn "目标镜像不存在"
  fi

  gDefaultRetVal="true|true"
}

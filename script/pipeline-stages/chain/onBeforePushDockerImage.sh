#!/usr/bin/env bash

function onBeforePushDockerImage_harbor() {
  export gDefaultRetVal
  export gForceCoverage

  local l_dockerRepoType=$1
  if [ "${l_dockerRepoType}" != "harbor" ];then
    gDefaultRetVal="false|false|false"
    return
  fi

  if ! type -t "existRepositoryInHarborProject" > /dev/null; then
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
  local l_result

  l_imageName="${l_image%:*}"
  l_imageVersion="${l_image##*:}"

  if [ "${l_archType}" ];then
    l_versionList=("${l_imageVersion}-${l_archType//\//-}")
  else
    l_versionList=("${l_imageVersion}" "${l_imageVersion}-linux-amd64" "${l_imageVersion}-linux-arm64")
  fi

  l_result=""
  # shellcheck disable=SC2068
  for l_versionItem in ${l_versionList[@]};do

    info "在${l_dockerRepoType}类型的docker仓库中查找现存的${l_imageName}:${l_versionItem}镜像..."
    existRepositoryInHarborProject "${l_dockerRepoHostAndPort}" "${l_dockerRepoInstanceName}" "${l_imageName}" "${l_versionItem}"
    if [ "${gDefaultRetVal}" == "true" ];then
      if [ "${gForceCoverage}" == "true" ];then
        info "目标镜像存在，且当前是强制覆盖模式，则开始清除仓库中现有版本..."
        deleteRepositoryInHarborProject "${l_dockerRepoHostAndPort}" "${l_dockerRepoInstanceName}" "${l_imageName}" "${l_versionItem}" \
          "${l_dockerRepoAccount}" "${l_dockerRepoPassword}"
        info "目标镜像清除成功"
        #返回: 否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|true"
      else
        warn "目标镜像存在，且当前不是强制覆盖模式，则跳过仓库中现有版本的清除过程"
        #返回: 否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|false"
      fi
    else
      warn "仓库中目标镜像不存在"
      #返回: 否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
      [[ ! "${l_result}" ]] && l_result="true|false|false"
    fi
  done
  gDefaultRetVal="${l_result}"
}

function onBeforePushDockerImage_nexus() {
  export gDefaultRetVal
  export gBuildScriptRootDir

  local l_dockerRepoType=$1
  if [ "${l_dockerRepoType}" != "nexus" ];then
    gDefaultRetVal="false|false|false"
    return
  fi

  if ! type -t "queryNexusComponentId" > /dev/null; then
    source "${gBuildScriptRootDir}/helper/nexus-api-helper.sh"
  fi

  local l_image=$2
  local l_archType=$3
  local l_dockerRepoName=$4
  local l_dockerRepoInstanceName=$5
  local l_dockerRepoWebPort=$6

  local l_imageName
  local l_imageVersion
  local l_versionList
  local l_versionItem
  local l_result

  l_imageName="${l_image%:*}"
  l_imageVersion="${l_image##*:}"

  if [ "${l_archType}" ];then
    l_versionList=("${l_imageVersion}-${l_archType//\//-}")
  else
    l_versionList=("${l_imageVersion}" "${l_imageVersion}-linux-amd64" "${l_imageVersion}-linux-arm64")
  fi

  l_result=""
  # shellcheck disable=SC2068
  for l_versionItem in ${l_versionList[@]};do
    info "在${l_dockerRepoType}类型的docker仓库中查找现存的${l_imageName}:${l_versionItem}镜像..."
    queryNexusComponentId "${l_dockerRepoName%%:*}" "${l_dockerRepoWebPort}" "${l_dockerRepoInstanceName}" "${l_imageName}" "${l_versionItem}"
    if [ "${gDefaultRetVal}" ];then
      if [ "${gForceCoverage}" == "true" ];then
        info "目标镜像存在，且当前是强制覆盖模式，则开始清除仓库中现有版本..."
        deleteNexusComponentById "${l_dockerRepoName%%:*}" "${l_dockerRepoWebPort}" "${gDefaultRetVal}"
        info "目标镜像清除成功"
        #返回: 否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|true"
      else
        warn "目标镜像存在，且当前不是强制覆盖模式，则跳过仓库中现有版本的清除过程"
        #返回: 否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|false"
      fi
    else
      warn "仓库中目标镜像不存在"
      #返回: 是否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
      [[ ! "${l_result}" ]] && l_result="true|false|false"
    fi
  done
  gDefaultRetVal="${l_result}"
}

function onBeforePushDockerImage_registry() {
  export gDefaultRetVal
  export gBuildScriptRootDir

  local l_dockerRepoType=$1
  if [ "${l_dockerRepoType}" != "registry" ];then
    gDefaultRetVal="false|false|false"
    return
  fi

  if ! type -t "queryDigestCodeOfImage" > /dev/null; then
    source "${gBuildScriptRootDir}/helper/registry-api-helper.sh"
  fi

  local l_image=$2
  local l_dockerRepoHostAndPort=$3
  local l_dockerPath=$4
  local l_dockerRepoWebPort=$5
  local l_dockerRepoAccount=$6
  local l_dockerRepoPassword=$7

  local l_imageName
  local l_imageVersion
  local l_versionList
  local l_versionItem
  local l_result

  l_imageName="${l_image%:*}"
  l_imageVersion="${l_image##*:}"

  if [ "${l_archType}" ];then
    l_versionList=("${l_imageVersion}-${l_archType//\//-}")
  else
    l_versionList=("${l_imageVersion}" "${l_imageVersion}-linux-amd64" "${l_imageVersion}-linux-arm64")
  fi

  l_result=""
  # shellcheck disable=SC2068
  for l_versionItem in ${l_versionList[@]};do

    info "在${l_dockerRepoType}类型的docker仓库中查找现存的${l_imageName}:${l_versionItem}镜像..."
    queryDigestCodeOfImage "${l_dockerRepoHostAndPort}" "${l_dockerPath}" "${l_imageName}" "${l_versionItem}"
    if [ "${gDefaultRetVal}" ];then
      if [ "${gForceCoverage}" == "true" ];then
        info "目标镜像存在，且当前是强制覆盖模式，则开始清除仓库中现有版本..."
        deleteImageByDigestCode "${l_dockerRepoHostAndPort}" "${l_dockerPath}" "${l_imageName}" "${l_versionItem}" \
          "${l_dockerRepoAccount}" "${l_dockerRepoPassword}" "${gDefaultRetVal}"
        info "目标镜像清除成功"
        #返回: 否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|true"
      else
        warn "目标镜像存在，且当前不是强制覆盖模式，则跳过仓库中现有版本的清除过程"
        #返回: 否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|false"
      fi
    else
      warn "仓库中目标镜像不存在"
      #返回: 否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
      [[ ! "${l_result}" ]] && l_result="true|false|false"
    fi
  done
  gDefaultRetVal="${l_result}"
}
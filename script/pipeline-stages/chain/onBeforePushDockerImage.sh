#!/usr/bin/env bash

function onBeforePushDockerImage_harbor() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  if [ "${l_dockerRepoType}" != "harbor" ];then
    gDefaultRetVal="false|false|false"
    return
  fi

  if ! type -t "existRepositoryInHarborProject" > /dev/null; then
    source "${gBuildScriptRootDir}/helper/harbor-api-helper.sh"
  fi

  local l_image=$2
  local l_archType=$3
  local l_forceCoverage=$4
  local l_dockerRepoHostAndPort=$5
  local l_dockerRepoInstanceName=$6
  local l_dockerRepoWebPort=$7
  local l_dockerRepoAccount=$8
  local l_dockerRepoPassword=$9

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

    info "on.before.push.docker.image.finding.existing.image" "${l_dockerRepoType}#${l_imageName}#${l_versionItem}" "-n"
    existRepositoryInHarborProject "${l_dockerRepoHostAndPort}" "${l_dockerRepoInstanceName}" "${l_imageName}" "${l_versionItem}"
    if [ "${gDefaultRetVal}" == "true" ];then
      info "on.before.push.docker.image.target.image.exist" "" "*"
      if [ "${l_forceCoverage}" == "true" ];then
        info "on.before.push.docker.image.target.image.exists.force.coverage.clearing" "" "-n"
        deleteRepositoryInHarborProject "${l_dockerRepoHostAndPort}" "${l_dockerRepoInstanceName}" "${l_imageName}" "${l_versionItem}" \
          "${l_dockerRepoAccount}" "${l_dockerRepoPassword}"
        info "on.before.push.docker.image.target.image.cleared.successfully" "" "*"
        #返回: 是否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|true"
      else
        warn "on.before.push.docker.image.target.image.exists.not.force.coverage.skipping" ""
        #返回: 是否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|false"
      fi
    else
      warn "on.before.push.docker.image.target.image.not.found" "" "*"
      #返回: 是否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
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
  local l_forceCoverage=$4
  local l_dockerRepoName=$5
  local l_dockerRepoInstanceName=$6
  local l_dockerRepoWebPort=$7

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
    info "on.before.push.docker.image.finding.existing.image" "${l_dockerRepoType}#${l_imageName}#${l_versionItem}" "-n"
    queryNexusComponentId "${l_dockerRepoName%%:*}" "${l_dockerRepoWebPort}" "${l_dockerRepoInstanceName}" "${l_imageName}" "${l_versionItem}"
    if [ "${gDefaultRetVal}" ];then
      info "on.before.push.docker.image.target.image.exist" "" "*"
      if [ "${l_forceCoverage}" == "true" ];then
        info "on.before.push.docker.image.target.image.exists.force.coverage.clearing" "" "-n"
        deleteNexusComponentById "${l_dockerRepoName%%:*}" "${l_dockerRepoWebPort}" "${gDefaultRetVal}"
        info "on.before.push.docker.image.target.image.cleared.successfully" "" "*"
        #返回: 是否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|true"
      else
        warn "on.before.push.docker.image.target.image.exists.not.force.coverage.skipping" ""
        #返回: 是否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|false"
      fi
    else
      warn "on.before.push.docker.image.target.image.not.found" "" "*"
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
  local l_archType=$3
  local l_forceCoverage=$4
  local l_dockerRepoHostAndPort=$5
  local l_dockerPath=$6
  local l_dockerRepoWebPort=$7
  local l_dockerRepoAccount=$8
  local l_dockerRepoPassword=$9

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
    info "on.before.push.docker.image.finding.existing.image" "${l_dockerRepoType}#${l_imageName}#${l_versionItem}" "-n"
    queryDigestCodeOfImage "${l_dockerRepoHostAndPort}" "${l_dockerPath}" "${l_imageName}" "${l_versionItem}"
    if [ "${gDefaultRetVal}" ];then
      info "on.before.push.docker.image.target.image.exist" "" "*"
      if [ "${l_forceCoverage}" == "true" ];then
        info "on.before.push.docker.image.target.image.exists.force.coverage.clearing" "" "-n"
        deleteImageByDigestCode "${l_dockerRepoHostAndPort}" "${l_dockerPath}" "${l_imageName}" "${l_versionItem}" \
          "${l_dockerRepoAccount}" "${l_dockerRepoPassword}" "${gDefaultRetVal}"
        info "on.before.push.docker.image.target.image.cleared.successfully" "" "*"
        #返回: 是否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|true"
      else
        warn "on.before.push.docker.image.target.image.exists.not.force.coverage.skipping" ""
        #返回: 是否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
        [[ ! "${l_result}" ]] && l_result="true|true|false"
      fi
    else
      warn "on.before.push.docker.image.target.image.not.found" "" "*"
      #返回: 是否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
      [[ ! "${l_result}" ]] && l_result="true|false|false"
    fi
  done
  gDefaultRetVal="${l_result}"
}

function onBeforePushDockerImage_aws-ecr() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  if [ "${l_dockerRepoType}" != "aws-ecr" ];then
    gDefaultRetVal="false|false|false"
    return
  fi

  #返回: 否找到了匹配的调用链方法|目标镜像是否已存在|是否删除成功
  gDefaultRetVal="true|true|true"
}
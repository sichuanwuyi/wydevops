#!/usr/bin/env bash

function onDockerLogin_harbor() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  local l_repoHostAndPort=$2
  local l_repoAccount=$3
  local l_repoPassword=$4

  if [ "${l_dockerRepoType}" != "harbor" ];then
    gDefaultRetVal="false|false|false"
    return
  fi
  #完成docker仓库登录
  dockerLogin "${l_repoHostAndPort}" "${l_repoAccount}" "${l_repoPassword}"
  #返回: 否找到了匹配的调用链方法|是否登录成功
  gDefaultRetVal="true|true"
}

function onDockerLogin_nexus() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  local l_repoHostAndPort=$2
  local l_repoAccount=$3
  local l_repoPassword=$4

  if [ "${l_dockerRepoType}" != "nexus" ];then
    gDefaultRetVal="false|false"
    return
  fi
  #完成docker仓库登录
  dockerLogin "${l_repoHostAndPort}" "${l_repoAccount}" "${l_repoPassword}"
  #返回: 否找到了匹配的调用链方法|是否登录成功
  gDefaultRetVal="true|true"
}

function onDockerLogin_registry() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  local l_repoHostAndPort=$2
  local l_repoAccount=$3
  local l_repoPassword=$4

  if [ "${l_dockerRepoType}" != "registry" ];then
    gDefaultRetVal="false|false"
    return
  fi
  #完成docker仓库登录
  dockerLogin "${l_repoHostAndPort}" "${l_repoAccount}" "${l_repoPassword}"
  #返回: 否找到了匹配的调用链方法|是否登录成功
  gDefaultRetVal="true|true"
}

function onDockerLogin_aws-ecr() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  local l_repoHostAndPort=$2
  local l_repoAccount=$3
  local l_repoPassword=$4

  local l_array
  local l_arrayLen
  local l_region

  if [ "${l_dockerRepoType}" != "aws-ecr" ];then
    gDefaultRetVal="false|false"
    return
  fi

  #aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 749059848629.dkr.ecr.us-east-2.amazonaws.com

  # shellcheck disable=SC2206
  l_array=(${l_repoHostAndPort//./ })
  l_arrayLen=${#l_array[@]}

  if [ "${l_arrayLen}" -lt 3 ];then
    error "on.docker.login.aws.ecr.repo.address.format.error" ""
  fi

  l_region="${l_array[${l_arrayLen}-3]}"

  info "aws ecr get-login-password --region ${l_region} | docker login --username ${l_repoAccount} --password-stdin ${l_repoHostAndPort}"
  aws ecr get-login-password --region "${l_region}" | docker login --username "${l_repoAccount}" --password-stdin "${l_repoHostAndPort}"
  if [ $? -ne 0 ];then
    error "on.docker.login.aws.ecr.login.failed" ""
    return
  fi

  #返回: 否找到了匹配的调用链方法|是否登录成功
  gDefaultRetVal="true|true"
}
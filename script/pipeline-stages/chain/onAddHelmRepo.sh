#!/usr/bin/env bash

function onAddHelmRepo_harbor() {
  export gDefaultRetVal
  local l_chartRepoType=$1

  if [ "${l_chartRepoType}" != "harbor" ];then
    gDefaultRetVal="false|"
    return
  fi

  local l_repoInstanceName=$2
  local l_repoHostAndPort=$3
  local l_account=$4
  local l_password=$5

  local l_result
  local l_errorLog

  #最新版本harbor(2.10+)已经采用oci协议管理chart镜像了。
  #不再需要执行helm repo add。这里转而执行helm registry login命令。

  info "登录Harbor仓库(helm registry login ${l_repoHostAndPort} --insecure -u ${l_account} -p ${l_password})"
  l_result=$(helm registry login "${l_repoHostAndPort}" --insecure -u "${l_account}" -p "${l_password}" 2>&1)
  l_errorLog=$(grep -oE "Login Succeeded" <<< "${l_result}")
  if [ ! "${l_errorLog}" ];then
    error "登录失败:\n${l_result}" "*"
  else
    info "登录成功" "*"
  fi

  gDefaultRetVal="true|true"
}

function onAddHelmRepo_nexus() {
  export gDefaultRetVal

  local l_chartRepoType=$1

  if [ "${l_chartRepoType}" != "nexus" ];then
    gDefaultRetVal="false|"
    return
  fi

  local l_repoInstanceName=$2
  local l_repoHostAndPort=$3
  local l_account=$4
  local l_password=$5

  local l_result
  local l_errorLog

  info "先尝试清除本地缓存中已经存在的${l_repoInstanceName}仓库..." "-n"
  l_result=$(helm repo remove "${l_repoInstanceName}" 2>&1)
  info "清除成功" "*"

  info "再向本地缓存中添加${l_repoInstanceName}仓库信息..." "-n"
  #如果指定了Chart仓库，则需要先登录Chart仓库，为后续Chart镜像推送做准备。
  l_result=$(helm repo add "${l_repoInstanceName}" "http://${l_repoHostAndPort}/repository/${l_repoInstanceName}/" --username "${l_account}" --password "${l_password}" 2>&1)
  l_errorLog=$(grep -iE 'Error|failed' <<< "${l_result}")
  if [ "${l_errorLog}" ];then
    error "添加失败:\n${l_result}" "*"
  else
    info "添加成功" "*"
  fi
  gDefaultRetVal="true|true"
}
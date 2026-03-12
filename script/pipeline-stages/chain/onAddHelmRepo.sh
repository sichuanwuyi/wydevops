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

  info "on.add.helm.repo.logging.in.harbor" "${l_repoHostAndPort}#${l_account}#${l_password}" "-n"
  l_result=$(helm registry login "${l_repoHostAndPort}" --insecure -u "${l_account}" -p "${l_password}" 2>&1)
  l_errorLog=$(grep -oE "Login Succeeded" <<< "${l_result}")
  if [ ! "${l_errorLog}" ];then
    error "on.add.helm.repo.login.failed" "${l_result}" "*"
  else
    info "on.add.helm.repo.login.succeeded" "" "*"
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

  info "on.add.helm.repo.clearing.local.cache" "${l_repoInstanceName}" "-n"
  l_result=$(helm repo remove "${l_repoInstanceName}" 2>&1)
  info "on.add.helm.repo.clear.succeeded" "" "*"

  info "on.add.helm.repo.adding.repo.to.cache" "${l_repoInstanceName}" "-n"
  #如果指定了Chart仓库，则需要先登录Chart仓库，为后续Chart镜像推送做准备。
  l_result=$(helm repo add "${l_repoInstanceName}" "http://${l_repoHostAndPort}/repository/${l_repoInstanceName}/" --username "${l_account}" --password "${l_password}" 2>&1)
  l_errorLog=$(grep -iE 'Error|failed' <<< "${l_result}")
  if [ "${l_errorLog}" ];then
    error "on.add.helm.repo.add.failed" "${l_result}" "*"
  else
    info "on.add.helm.repo.add.succeeded" "" "*"
  fi
  gDefaultRetVal="true|true"
}
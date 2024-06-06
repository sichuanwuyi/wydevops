#!/usr/bin/env bash

function onPushChartImage_harbor() {
  export gDefaultRetVal
  export gBuildScriptRootDir

  local l_chartRepoType=$1

  if [ "${l_chartRepoType}" != "harbor" ];then
    gDefaultRetVal="false|"
    return
  fi

  local l_chartFile=$2
  local l_repoHostAndPort=$3
  local l_repoInstanceName=$4

  local l_result
  local l_errorLog

  info "正在推送${l_chartFile##*/}镜像到chart仓库中..." "-n"
  l_result=$(helm push "${l_chartFile}" "oci://${l_repoHostAndPort}/${l_repoInstanceName}" --plain-http)
  l_errorLog=$(echo "${l_result}" | grep -ioP "^.*(Error|failed).*$")
  if [ "${l_errorLog}" ];then
    error "推送失败:\n${l_result}" "*"
  else
    info "推送成功" "*"
  fi

  gDefaultRetVal="true|true"
}

function onPushChartImage_nexus() {
  export gDefaultRetVal
  export gBuildScriptRootDir

  local l_chartRepoType=$1

  if [ "${l_chartRepoType}" != "nexus" ];then
    gDefaultRetVal="false|"
    return
  fi

  source "${gBuildScriptRootDir}/helper/nexus-api-helper.sh"

  local l_chartFile=$2
  local l_repoHostAndPort=$3
  local l_repoInstanceName=$4
  local l_account=$5
  local l_password=$6

  pushNexusChartComponent "${l_repoHostAndPort%%:*}" "${l_repoHostAndPort##*:}" "${l_repoInstanceName}" \
    "${l_chartFile}" "${l_account}" "${l_password}"

  gDefaultRetVal="true|true"
}

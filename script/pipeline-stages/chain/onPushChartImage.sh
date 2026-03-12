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
  local l_account=$5
  local l_password=$6

  local l_result
  local l_errorLog

  info "on.push.chart.image.logging.into.harbor" "${l_repoHostAndPort}#${l_account}#${l_password}" "-n"
  l_result=$(helm registry login "${l_repoHostAndPort}" --insecure -u "${l_account}" -p "${l_password}" 2>&1)
  l_errorLog=$(grep -o "Login Succeeded" <<< "${l_result}")
  if [ ! "${l_errorLog}" ];then
    error "on.push.chart.image.login.failed" "${l_result}" "*"
  else
    info "on.push.chart.image.login.succeeded" "" "*"
  fi

  info "on.push.chart.image.pushing" "${l_chartFile##*/}" "-n"
  l_result=$(helm push "${l_chartFile}" "oci://${l_repoHostAndPort}/${l_repoInstanceName}" --plain-http)
  l_errorLog=$(grep -o "Error|failed" <<< "${l_result}")
  if [ "${l_errorLog}" ];then
    error "on.push.chart.image.push.failed" "${l_result}" "*"
  else
    info "on.push.chart.image.push.succeeded" "" "*"
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

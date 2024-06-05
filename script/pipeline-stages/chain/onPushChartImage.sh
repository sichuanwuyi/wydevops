#!/usr/bin/env bash

function onPushChartImage_nexus() {
  export gDefaultRetVal
  export gBuildScriptRootDir

  local l_chartRepoType=$1

  if [ "${l_chartRepoType}" != "nexus" ];then
    gDefaultRetVal="false|"
    return
  fi

  source "${gBuildScriptRootDir}/nexus-api-helper.sh"

  local l_chartFile=$2
  local l_repoHostAndPort=$3
  local l_repoInstanceName=$4
  local l_account=$5
  local l_password=$6

  pushNexusChartComponent "${l_repoHostAndPort%%:*}" "${l_repoHostAndPort##*:}" "${l_repoInstanceName}" \
    "${l_chartFile}" "${l_account}" "${l_password}"

  gDefaultRetVal="true|true"
}
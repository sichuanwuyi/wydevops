#!/usr/bin/env bash

function onBeforePushChartImage_harbor() {
  export gDefaultRetVal
  export gBuildScriptRootDir

  local l_chartRepoType=$1

  if [ "${l_chartRepoType}" != "harbor" ];then
    gDefaultRetVal="false|"
    return
  fi

  if ! type -t "existRepositoryInHarborProject" > /dev/null; then
    source "${gBuildScriptRootDir}/helper/harbor-api-helper.sh"
  fi

  local l_imageName=$2
  local l_imageVersion=$3
  local l_repoHostAndPort=$4
  local l_repoInstanceName=$5
  local l_dockerRepoAccount=$6
  local l_dockerRepoPassword=$7

  info "on.before.push.chart.image.finding.existing.image.in.harbor" "${l_chartRepoType}#${l_imageName}-${l_imageVersion}.tgz" "-n"
  existRepositoryInHarborProject "${l_repoHostAndPort}" "${l_repoInstanceName}" "${l_imageName}" "${l_imageVersion}"
  if [ "${gDefaultRetVal}" == "true" ];then
    info "on.before.push.chart.image.target.image.exist" "" "*"
    info "on.before.push.chart.image.target.image.found.start.clearing" "" "-n"
    deleteRepositoryInHarborProject "${l_repoHostAndPort}" "${l_repoInstanceName}" "${l_imageName}" "${l_imageVersion}" \
      "${l_dockerRepoAccount}" "${l_dockerRepoPassword}"
    info "on.before.push.chart.image.target.image.cleared.successfully" "" "*"
  else
    warn "on.before.push.chart.image.target.image.not.found" "" "*"
  fi

  gDefaultRetVal="true|true"

}

function onBeforePushChartImage_nexus() {
  export gDefaultRetVal
  export gBuildScriptRootDir

  local l_chartRepoType=$1

  if [ "${l_chartRepoType}" != "nexus" ];then
    gDefaultRetVal="false|"
    return
  fi

  if ! type -t "existRepositoryInHarborProject" > /dev/null; then
    source "${gBuildScriptRootDir}/helper/nexus-api-helper.sh"
  fi

  local l_imageName=$2
  local l_imageVersion=$3
  local l_repoHostAndPort=$4
  local l_repoInstanceName=$5

  info "on.before.push.chart.image.finding.existing.image.in.nexus" "${l_chartRepoType}#${l_imageName}#${l_imageVersion}" "-n"
  queryNexusComponentId "${l_repoHostAndPort%%:*}" "${l_repoHostAndPort##*:}" "${l_repoInstanceName}" "${l_imageName}" "${l_imageVersion}"
  if [ "${gDefaultRetVal}" ];then
    info "on.before.push.chart.image.target.image.exist" "" "*"
    info "on.before.push.chart.image.target.image.found.start.clearing" "" "-n"
    deleteNexusComponentById "${l_repoHostAndPort%%:*}" "${l_repoHostAndPort##*:}" "${gDefaultRetVal}"
    info "on.before.push.chart.image.target.image.cleared.successfully" "" "*"
  else
    warn "on.before.push.chart.image.target.image.not.found" "" "*"
  fi

  gDefaultRetVal="true|true"
}
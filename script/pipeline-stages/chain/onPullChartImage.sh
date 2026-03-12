#!/usr/bin/env bash

function onPullChartImage_harbor() {
  export gDefaultRetVal

  local l_chartRepoType=$1

  if [ "${l_chartRepoType}" != "harbor" ];then
    gDefaultRetVal="false|"
    return
  fi

  local l_chartName=$2
  local l_chartVersion=$3
  local l_projectName=$4
  local l_destination=$5
  local l_harborAddress=$6
  local l_account=$7
  local l_password=$8

  local l_result
  local l_errorLog

  info "on.pull.chart.image.logging.into.harbor" "${l_harborAddress}#${l_account}#${l_password}" "-n"
  l_result=$(helm registry login "${l_harborAddress}" --insecure -u "${l_account}" -p "${l_password}" 2>&1)
  l_errorLog=$(grep -oE "Login Succeeded" <<< "${l_result}")
  if [ ! "${l_errorLog}" ];then
    error "on.pull.chart.image.login.failed" "${l_result}" "*"
  else
    info "on.pull.chart.image.login.succeeded" "" "*"
  fi

  info "helm pull oci://${l_harborAddress}/${l_projectName}/${l_chartName} --version ${l_chartVersion} --plain-http"
  l_result=$(helm pull "oci://${l_harborAddress}/${l_projectName}/${l_chartName}" --destination "${l_destination}" --version "${l_chartVersion}" --plain-http)
  l_errorLog=$(grep -o "Error|failed" <<< "${l_result}")
  if [ "${l_errorLog}" ];then
    error "on.pull.chart.image.pull.failed" "${l_result}"
  fi

  gDefaultRetVal="true|true"
}

function onPullChartImage_nexus() {
  export gDefaultRetVal

  local l_chartRepoType=$1

  if [ "${l_chartRepoType}" != "nexus" ];then
    gDefaultRetVal="false|"
    return
  fi

  local l_chartName=$2
  local l_chartVersion=$3
  local l_repoInstanceName=$4
  local l_destination=$5

  local l_result
  local l_errorLog

  #更新本地库
  info "helm repo update" ""
  helm repo update

  #拉取Chart镜像
  info "helm pull ${l_repoInstanceName}/${l_chartName} --destination ${l_destination} --version ${l_chartVersion}" ""
  l_result=$(helm pull "${l_repoInstanceName}/${l_chartName}" --destination "${l_destination}" --version "${l_chartVersion}" 2>&1)
  l_errorLog=$(grep -p "Error|failed" <<< "${l_result}")
  if [ "${l_errorLog}" ];then
    error "on.pull.chart.image.pull.from.repo.failed" "${l_result}"
  fi

  gDefaultRetVal="true|true"
}
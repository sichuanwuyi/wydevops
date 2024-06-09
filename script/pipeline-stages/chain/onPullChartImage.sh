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

  local l_result
  local l_errorLog

  echo "helm pull oci://${l_harborAddress}/${l_projectName}/${l_chartName} --version ${l_chartVersion}"
  l_result=$(helm pull "oci://${l_harborAddress}/${l_projectName}/${l_chartName}" --version "${l_chartVersion}")
  l_errorLog=$(echo -e "${l_errorLog}" | grep -ioP "^(.*)(Error|failed)(.*)$")
  if [ "${l_errorLog}" ];then
    error "从chart镜像仓库拉取镜像失败:${l_result}"
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
  echo "helm repo update"
  helm repo update

  #拉取Chart镜像
  echo "helm pull ${l_repoInstanceName}/${l_chartName} --destination ${l_destination} --version ${l_chartVersion}"
  l_result=$(helm pull "${l_repoInstanceName}/${l_chartName}" --destination "${l_destination}" --version "${l_chartVersion}" 2>&1)
  l_errorLog=$(echo -e "${l_errorLog}" | grep -ioP "^(.*)(Error|failed)(.*)$")
  if [ "${l_errorLog}" ];then
    error "从镜像仓库拉取chart镜像失败:${l_result}"
  fi

  gDefaultRetVal="true|true"
}
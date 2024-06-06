#!/usr/bin/env bash

function addHelmRepo() {
  #执行onAddHelmRepo调用链。
  invokeExtendChain "onAddHelmRepo" "${@}"
}

function pushChartImage() {
  export gChartRepoType

  local l_chartFile=$1
  local l_repoInstanceName=$2
  local l_repoHostAndPort=$3
  local l_account=$4
  local l_password=$5

  local l_tmpFile
  local l_imageName
  local l_imageVersion

  l_tmpFile="${l_chartFile##*/}"
  l_imageName="${l_tmpFile%-*}"
  l_imageVersion="${l_chartFile##*-}"
  l_imageVersion="${l_imageVersion%.*}"

  #执行推送前调用链: 先删除已经存在的同名同版本镜像。
  invokeExtendChain "onBeforePushChartImage" "${gChartRepoType}" "${l_imageName}" "${l_imageVersion}" \
    "${l_repoHostAndPort}" "${l_repoInstanceName}"

  #执行推送调用链
  invokeExtendChain "onPushChartImage" "${gChartRepoType}" "${l_chartFile}" "${l_repoHostAndPort}" \
    "${l_repoInstanceName}" "${l_account}" "${l_password}"

}

function pullChartImage() {
  local l_chartName=$1
  local l_chartVersion=$2
  local l_repoAliasName=$3
  local l_destination=$4

  local l_errorLog

  if [ ! -d "${l_destination}" ];then
    mkdir -p "${l_destination}"
  fi

  #更新本地库
  echo "helm repo update"
  helm repo update

  #拉取Chart镜像
  echo "helm pull ${l_repoAliasName}/${l_chartName} --destination ${l_destination} --version ${l_chartVersion}"
  l_errorLog=$(helm pull "${l_repoAliasName}/${l_chartName}" --destination "${l_destination}" --version "${l_chartVersion}" 2>&1)
  l_errorLog=$(echo -e "${l_errorLog}" | grep -ioP "^(.*)(Error|failed)(.*)$")
  if [ "${l_errorLog}" ];then
    error "从${l_repoAliasName}镜像仓库拉取Chart镜像失败:${l_errorLog}"
  fi
}
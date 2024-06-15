#!/usr/bin/env bash

function addHelmRepo() {
  #执行onAddHelmRepo调用链。
  invokeExtendChain "onAddHelmRepo" "${@}"
}

function pushChartImage() {

  local l_chartFile=$1
  local l_chartRepoType=$2
  local l_repoInstanceName=$3
  local l_repoHostAndPort=$4
  local l_account=$5
  local l_password=$6

  local l_tmpFile
  local l_imageName
  local l_imageVersion

  l_tmpFile="${l_chartFile##*/}"
  l_imageName="${l_tmpFile%-*}"
  l_imageVersion="${l_chartFile##*-}"
  l_imageVersion="${l_imageVersion%.*}"

  #执行推送前调用链: 先删除已经存在的同名同版本镜像。
  invokeExtendChain "onBeforePushChartImage" "${l_chartRepoType}" "${l_imageName}" "${l_imageVersion}" \
    "${l_repoHostAndPort}" "${l_repoInstanceName}" "${l_account}" "${l_password}"

  #执行推送调用链
  invokeExtendChain "onPushChartImage" "${l_chartRepoType}" "${l_chartFile}" "${l_repoHostAndPort}" \
    "${l_repoInstanceName}" "${l_account}" "${l_password}"
}

function pullChartImage() {
  local l_chartName=$1
  local l_chartVersion=$2
  local l_chartRepoType=$3
  local l_chartRepoName=$4
  local l_repoInstanceName=$5
  local l_destination=$6
  local l_account=$7
  local l_password=$8

  if [ ! -d "${l_destination}" ];then
    mkdir -p "${l_destination}"
  fi

  #执行推送调用链
  invokeExtendChain "onPullChartImage" "${l_chartRepoType}" "${l_chartName}" "${l_chartVersion}" \
    "${l_repoInstanceName}" "${l_destination}" "${l_chartRepoName}" "${l_account}" "${l_password}"

}
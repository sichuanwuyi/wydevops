#!/usr/bin/env bash

function unzipOfflinePackage() {
  export gOfflinePackage
}

function loadAndPushDockerImage() {
  export gOfflinePackage

}

function dispatchOfflinePackage() {
   export gOfflinePackage
}

function dispatchOfflinePackage() {
   export gOfflinePackage
}

function parallelInstallService() {
   export gOfflinePackage
}

_chartName=$1
_chartVersion=$2
_offlinePackage=$3
_dockerRepoName=$4
_dockerRepoAccount=$5
_dockerRepoPassword=$6
_nodeInfoList=$7

echo "-----_chartName=${_chartName}-----"
echo "-----_chartVersion=${_chartVersion}-----"
echo "-----_offlinePackage=${_offlinePackage}-----"
echo "-----_dockerRepoName=${_dockerRepoName}-----"
echo "-----_dockerRepoAccount=${_dockerRepoAccount}-----"
echo "-----_dockerRepoPassword=${_dockerRepoPassword}-----"
echo "-----_nodeInfoList=${_nodeInfoList}-----"

# shellcheck disable=SC2164
_selfRootDir=$(cd "$(dirname "$0")"; pwd)

if [  -f "${_selfRootDir}/${gOfflinePackage}" ];then
  #解压缩离线安装包
  unzipOfflinePackage
  #导入离线安装包中的docker镜像，并推送到Docker镜像仓库中
  loadAndPushDockerImage
  #如果镜像仓库不存在，则使用ansible将离线安装包分发到其他服务器上。
  if [ ! "${gDockerRepoName}" ];then
    #分发离线安装包。
    dispatchOfflinePackage
  fi
fi

if [ -f "${_selfRootDir}/docker-run.sh" ];then
  #后台直接执行docker-run.sh
  bash "${_selfRootDir}/docker-run.sh" &
elif [ -f "${_selfRootDir}/docker-compose.yaml" ];then
  #后台docker-compose方式启动
  docker-compose -d -f "${_selfRootDir}/docker-compose.yaml" up &
fi

if [[  -f "${_selfRootDir}/${gOfflinePackage}" &&  ! "${gDockerRepoName}" ]];then
  #通过ansible分发离线安装包。
  dispatchOfflinePackageToRemoteNode
  #通过ansible同时在多个服务器上拉起docker容器运行服务。
  parallelRemoteInstallService
fi
#!/usr/bin/env bash

function unzipOfflinePackage() {
  export resultVal

  local l_offlinePackage=$1
  local l_chartName=$2

  resultVal="true"

  #创建解压文件存放目录
  mkdir "${l_offlinePackage%/*}/${l_chartName}"
  #解压文件到当前目录下。
  echo "tar -zxvf ${l_offlinePackage} -C ${l_offlinePackage%/*}/${l_chartName}"
  tar -zxvf "${l_offlinePackage}" -C "${l_offlinePackage%/*}/${l_chartName}" 2>&1
  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    error "remote.install.proxy.sh.unzip.offline.package" "${l_offlinePackage##*/}"
    resultVal="false"
  fi
}

function loadAndPushDockerImage() {
  export resultVal

  local l_targetDir=$1
  local l_dockerRepoName=$2
  local l_dockerRepoAccount=$3
  local l_dockerRepoPassword=$4

  local l_fileList
  local l_file
  local l_errorLog
  local l_image

  resultVal="true"

  if [ "${l_dockerRepoName}" ];then
    echo "${l_dockerRepoPassword}" | docker login "${l_dockerRepoName}" -u "${l_dockerRepoAccount}" --password-stdin
    # shellcheck disable=SC2181
    if [[ "$?" -ne 0 ]];then
      echo "登录docker仓库失败：echo ${l_dockerRepoPassword} | docker login ${l_dockerRepoName} -u ${l_dockerRepoAccount} --password-stdin"
      resultVal="false"
      return
    fi
  fi

  l_fileList=$(find "${l_targetDir}" -type f -name "*.tar")
  # shellcheck disable=SC2068
  for l_file in ${l_fileList[@]};do
    l_errorLog=$(docker load -i "${l_file}" 2>&1)
    l_errorLog=$(echo -e "${l_errorLog}" | grep -oE "^Loaded image:(.*)$")
    if [ "${l_errorLog}" ];then
      l_image="${l_errorLog#*:}"
      l_image="${l_image// /}"
      echo "成功加载docker镜像：${l_image}"

      if [ "${l_dockerRepoName}" ];then
        #镜像更名
        docker tag "${l_image}" "${l_dockerRepoName}/${l_image}"
        #推送镜像到仓库中
        docker push "${l_dockerRepoName}/${l_image}" 2>&1
        # shellcheck disable=SC2181
        if [ "$?" -ne 0 ];then
          echo "${l_image}镜像推送失败"
          resultVal="false"
          break
        fi
      fi

    else
      echo "从${l_file##*/}文件加载docker镜像失败"
      resultVal="false"
      break
    fi
  done

}

function pullDockerImage(){
  export resultVal

  local l_dockerRepoName=$1
  local l_dockerImageName=$2
  local l_archType=$3
  local l_dockerRepoAccount=$4
  local l_dockerRepoPassword=$5

  if [ -z "${l_dockerRepoName}" ];then
    resultVal="false"
    return
  fi

  echo "${l_dockerRepoPassword}" | docker login "${l_dockerRepoName}" -u "${l_dockerRepoAccount}" --password-stdin
  # shellcheck disable=SC2181
  if [[ "$?" -ne 0 ]];then
    echo "登录docker仓库失败：echo ${l_dockerRepoPassword} | docker login ${l_dockerRepoName} -u ${l_dockerRepoAccount} --password-stdin"
    resultVal="false"
    return
  fi

  echo "从${l_dockerRepoName}拉取docker镜像..."
  docker pull --platform="${l_archType}" "${l_dockerRepoName}/${l_dockerImageName}"
  if [ "$?" -ne 0 ];then
    echo "拉取${l_dockerRepoName}/${l_dockerImageName}镜像失败"
    resultVal="false"
    return
  fi

  resultVal="true"
}

function execute(){
  export resultVal

  local l_chartName=$1
  local l_chartVersion=$2
  local l_archType=$3
  local l_forceDeployArchType=$4
  local l_offlinePackage=$5
  local l_dockerRepoName=$6
  local l_dockerRepoAccount=$7
  local l_dockerRepoPassword=$8
  local l_nodeInfoList=$9

  local l_selfRootDir
  local l_dockerFilePath

  # shellcheck disable=SC2164
  l_selfRootDir=$(cd "$(dirname "$0")"; pwd)

  if [  -f "${l_selfRootDir}/${l_offlinePackage}" ];then
    l_dockerFilePath="${l_selfRootDir}"
    if [[ "${l_offlinePackage}" =~ ^(.*).tar.gz$ ]];then
      #解压缩离线安装包
      unzipOfflinePackage "${l_selfRootDir}/${l_offlinePackage}" "${l_chartName}"
      [[ "${resultVal}" == "false" ]] && return
      l_dockerFilePath="${l_selfRootDir}/${l_chartName}/docker"
    fi
    #导入离线安装包中的docker镜像，并如果存在Docker镜像仓库则推送到Docker镜像仓库中
    loadAndPushDockerImage "${l_dockerFilePath}" "${l_dockerRepoName}" "${l_dockerRepoAccount}" "${l_dockerRepoPassword}"
    [[ "${resultVal}" == "false" ]] && return
  elif [ "${l_dockerRepoName}" ];then
    #从Docker镜像仓库拉取Docker镜像
    pullDockerImage "${l_dockerRepoName}" "${l_chartName}:${l_chartVersion}" "${l_dockerRepoAccount}" "${l_dockerRepoPassword}"
    [[ "${resultVal}" == "false" ]] && return
  else
    echo "找不到Docker镜像"
    return
  fi

  #先确保本地拉起Docker镜像。
  if [ -f "${l_selfRootDir}/docker-run.sh" ];then
    echo "执行\"docker run\"命令,拉起发布的服务..."
    bash "${l_selfRootDir}/docker-run.sh" &
  elif [ -f "${l_selfRootDir}/docker-compose.yaml" ];then
    echo "执行\"docker compose\"命令,拉起发布的服务..."
    docker-compose -d -f "${l_selfRootDir}/docker-compose.yaml" up &
  fi

}

export resultVal

execute "${@}"
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
    echo "${l_offlinePackage##*/}文件解压失败"
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

  l_targetDir="${l_targetDir}/docker"
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

function execute(){
  export resultVal

  local l_chartName=$1
  local l_chartVersion=$2
  local l_offlinePackage=$3
  local l_dockerRepoName=$4
  local l_dockerRepoAccount=$5
  local l_dockerRepoPassword=$6
  local l_nodeInfoList=$7

  local l_selfRootDir

  # shellcheck disable=SC2164
  l_selfRootDir=$(cd "$(dirname "$0")"; pwd)

  if [[  -f "${l_selfRootDir}/${l_offlinePackage}" && ! "${l_dockerRepoName}" ]];then
    #解压缩离线安装包
    unzipOfflinePackage "${l_selfRootDir}/${l_offlinePackage}" "${l_chartName}"
    [[ "${resultVal}" == "false" ]] && return
    #导入离线安装包中的docker镜像，并如果存在Docker镜像仓库则推送到Docker镜像仓库中
    loadAndPushDockerImage "${l_selfRootDir}/${l_chartName}" "${l_dockerRepoName}" \
      "${l_dockerRepoAccount}" "${l_dockerRepoPassword}"
    [[ "${resultVal}" == "false" ]] && return
  fi

  #先确保本地拉起Docker镜像。
  if [ -f "${l_selfRootDir}/docker-run.sh" ];then
    echo "执行\"docker run\"命令,拉起发布的服务..."
    bash "${l_selfRootDir}/docker-run.sh" &
  elif [ -f "${l_selfRootDir}/docker-compose.yaml" ];then
    echo "执行\"docker compose\"命令,拉起发布的服务..."
    docker-compose -d -f "${l_selfRootDir}/docker-compose.yaml" up &
  elif [ -f "${l_selfRootDir}/${l_chartName}/chart/${l_chartName}-${l_chartVersion}.tgz" ];then
    #通过helm安装k8s应用
    echo "执行\"helm upgrade --install\"命令,拉起发布的服务..."
    helm
  fi

}

export resultVal

execute "${@}"
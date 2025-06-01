#!/usr/bin/env bash

function queryDigestCodeOfImage() {
  export gDefaultRetVal

  local l_dockerRepoHostAndPort=$1
  local l_dockerPath=$2
  local l_imageFullName=$3
  local l_imageVersion=$4

  local l_imageName
  local l_result
  local l_content

  l_imageName="${l_imageFullName##*/}"

  gDefaultRetVal=""

  l_result=$(curl -s --header "Accept: application/vnd.docker.distribution.manifest.v2+json" -I \
    "http://${l_dockerRepoHostAndPort}/v2/${l_dockerPath}/${l_imageName}/manifests/${l_imageVersion}" 2>&1 | grep "^Docker-Content-Digest:")

  if [ "${l_result}" ];then
    l_content="${l_result#*:}"
    gDefaultRetVal="${l_content:1}"
  fi

}

function deleteImageByDigestCode() {
  export gDefaultRetVal
  #对于registry类型的仓库，指定其registry服务名称
  export gRegistryName
  #对于registry类型的仓库，指定其配置文件全路径名称
  export gRegistryConfigFile

  local l_dockerRepoHostAndPort=$1
  local l_dockerPath=$2
  local l_imageFullName=$3
  local l_imageVersion=$4
  local l_dockerRepoAccount=$5
  local l_dockerRepoPassword=$6
  local l_digestCode=$7

  local l_imageName
  local l_result

  local l_array
  local l_size

  local l_rowDatas
  local l_containerId
  local l_cmdPrefix
  local l_defaultConfigFile
  local l_configFile

  l_imageName="${l_imageFullName##*/}"

  gDefaultRetVal=""

  #先删除manifests数据。
  l_result=$(curl -s -u "${l_dockerRepoAccount}":"${l_dockerRepoPassword}" -X DELETE "http://${l_dockerRepoHostAndPort}/v2/${l_dockerPath}/${l_imageName}/manifests/${l_digestCode}" 2>&1)
  if [ "${l_result}" ];then
    error "删除现存的${l_imageName}:${l_imageVersion}镜像失败：${l_result}"
  fi
  info "成功删除manifests数据"

  if [ "${gRegistryName}" ];then
    # shellcheck disable=SC2206
    l_array=(${gRegistryName//|/ })

    l_cmdPrefix=""
    #todo：官方registry:3.0.0-rc.2镜像中配置文件是/etc/distribution/config.yml。
    #todo: 不同版本的registry镜像其配置文件config.yml保存的路径可能是不同的。
    l_defaultConfigFile="/etc/distribution/config.yml"

    l_configFile="${l_defaultConfigFile}"
    [[ "${gRegistryConfigFile}" ]] && l_configFile="${gRegistryConfigFile}"

    l_size=${#l_array[@]}
    if [ "${l_size}" -ge 4 ];then
      _remoteDeleteImageByBlobData "${@}"
      return
    fi

    winpty --version
    # shellcheck disable=SC2181
    if [ "${?}" == 0 ];then
      l_cmdPrefix="winpty"
      l_configFile="/${l_configFile}"
      l_defaultConfigFile="/${l_defaultConfigFile}"
    fi

    #再清除容器中对应的blobs数据。
    #获取docker-registry镜像的ID。
    l_rowDatas=$(docker ps -a | grep -oE ".*${l_array[0]}")
    if [ "${l_rowDatas}" ];then
      # shellcheck disable=SC2068
      for l_containerId in ${l_rowDatas[@]};do
        #回收无效的blobs数据。
        "${l_cmdPrefix}" docker exec -d "${l_containerId}" registry garbage-collect "${l_defaultConfigFile}"
        # shellcheck disable=SC2181
        if [[ "${?}" -ne 0 && ${l_configFile} != "${l_defaultConfigFile}" ]];then
          info "清除无效的镜像数据时，使用指定的配置文件全路径名称：${l_configFile}"
          "${l_cmdPrefix}" docker exec -d "${l_containerId}" registry garbage-collect "${l_configFile}"
        fi
        # shellcheck disable=SC2181
        if [ "${?}" -eq 0 ];then
          info "成功清除无效的镜像数据"
        else
          warn "清除无效的镜像数据失败"
        fi
        break
      done
    else
      warn "未能查询到名称为${gRegistryName}的Registry镜像仓库服务。"
      warn "请定时使用\"registry garbage-collect {registry配置文件}\"命令清除仓库中的无效镜像数据。"
    fi

  fi
}

function _remoteDeleteImageByBlobData() {
  export gDefaultRetVal
  #对于registry类型的仓库，指定其registry服务名称
  export gRegistryName
  #对于registry类型的仓库，指定其配置文件全路径名称
  export gRegistryConfigFile

  local l_result
  local l_array

  local l_rowDatas
  local l_containerId
  local l_defaultConfigFile
  local l_configFile

  # shellcheck disable=SC2206
  l_array=(${gRegistryName//|/ })

  #todo：官方registry:3.0.0-rc.2镜像中配置文件是/etc/distribution/config.yml。
  #todo: 不同版本的registry镜像其配置文件config.yml保存的路径可能是不同的。
  l_defaultConfigFile="/etc/distribution/config.yml"

  l_configFile="${l_defaultConfigFile}"
  [[ "${gRegistryConfigFile}" ]] && l_configFile="${gRegistryConfigFile}"

  #再清除容器中对应的blobs数据。
  #获取docker-registry镜像的ID。
  l_rowDatas=$(ssh -o "StrictHostKeyChecking no" -p "${l_array[2]}" "${l_array[3]}@${l_array[1]}" docker ps -a | grep -oE ".*${l_array[0]}")
  if [ "${l_rowDatas}" ];then
    # shellcheck disable=SC2068
    for l_containerId in ${l_rowDatas[@]};do
      #回收无效的blobs数据。
      ssh -o "StrictHostKeyChecking no" -p "${l_array[2]}" "${l_array[3]}@${l_array[1]}" docker exec -d "${l_containerId}" registry garbage-collect "${l_configFile}"
      if [ "${l_defaultConfigFile}" != "${l_configFile}" ];then
        ssh -o "StrictHostKeyChecking no" -p "${l_array[2]}" "${l_array[3]}@${l_array[1]}" docker exec -d "${l_containerId}" registry garbage-collect "${l_defaultConfigFile}"
      fi
      info "成功清除无效的镜像数据"
      break
    done
  else
    warn "未能在${l_array[1]}服务器上远程查询到名称为${l_array[0]}的Registry镜像仓库服务。"
    warn "请定时使用\"registry garbage-collect {registry配置文件}\"命令清除仓库中的无效镜像数据。"
  fi

}


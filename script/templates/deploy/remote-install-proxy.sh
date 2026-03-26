#!/usr/bin/env bash

function unzipOfflinePackage() {
  export resultVal

  local l_offlinePackage=$1
  local l_chartName=$2

  local l_errorLog

  resultVal="false"

  #创建解压文件存放目录
  mkdir "${l_offlinePackage%/*}/${l_chartName}"

  info "remote.install.sh.unzipping.offline.package" "${l_offlinePackage##*/}#${l_chartName}" "-n"
  #解压文件到当前目录下。
  l_errorLog=$(tar -zxvf "${l_offlinePackage}" -C "${l_offlinePackage%/*}/${l_chartName}" 2>&1)
  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    error warn "remote.install.sh.execute.failed" "${l_errorLog}" "*"
  fi
  warn "remote.install.sh.execute.success" "" "*"
  resultVal="false"
}

function loadAndPushDockerImage() {
  export resultVal

  local l_targetDir=$1
  local l_dockerRepoName=$2
  local l_archType=$3
  local l_dockerRepoAccount=$4
  local l_dockerRepoPassword=$5

  local l_fileList
  local l_file
  local l_errorLog
  local l_image

  resultVal="false"

  if [ "${l_dockerRepoName}" ];then
    info "remote.install.sh.executing.docker.login.command" "" "-n"
    l_errorLog=$(echo "${l_dockerRepoPassword}" | docker login "${l_dockerRepoName}" -u "${l_dockerRepoAccount}" --password-stdin 2>&1)
    # shellcheck disable=SC2181
    if [[ "$?" -ne 0 ]];then
      error "remote.install.sh.execute.failed" "${l_errorLog}" "*"
    fi
    warn "remote.install.sh.execute.success" "" "*"
  fi

  l_fileList=$(find "${l_targetDir}" -type f -name "*.tar")
  # shellcheck disable=SC2068
  for l_file in ${l_fileList[@]};do
    info "remote.install.sh.loading.images" "${l_file##*/}" "-n"
    l_errorLog=$(docker load -i "${l_file}" 2>&1)
    if [ "$?" -eq 0 ];then
      l_image="${l_errorLog#*:}"
      l_image="${l_image// /}"
      warn "${l_image}" "" "*"

      if [ "${l_dockerRepoName}" ];then
        info "remote.install.sh.pushing.images" "${l_archType}#${l_image}#${l_dockerRepoName}" "-n"
        #镜像更名
        l_errorLog=$(docker tag "${l_image}" "${l_dockerRepoName}/${l_image}" 2>&1)
        # shellcheck disable=SC2181
        if [ "$?" -ne 0 ];then
          error "remote.install.sh.execute.failed" "${l_errorLog}" "*"
        fi
        #推送镜像到仓库中，这里要
        l_errorLog=$(docker push --platform="${l_archType}" "${l_dockerRepoName}/${l_image}" 2>&1)
        # shellcheck disable=SC2181
        if [ "$?" -ne 0 ];then
          error "remote.install.sh.execute.failed" "${l_errorLog}" "*"
        fi
        warn "remote.install.sh.execute.success" "" "*"
      fi
    else
      error "remote.install.sh.execute.failed" "${l_errorLog}" "*"
    fi
  done
  resultVal="true"
}

function pullDockerImage(){
  export resultVal

  local l_dockerRepoName=$1
  local l_dockerImageName=$2
  local l_archType=$3
  local l_dockerRepoAccount=$4
  local l_dockerRepoPassword=$5

  local l_errorLog

  resultVal="false"
  if [ -z "${l_dockerRepoName}" ];then
    return
  fi

  info "remote.install.sh.executing.docker.login.command" "" "-n"
  l_errorLog=$(echo "${l_dockerRepoPassword}" | docker login "${l_dockerRepoName}" -u "${l_dockerRepoAccount}" --password-stdin 2>&1)
  # shellcheck disable=SC2181
  if [[ "$?" -ne 0 ]];then
    error "remote.install.sh.execute.failed" "${l_errorLog}" "*"
  fi
  warn "remote.install.sh.execute.success" "" "*"

  echo "remote.install.sh.pulling.images" "${l_dockerRepoName}#${l_archType}#${l_image}"
  l_errorLog=$(docker pull --platform="${l_archType}" "${l_dockerRepoName}/${l_dockerImageName}" 2>&1)
  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    error "remote.install.sh.execute.failed" "${l_errorLog}" "*"
  fi
  warn "remote.install.sh.execute.success" "" "*"

  resultVal="true"
}

function _install_tonistiigi_binfmt() {

  local l_localArchType=$1
  local l_imageCacheDir=$2
  local l_dockerRepoName=$3

  local l_errorLog

  info "remote.install.sh.checking.qemu.image.exists" "tonistiigi/binfmt:latest" "-n"
  l_errorLog=$(docker image inspect tonistiigi/binfmt:latest >/dev/null 2>&1)
  # shellcheck disable=SC2181
  if [ "$?" -eq 0 ];then
    warn "remote.install.sh.image.already.exists" "" "*"
    return
  fi
  warn "remote.install.sh.image.not.exists" "" "*"

  if [ "${l_dockerRepoName}" ];then
   info "remote.install.sh.installing.qemu.docker.image" "${l_dockerRepoName}/tonistiigi/binfmt:latest" "-n"
   l_errorLog=$(docker run --rm --privileged "${l_dockerRepoName}/tonistiigi/binfmt:latest" --install all 2>&1)
   if [ "$?" -eq 0 ];then
     warn "remote.install.sh.execute.success" "" "*"
     return
   fi
   warn "remote.install.sh.execute.failed" "\n${l_errorLog}" "*"
  fi

  info "remote.install.sh.find.qemu.image.export.file.from.local.cache" "${l_imageCacheDir}#tonistiigi_binfmt-latest-${l_localArchType//\//-}.tar" "-n"
  if [ -f "${l_imageCacheDir}/tonistiigi_binfmt-latest-${l_localArchType//\//-}.tar" ];then
    warn "remote.install.sh.execute.success" "" "*"
    info "remote.install.sh.load.qemu.image.from.file" "tonistiigi/binfmt:latest" "-n"
    l_errorLog=$(docker load -i "${l_imageCacheDir}/tonistiigi_binfmt-latest-${l_localArchType//\//-}.tar" 2>&1)
    if [ "$?" -eq 0 ];then
      warn "remote.install.sh.execute.success" "" "*"
    else
      warn "remote.install.sh.execute.failed" "\n${l_errorLog}" "*"
    fi
  else
    warn "remote.install.sh.execute.failed" "" "*"
  fi

  info "remote.install.sh.installing.qemu.docker.image" "tonistiigi/binfmt:latest" "-n"
  l_errorLog=$(docker run --rm --privileged tonistiigi/binfmt:latest --install all 2>&1)
  if [ "$?" -ne 0 ];then
    error "remote.install.sh.execute.failed" "\n${l_errorLog}" "*"
  fi
  warn "remote.install.sh.execute.success" "" "*"
  info "remote.install.sh.install.qemu.image.complete" "tonistiigi/binfmt:latest"
}

function execute(){
  export resultVal

  local l_chartName=$1
  local l_chartVersion=$2
  local l_curArchType=$3
  local l_targetArchType=$4
  local l_offlinePackage=$5
  local l_dockerRepoName=$6
  local l_dockerRepoAccount=$7
  local l_dockerRepoPassword=$8
  local l_nodeInfoList=$9

  local l_selfRootDir
  local l_dockerFilePath
  local l_errorLog

  # shellcheck disable=SC2164
  l_selfRootDir=$(cd "$(dirname "$0")"; pwd)

  if [ "${l_dockerRepoName}" ];then
    #从Docker镜像仓库拉取Docker镜像
    pullDockerImage "${l_dockerRepoName}" "${l_chartName}:${l_chartVersion}" "${l_targetArchType}" \
      "${l_dockerRepoAccount}" "${l_dockerRepoPassword}"
    [[ "${resultVal}" == "false" ]] && return
  elif [ -f "${l_selfRootDir}/${l_offlinePackage}" ];then
    l_dockerFilePath="${l_selfRootDir}"
    if [[ "${l_offlinePackage}" =~ ^(.*).tar.gz$ ]];then
      #解压缩离线安装包
      unzipOfflinePackage "${l_selfRootDir}/${l_offlinePackage}" "${l_chartName}"
      [[ "${resultVal}" == "false" ]] && return
      l_dockerFilePath="${l_selfRootDir}/${l_chartName}/docker"
    fi
    #导入离线安装包中的docker镜像，并如果存在Docker镜像仓库则推送到Docker镜像仓库中
    loadAndPushDockerImage "${l_dockerFilePath}" "${l_dockerRepoName}" "${l_targetArchType}" \
      "${l_dockerRepoAccount}" "${l_dockerRepoPassword}"
    [[ "${resultVal}" == "false" ]] && return
  else
    error "remote.install.sh.no.any.target.image"
  fi

  #安装qemu镜像，用于运行不同架构的其他镜像。
  if [ "${l_targetArchType}" != "${l_curArchType}" ];then
    _install_tonistiigi_binfmt "${l_targetArchType}" "${l_selfRootDir}/cachedImages" "${l_dockerRepoName}"
  fi

  #先确保本地拉起Docker镜像。
  if [ -f "${l_selfRootDir}/docker-run.sh" ];then
    info "remote.install.sh.execute.docker.run"
    l_errorLog=$(bash "${l_selfRootDir}/docker-run.sh" "${l_targetArchType}" & )
    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ];then
      error "remote.install.sh.execute.failed" "\n${l_errorLog}" "*"
    else
      warn "remote.install.sh.execute.success" "" "*"
    fi
  elif [ -f "${l_selfRootDir}/docker-compose.yaml" ];then
    info "remote.install.sh.execute.docker.compose.run"
    l_errorLog=$(docker-compose -d -f "${l_selfRootDir}/docker-compose.yaml" up &)
    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ];then
      error "remote.install.sh.execute.failed" "\n${l_errorLog}" "*"
    else
      warn "remote.install.sh.execute.success" "" "*"
    fi
  fi

}

export resultVal
export gMessagePropertiesMap

if [[ "${gMessagePropertiesMap}" && "${#gMessagePropertiesMap[@]}" -eq 0 ]]; then
  #获取脚本所在的根目录
  export _selfRootDir
  _selfRootDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -L)"
  #convertI18NText方法的返回值变量。
  export gLogI18NRetVal
  #引入工作模式全局变量,jenkins模式下输出的日志不设置颜色。
  export gWorkMode
  gWorkMode="local"
  # 申明全局调试模式指示变量，用于debug函数内控制信息的显示
  export gDebugMode
  gDebugMode="false"
  # 申明默认调试文件输出目录
  export gDebugOutDir
  gDebugOutDir="${_selfRootDir}/debug"
  #引入的全局临时文件目录
  export gTempFileDir
  gTempFileDir="${_selfRootDir}/temp"
  #引入yaml-helper.yaml文件中的文件内存缓存变量
  #在删除文件时需要同步清除缓存中的内容。
  export gFileContentMap
  source "${_selfRootDir}/log-helper.sh"
fi

execute "${@}"
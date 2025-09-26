#!/usr/bin/env bash

function dockerLogin(){
  export gTempFileDir

  local l_repoName=$1
  local l_account=$2
  local l_password=$3

  local l_tmpFile
  local l_tmpFileContent
  local l_errorLog

  if [ "${l_repoName}" ];then
    info "执行命令(docker logout ${l_repoName} && echo ${l_password} | docker login ${l_repoName} -u ${l_account} --password-stdin)..." "-n"
    # shellcheck disable=SC2088
    l_tmpFile="${gTempFileDir}/docker-${RANDOM}.tmp"
    registerTempFile "${l_tmpFile}"
    #先执行登出（避免某些情况下直接登入失败）,再执行登入。
    docker logout "${l_repoName}" && echo "${l_password}" | docker login "${l_repoName}" -u "${l_account}" --password-stdin  2>&1 | tee "${l_tmpFile}"
    # shellcheck disable=SC2002
    l_tmpFileContent=$(cat "${l_tmpFile}")
    l_errorLog=$(grep -E "^.*(Error|failed|panic).*$" <<< "${l_tmpFileContent}")
    unregisterTempFile "${l_tmpFile}"
    # shellcheck disable=SC2015
    if [[ "${l_errorLog}" ]];then
      error "失败：请检查网络并确保docker配置文件(daemon.json)中insecure-registries数组参数中已经添加了${l_repoName}\n${l_tmpFileContent}" "*"
    else
      info "成功" "*"
    fi
  fi
}

function pullImage(){
  export gDefaultRetVal

  local l_image=$1
  local l_archType=$2
  local l_repoName=$3
  local l_imageCachedDir=$4
  local l_savedFile=$5

  local l_repoName1="${l_repoName}"
  local l_fileName

  #从本地、本地镜像缓存目录或私库(如果设置了私库)中获取目标镜像。
  _pullImageFromPrivateRepository "${l_image}" "${l_archType}" "${l_repoName}" "${l_imageCachedDir}" "${l_savedFile}"
  if [ "${gDefaultRetVal}" == "true" ];then
    gDefaultRetVal="${l_image}"
  else
    #如果仍没有获取到目标镜像，则从公网仓库中获取目标镜像。如果获取成功则缓存到本地镜像缓存目录中。
    _pullImageFromPublicRepository "${l_image}" "${l_archType}" "${l_repoName1}" "${l_imageCachedDir}"
    if [ "${gDefaultRetVal}" == "true" ];then
      if [ "${l_repoName1}" ];then
        info "将从公网拉取的${l_archType}架构的${l_image}镜像推送到${l_repoName1}仓库中..."
        pushImage "${l_image}" "${l_archType}" "${l_repoName1}"
        if [ "${gDefaultRetVal}" == "true" ];then
          info "将导出的镜像文件${l_savedFile}复制到${l_imageCachedDir}目录中..."
          l_fileName="${l_image//\//_}"
          l_fileName="${l_fileName//:/-}-${l_archType//\//-}.tar"
          cp -f "${l_savedFile}" "${l_imageCachedDir}/${l_fileName}"
          gDefaultRetVal="${l_image}"
        fi
      else
        gDefaultRetVal="${l_image}"
      fi
    fi
  fi
}

function existDockerImage() {
  export gDefaultRetVal

  local l_image=$1
  local l_archType=$2

  local l_imageInfo

  gDefaultRetVal="false"
  l_imageInfo=$(docker image list | grep -oE "^(.*)${l_image%:*}([ ]+)${l_image##*:}([ ]+).*$")
  if [ "${l_imageInfo}" ];then
    # shellcheck disable=SC2068
    #判断镜像名称和版本是否一致。
    if [[ "${l_imageInfo// /}" =~ ^(${l_image%:*}) \
      && "${l_imageInfo#* }" =~ ^([ ]*)${l_image##*:} ]];then
      if [ "${l_archType}" ];then
        #判断镜像的架构类型是否一致
        #l_architecture=$(docker inspect "${l_image}" | grep "Architecture")
        #l_errorLog=$(grep -oE "^.*${l_archType#*/}.*$" <<< "${l_architecture}")
        l_errorLog=$(docker inspect -f '{{.Architecture}}' "${l_image}" | grep -x "${l_archType#*/}")
        if [ "${l_errorLog}" ];then
          gDefaultRetVal="true"
        fi
      else
        gDefaultRetVal="true"
      fi
    fi

  fi
}


#拉取镜像并检查其架构是否与传入的一致
function pullAndCheckImage(){
  export gDefaultRetVal
  export gDockerRepoInstanceName
  export gTempFileDir

  local l_image=$1
  local l_archType=$2
  local l_repoName=$3
  local l_pullFromRepoName=$4

  local l_tmpImage
  local l_errorLog

  gDefaultRetVal="true"

  l_tmpImage="${l_image}"
  [[ "${l_pullFromRepoName}" == "true" && "${l_repoName}" ]] && l_tmpImage="${l_repoName}/${l_image}"

  info "先删除可能已存在的同名异构的镜像:${l_tmpImage}"
  docker rmi "${l_tmpImage}" 2>/dev/null || true

  info "执行命令：docker pull --platform ${l_archType} ${l_tmpImage}"
  docker pull --platform "${l_archType}" "${l_tmpImage}"

  # shellcheck disable=SC2181
  if [ "$?" -eq 0 ];then
    l_errorLog=$(docker inspect -f '{{.Architecture}}' "${l_tmpImage}" | grep -x "${l_archType#*/}")
    if [ ! "${l_errorLog}" ];then
      error "从${l_repoName}私库拉取${l_archType}架构的镜像${l_image}失败，架构类型与指定的${l_archType}不一致"
      gDefaultRetVal="false"
    else
      if [[ "${l_pullFromRepoName}" == "true" && "${l_repoName}" ]];then
        info "成功从${l_repoName}私库拉取${l_archType}架构的镜像：${l_image}"
        #去掉docker镜像的仓库前缀。
        docker tag "${l_tmpImage}" "${l_image}"
        #删除带私库的前缀。
        docker rmi "${l_tmpImage}"
      else
        info "从公网拉取${l_archType}架构的镜像成功：${l_image}"
        if [ "${l_repoName}" ];then
          info "将${l_archType}架构的${l_image}镜像推送到${l_repoName}仓库中..."
          pushImage "${l_image}" "${l_archType}" "${l_repoName}"
        else
          warn "未将公共镜像${l_image}推送到私库中：没有指定私库信息"
        fi
      fi
    fi
  else
    gDefaultRetVal="false"
  fi
}

function pushImage() {
  export gDefaultRetVal

  local l_image=$1
  local l_archType=$2
  local l_repoName=$3

  local l_tmpFile
  local l_errorLog
  local l_tmpImage

  l_tmpImage="${l_repoName}/${l_image}-${l_archType//\//-}"

  docker tag "${l_image}" "${l_tmpImage}" 2>&1
  if [ "$?" -ne 0 ];then
    error "--->执行命令(docker tag ${l_image} ${l_tmpImage})失败"
  else
    info "--->成功执行命令(docker tag ${l_image} ${l_tmpImage})"
  fi

  docker push "${l_tmpImage}" 2>&1
  if [ "$?" -ne 0 ];then
    #报错前删除刚定义的镜像。
    docker rmi -f "${l_tmpImage}"
    error "--->执行命令(docker push ${l_tmpImage})失败"
  else
    info "--->成功执行命令(docker push ${l_tmpImage})"
  fi

  _createDockerManifest "${l_image}" "${l_archType}" "${l_repoName}"

  #删除无用的镜像
  docker rmi -f "${l_repoName}/${l_image}-${l_archType//\//-}"

  gDefaultRetVal="true"
}

#将镜像导出到指定目录的文件中
function saveImage(){
  export gTempFileDir

  local l_image=$1
  local l_archType=$2
  local l_savePath=$3

  local l_fileName
  local l_tmpFile
  local l_errorLog
  local l_curDir

  if [ ! -d "${l_savePath}" ];then
    info "创建镜像导出文件的存储目录：${l_savePath}"
    mkdir -p "${l_savePath}"
    if [ ! -d "${l_savePath}" ];then
      error "创建${l_savePath}目录失败"
    fi
  fi

  l_fileName="${l_image//\//_}"
  l_fileName="${l_fileName//:/-}-${l_archType//\//-}.tar"
  if [ -f "${l_savePath}/${l_fileName}" ];then
    info "删除现存的同名导出文件:${l_fileName}"
    rm -f "${l_savePath}/${l_fileName}"
  fi


  l_curDir=$(pwd)
  # shellcheck disable=SC2164
  cd "${l_savePath}"

  info "生成镜像导出文件${l_savePath}/${l_fileName}..." "-n"
  # shellcheck disable=SC2088
  l_tmpFile="${gTempFileDir}/docker-save-${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"
  docker save --platform "${l_archType}" -o "${l_fileName}" "${l_image}" 2>&1 | tee "${l_tmpFile}"
  # shellcheck disable=SC2002
  l_errorLog=$(grep -oE "^.*(Error|failed).*$" "${l_tmpFile}")
  unregisterTempFile "${l_tmpFile}"

  # shellcheck disable=SC2164
  cd "${l_curDir}"

  if [ "${l_errorLog}" ];then
    error "失败：${l_errorLog}" "*"
  else
    info "成功" "*"
  fi
}
#**********************私有方法-开始******************************#

function _pullImageFromPrivateRepository(){
  export gDefaultRetVal

  local l_image=$1
  local l_archType=$2
  local l_repoName=$3
  local l_imageCachedDir=$4
  local l_savedFilePath=$5

  info "检查本地是否存在${l_archType}架构的目标镜像:${l_image} ..." "-n"
  existDockerImage "${l_image}" "${l_archType}"
  # shellcheck disable=SC2015
  if [[ "${gDefaultRetVal}" == "true" ]];then
    info "存在" "*"
  else
    info "不存在" "*"
  fi

  if [ "${gDefaultRetVal}" == "false" ];then
    info "尝试从本地镜像缓存目录${l_imageCachedDir}中加载${l_archType}架构的镜像:${l_image} ..." "-n"
    _loadImageFromDir "${l_image}" "${l_archType}" "${l_imageCachedDir}"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "true" ]] && info "成功" "*" || info "失败" "*"
  fi

  if [[ "${gDefaultRetVal}" == "false" && "${l_repoName}" ]];then
    info "尝试从${l_repoName}仓库中获取${l_archType}架构的镜像:${l_image}..."
    pullAndCheckImage "${l_image}" "${l_archType}" "${l_repoName}" "true"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "true" ]] && info "成功" "*" || info "失败" "*"
  fi

  if [[ "${gDefaultRetVal}" == "true" && "${l_savedFilePath}" ]];then
    info "将本地${l_archType}架构的镜像${l_image}导出到${l_savedFilePath%/*}目录中..."
    _cacheImageToDir "${l_image}" "${l_archType}" "${l_savedFilePath%/*}"
  fi

}

function _pullImageFromPublicRepository(){
  export gDefaultRetVal

  local l_image=$1
  local l_archType=$2
  local l_repoName=$3
  local l_imageCachedDir=$4

  info "尝试从公网仓库中拉取架构为${l_archType}的目标镜像:${l_image} ..."
  pullAndCheckImage "${l_image}" "${l_archType}" "${l_repoName}" "false"
  if [ "${gDefaultRetVal}" == "true" ];then
    info "将从公网拉取的${l_archType}架构的${l_image}镜像缓存到本地镜像缓存目录${l_imageCachedDir}中 ..."
    _cacheImageToDir "${l_image}" "${l_archType}" "${l_imageCachedDir}"
  else
    error "从公网拉取${l_archType}架构的${l_image}镜像失败"
  fi
}


function _loadImageFromDir() {
  export gDefaultRetVal

  local l_image=$1
  local l_archType=$2
  local l_cacheDir=$3

  local l_fileName
  local l_targetFiles
  local l_targetFile
  local l_errorLog

  gDefaultRetVal="false"
  if [ -d "${l_cacheDir}" ];then
    l_fileName="${l_image//\//_}"
    l_fileName="${l_fileName//:/-}-${l_archType//\//-}.tar"

    l_targetFiles=$(find "${l_cacheDir}" -maxdepth 1 -type f -name "${l_fileName}")
    if [ "${l_targetFiles}" ];then
      l_targetFile=${l_targetFiles[0]}
      l_errorLog=$(docker load -i "${l_targetFile}" 2>&1 | grep -oE "^.*(Loaded image: ${l_image}).*$")
      [[ "${l_errorLog}" ]] && gDefaultRetVal="true"
    fi
  fi
}

function _cacheImageToDir() {
  export gTempFileDir

  local l_image=$1
  local l_archType=$2
  local l_cacheDir=$3

  local l_fileName
  local l_tmpFile
  local l_errorLog
  local l_curDir

  if [ ! -d "${l_cacheDir}" ];then
    mkdir -p "${l_cacheDir}" 2>&1
    if [ ! -d "${l_cacheDir}" ];then
      error "创建镜像缓存目录(${l_cacheDir})失败"
    fi
  fi

  l_fileName="${l_image//\//_}"
  l_fileName="${l_fileName//:/-}-${l_archType//\//-}.tar"

  if [ -f "${l_cacheDir}/${l_fileName}" ];then
    info "先删除已经存在的同名文件:${l_cacheDir}/${l_fileName}"
    rm -f "${l_cacheDir}/${l_fileName}" || true
  fi

  l_curDir=$(pwd)
  # shellcheck disable=SC2164
  cd "${l_cacheDir}"

  # shellcheck disable=SC2088
  l_tmpFile="${gTempFileDir}/docker-save-${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"
  info "将${l_image}镜像导出到${l_cacheDir}/${l_fileName}文件中..."
  info "执行命令(docker save --platform ${l_archType} -o ${l_fileName} ${l_image})..."
  docker save --platform "${l_archType}" -o "${l_fileName}" "${l_image}" 2>&1 | tee "${l_tmpFile}"
  # shellcheck disable=SC2002
  l_errorLog=$(grep -oE "^.*(Error|failed).*$" <<< "${l_tmpFile}")
  unregisterTempFile "${l_tmpFile}"

  # shellcheck disable=SC2164
  cd "${l_curDir}"

  if [ "${l_errorLog}" ];then
    error "执行命令(docker save -o ${l_fileName} ${l_image})失败：${l_errorLog}"
  fi
}

function _createDockerManifest() {
  export gDefaultRetVal

  local l_image=$1
  local l_archType=$2
  local l_repoName=$3

  local l_cacheDir
  local l_tmpImage
  local l_otherImage
  local l_otherArchType

  local l_result
  local l_errorLog

  l_tmpImage="${l_repoName}/${l_image}"
  l_tmpImage="${l_tmpImage//:/\-}"
  l_tmpImage="${l_tmpImage//\//_}"
  # shellcheck disable=SC2088
  l_cacheDir="${HOME}/.docker/manifests/${l_tmpImage}"
  if [ ! -d "${l_cacheDir}" ];then
    mkdir -p "${l_cacheDir}"
    info "镜像manifests缓存目录创建成功:${l_cacheDir}"
  else
    info "镜像manifests缓存目录已经存在:${l_cacheDir}"
    rm -rf "${l_cacheDir:?}/*"
    info "镜像manifests缓存目录已清空"
  fi

  if [ "${l_archType}" == "linux/amd64" ];then
    l_otherArchType="linux/arm64"
  else
    l_otherArchType="linux/amd64"
  fi

  #获取其他架构的镜像名称。
  info "获取现有${l_otherArchType}架构的镜像名称..." "-n"
  l_otherImage="${l_repoName}/${l_image}-${l_otherArchType//\//-}"
  _readDigestValueOfManifestList "${l_otherImage}" "${l_otherArchType}" "${l_repoName}"
  if [ "${gDefaultRetVal}" != "null" ];then
    if [ "${gDefaultRetVal}" ];then
      l_otherImage="${l_otherImage%:*}@${gDefaultRetVal}"
    fi
    info "" "*"
    info "${l_otherImage}"
  else
    l_otherImage=""
    info "失败" "*"
  fi

  #获取当前架构的镜像名称。
  info "获取现有${l_archType}架构的镜像名称..." -n
  gDefaultRetVal=""
  l_tmpImage="${l_repoName}/${l_image}-${l_archType//\//-}"
  _readDigestValueOfManifestList "${l_tmpImage}" "${l_archType}" "${l_repoName}"
  if [ "${gDefaultRetVal}" ];then
    l_tmpImage="${l_tmpImage%:*}@${gDefaultRetVal}"
    info "" "*"
    info "${l_tmpImage}"
  else
    info "失败" "*"
  fi


  # 删除已存在的manifest列表
  docker manifest rm "${l_repoName}/${l_image}" 2>/dev/null || true

  if [ "${l_otherImage}" ];then
    # 创建新的manifest列表
    l_result=$(docker manifest create --insecure --amend "${l_repoName}/${l_image}" "${l_tmpImage}" "${l_otherImage}" 2>&1)
  else
    l_result=$(docker manifest create --insecure --amend "${l_repoName}/${l_image}" "${l_tmpImage}" 2>&1)
  fi
  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    error "--->执行命令(docker manifest create --insecure --amend ${l_repoName}/${l_image} ${l_tmpImage} ${l_otherImage})失败:\n${l_result}"
  else
    info "--->成功执行命令(docker manifest create --insecure --amend ${l_repoName}/${l_image} ${l_tmpImage} ${l_otherImage})"
  fi

  l_result=$(docker manifest annotate "${l_repoName}/${l_image}" "${l_tmpImage}" --os "${l_archType%%/*}" --arch "${l_archType#*/}" 2>&1)
  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    error "--->执行命令(docker manifest annotate ${l_repoName}/${l_image} ${l_tmpImage}  --os ${l_archType%%/*} --arch ${l_archType#*/})失败:\n${l_result}"
  else
    info "--->成功执行命令(docker manifest annotate ${l_repoName}/${l_image} ${l_tmpImage} --os ${l_archType%%/*} --arch ${l_archType#*/})"
  fi

  if [ "${l_otherImage}" ];then
    l_result=$(docker manifest annotate "${l_repoName}/${l_image}" "${l_otherImage}" --os "${l_otherArchType%%/*}" --arch "${l_otherArchType#*/}" 2>&1)
    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ];then
      error "--->执行命令(docker manifest annotate ${l_repoName}/${l_image} ${l_otherImage}  --os ${l_otherArchType%%/*} --arch ${l_otherArchType#*/})失败:\n${l_result}"
    else
      info "--->成功执行命令(docker manifest annotate ${l_repoName}/${l_image} ${l_otherImage} --os ${l_otherArchType%%/*} --arch ${l_otherArchType#*/})"
    fi
  fi

  l_result=$(docker manifest push --insecure --purge "${l_repoName}/${l_image}" 2>&1)
  # shellcheck disable=SC2181
   if [ "$?" -ne 0 ];then
    error "--->执行命令(docker manifest push --insecure --purge ${l_repoName}/${l_image})失败:\n${l_result}"
  else
    info "--->成功执行命令(docker manifest push --insecure --purge ${l_repoName}/${l_image})"
  fi

  #删除本地manifest缓存中的文件。
  rm -rf "${l_cacheDir:?}"
}

function _readDigestValueOfManifestList(){
    export gDefaultRetVal

    local l_image=$1
    local l_archType=$2
    local l_repoName=$3
    local l_readConfig=$4

    # 提取指定系统架构的digest值（兼容manifest list和单一架构镜像）
    local l_os="${l_archType%%/*}"
    local l_arch="${l_archType#*/}"
    local l_digest

    local l_content
    local l_lines
    local l_line
    local l_tmpLine
    local l_tmpContent

    if [ ! "${l_readConfig}" ];then
      l_readConfig="false"
    fi

    l_content=$(docker manifest inspect  --insecure "${l_image}")
    # shellcheck disable=SC2181
    # shellcheck disable=SC2320
    if [ "$?" -ne 0 ];then
      gDefaultRetVal="null"
      return
    fi

    l_tmpContent=$(grep -oE "\"config\":" <<< "${l_content}")
    if [ "${l_tmpContent}" ]; then
        gDefaultRetVal=""
        if [ "${l_readConfig}" == "true" ]; then
            l_tmpContent=$(grep -m 1 -oE "sha256:[a-zA-Z0-9]+" <<< "${l_content}")
            gDefaultRetVal="${l_tmpContent}"
        fi
        return
    fi

    l_lines=$(sed -n "/\"architecture\": \"${l_arch}\"/=" <<< "${l_content}")
    # shellcheck disable=SC2068
    for l_line in ${l_lines[@]};do
      ((l_tmpLine = l_line + 1))
      l_tmpContent=$(sed -n "${l_tmpLine}p" <<< "${l_content}")
      if [[ "${l_tmpContent}" =~ ^([ ]+)\"os\":([ ]+)\"${l_os}\" ]];then
        l_digest=$(sed -n "1,${l_line}p" <<< "${l_content}" | grep -oE "sha256:[a-zA-Z0-9]+" | tail -n 1)
        break;
      fi
    done

    gDefaultRetVal="${l_digest}"
}



#**********************私有方法-结束******************************

#引入的全局临时文件目录
export gTempFileDir

export _selfRootDir

if type -t "info" > /dev/null; then
  if [ ! "${_selfRootDir}" ];then
    # shellcheck disable=SC2164
    _selfRootDir=$(cd "$(dirname "$0")"; pwd)
  fi
  source "${_selfRootDir}/helper/log-helper.sh"
fi
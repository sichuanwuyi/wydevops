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
    info "docker.helper.executing.command" "docker logout ${l_repoName} && echo ${l_password} | docker login ${l_repoName} -u ${l_account} --password-stdin"
    # shellcheck disable=SC2088
    #l_tmpFile="${gTempFileDir}/docker-${RANDOM}.tmp"
    #registerTempFile "${l_tmpFile}"
    #先执行登出（避免某些情况下直接登入失败）,再执行登入。
    l_errorLog=$(docker logout "${l_repoName}" && echo "${l_password}" | docker login "${l_repoName}" -u "${l_account}" --password-stdin  2>&1) # | tee "${l_tmpFile}"
    #l_tmpFileContent=$(cat "${l_tmpFile}")
    #l_errorLog=$(grep -E "^.*(Error|failed|panic).*$" <<< "${l_tmpFileContent}")
    #unregisterTempFile "${l_tmpFile}"
    # shellcheck disable=SC2015
    if [ "$?" -ne 0 ];then
      # shellcheck disable=SC2002
      error "docker.helper.login.fail" "${l_repoName}#${l_errorLog}"
    else
      info "docker.helper.login.success"
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
        info "docker.helper.push.public.image.to.private.repo" "${l_archType}#${l_image}#${l_repoName1}" "-n"
        pushImage "${l_image}" "${l_archType}" "${l_repoName1}"
        if [ "${gDefaultRetVal}" == "true" ];then
          info "docker.helper.common.success" "" "*"
          info "docker.helper.copy.exported.image" "${l_savedFile}#${l_imageCachedDir}" "-n"
          l_fileName="${l_image//\//_}"
          l_fileName="${l_fileName//:/-}-${l_archType//\//-}.tar"
          cp -f "${l_savedFile}" "${l_imageCachedDir}/${l_fileName}"
          if [ "$?" -ne "0" ];then
            error "docker.helper.common.fail" "" "*"
          fi
          info "docker.helper.common.success" "" "*"
          gDefaultRetVal="${l_image}"
        else
          error "docker.helper.common.fail" "" "*"
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
  # Use docker inspect with --format for machine-readable output. This is more reliable than parsing `docker image list`.
  # It attempts to get the architecture of the image. If the command succeeds and returns any output, the image exists.
  l_imageInfo=$(docker image inspect --format='{{.Architecture}}' "${l_image}" 2>/dev/null)
  if [ -n "${l_imageInfo}" ];then
    # If an architecture check is required, verify it matches.
    if [ "${l_archType}" ];then
      if [ "${l_imageInfo}" == "${l_archType#*/}" ];then
        gDefaultRetVal="true"
      fi
    else
      # If no architecture check is needed, the image is considered to exist.
      gDefaultRetVal="true"
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

  info "docker.helper.delete.existing.heterogeneous.image" "${l_tmpImage}"
  docker rmi "${l_tmpImage}" 2>/dev/null || true

  info "docker.helper.executing.command" "docker pull --platform ${l_archType} ${l_tmpImage}"
  docker pull --platform "${l_archType}" "${l_tmpImage}"

  # shellcheck disable=SC2181
  if [ "$?" -eq 0 ];then
    l_errorLog=$(docker inspect -f '{{.Architecture}}' "${l_tmpImage}" | grep -x "${l_archType#*/}")
    if [ ! "${l_errorLog}" ];then
      error "docker.helper.pull.from.docker.repo.fail.arch.mismatch" "${l_repoName}#${l_archType}#${l_image}#${l_archType}"
      gDefaultRetVal="false"
    else
      if [[ "${l_pullFromRepoName}" == "true" && "${l_repoName}" ]];then
        info "docker.helper.pull.from.private.repo.success" "${l_repoName}#${l_archType}#${l_image}"
        #去掉docker镜像的仓库前缀。
        docker tag "${l_tmpImage}" "${l_image}"
        #删除带私库的前缀。
        docker rmi "${l_tmpImage}"
      else
        info "docker.helper.pull.from.public.repo.success" "${l_archType}#${l_image}"
        if [ "${l_repoName}" ];then
          info "docker.helper.push.image.to.private.repo" "${l_archType}#${l_image}#${l_repoName}"
          pushImage "${l_image}" "${l_archType}" "${l_repoName}"
        else
          warn "docker.helper.push.public.image.to.private.repo.not.specified" "${l_image}"
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
  local l_result

  l_tmpImage="${l_repoName}/${l_image}-${l_archType//\//-}"

  info "docker.helper.executing.command" "docker tag ${l_image} ${l_tmpImage}" "-n"
  l_result=$(docker tag "${l_image}" "${l_tmpImage}" 2>&1)
  if [ "$?" -ne 0 ];then
    error "docker.helper.common.fail" "" "*"
  else
    info "docker.helper.common.success" "" "*"
  fi

  info "docker.helper.executing.command" "docker push -q ${l_tmpImage}" "-n"

  l_result=$(docker push -q "${l_tmpImage}" 2>&1)
  if [ "$?" -ne 0 ];then
    #报错前删除刚定义的镜像。
    docker rmi -f "${l_tmpImage}"
    error "docker.helper.push.fail.reason"
  fi
  info "docker.helper.push.success" "" "*"

  _createDockerManifest "${l_image}" "${l_archType}" "${l_repoName}"

  #删除无用的镜像
  docker rmi -f "${l_repoName}/${l_image}-${l_archType//\//-}"

  gDefaultRetVal="true"
}

#将镜像导出到指定目录的文件中
function saveImage(){
  export gDefaultRetVal
  export gTempFileDir

  local l_image=$1
  local l_archType=$2
  local l_savePath=$3

  local l_fileName
  local l_tmpFile
  local l_errorLog
  local l_curDir

  if [ ! -d "${l_savePath}" ];then
    info "docker.helper.create.export.dir" "${l_savePath}" "-n"
    mkdir -p "${l_savePath}"
    if [ ! -d "${l_savePath}" ];then
      error "docker.helper.common.fail" "" "*"
    else
      info "docker.helper.common.success" "" "*"
    fi
  fi

  l_fileName="${l_image//\//_}"
  l_fileName="${l_fileName//:/-}-${l_archType//\//-}.tar"
  if [ -f "${l_savePath}/${l_fileName}" ];then
    info "docker.helper.delete.existing.export.file" "${l_fileName}" "-n"
    rm -f "${l_savePath}/${l_fileName}"
    if [ "$?" -ne 0 ];then
      error "docker.helper.common.fail" "" "*"
    else
      info "docker.helper.common.success" "" "*"
    fi
  fi


  l_curDir=$(pwd)
  # shellcheck disable=SC2164
  cd "${l_savePath}"

  info "docker.helper.generating.export.file" "${l_savePath}/${l_fileName}" "-n"
  # shellcheck disable=SC2088
  l_tmpFile="${gTempFileDir}/docker-save-${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"
  docker save --platform "${l_archType}" -o "${l_fileName}" "${l_image}" 2>&1 | tee "${l_tmpFile}"
  # shellcheck disable=SC2002
  if [ "$?" -ne 0 ];then
    l_errorLog=$(grep -oE "^.*(Error|failed).*$" "${l_tmpFile}")
    [[ ! "${l_errorLog}" ]] && l_errorLog="unknown"
  else
    l_errorLog=""
  fi
  unregisterTempFile "${l_tmpFile}"

  # shellcheck disable=SC2164
  cd "${l_curDir}"

  if [ "${l_errorLog}" ];then
    error "docker.helper.execute.command.fail.with.reason" "${l_errorLog}" "*"
  else
    info "docker.helper.common.success" "" "*"
  fi
  gDefaultRetVal="true"
}
#**********************私有方法-开始******************************#

function _pullImageFromPrivateRepository(){
  export gDefaultRetVal

  local l_image=$1
  local l_archType=$2
  local l_repoName=$3
  local l_imageCachedDir=$4
  local l_savedFilePath=$5

  info "docker.helper.check.local.image.existence" "${l_archType}#${l_image}" "-n"
  existDockerImage "${l_image}" "${l_archType}"
  # shellcheck disable=SC2015
  if [[ "${gDefaultRetVal}" == "true" ]];then
    info "docker.helper.common.exist" "" "*"
  else
    info "docker.helper.common.not.exist" "" "*"
  fi

  if [ "${gDefaultRetVal}" == "false" ];then
    info "docker.helper.load.image.from.cache.dir" "${l_imageCachedDir}#${l_archType}#${l_image}"
    _loadImageFromDir "${l_image}" "${l_archType}" "${l_imageCachedDir}"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "true" ]] && info "docker.helper.load.image.success" "${l_image}" "*" \
      || info "docker.helper.load.image.fail" "${l_image}" "*"
  fi

  if [[ "${gDefaultRetVal}" == "false" && "${l_repoName}" ]];then
    info "docker.helper.get.image.from.private.repo" "${l_repoName}#${l_archType}#${l_image}"
    pullAndCheckImage "${l_image}" "${l_archType}" "${l_repoName}" "true"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "true" ]] && info "docker.helper.load.image.success" "${l_image}" "*" \
      || info "docker.helper.load.image.fail" "${l_image}" "*"
  fi

  if [[ "${gDefaultRetVal}" == "true" && "${l_savedFilePath}" ]];then
    info "docker.helper.export.local.image.to.dir" "${l_archType}#${l_image}#${l_savedFilePath%/*}"
    _cacheImageToDir "${l_image}" "${l_archType}" "${l_savedFilePath%/*}"
  fi

}

function _pullImageFromPublicRepository(){
  export gDefaultRetVal

  local l_image=$1
  local l_archType=$2
  local l_repoName=$3
  local l_imageCachedDir=$4

  info "docker.helper.pull.from.public.repo" "${l_archType}#${l_image}"
  pullAndCheckImage "${l_image}" "${l_archType}" "${l_repoName}" "false"
  if [ "${gDefaultRetVal}" == "true" ];then
    info "docker.helper.cache.public.image.to.local.dir" "${l_archType}#${l_image}#${l_imageCachedDir}"
    _cacheImageToDir "${l_image}" "${l_archType}" "${l_imageCachedDir}"
  else
    error "docker.helper.pull.from.public.repo.fail" "${l_archType}#${l_image}"
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

    info "docker.helper.find.file.in.dir" "${l_cacheDir}#${l_fileName}" "-n"

    l_targetFiles=$(find "${l_cacheDir}" -maxdepth 1 -type f -name "${l_fileName}")
    if [ "${l_targetFiles}" ];then
      info "docker.helper.common.success" "" "*"
      l_targetFile=${l_targetFiles[0]}
      info "docker.helper.executing.command" "docker load -i ${l_targetFile}" "-n"
      l_errorLog=$(docker load -i "${l_targetFile}" 2>&1 | grep -oE "^.*(Loaded image: ${l_image}).*$")
      if [ "${l_errorLog}" ];then
        gDefaultRetVal="true"
        info "docker.helper.common.success" "" "*"
      else
        info "docker.helper.common.fail" "" "*"
      fi
    else
      warn "docker.helper.common.fail" "" "*"
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
    info "docker.helper.create.cache.dir" "${l_cacheDir}" "-n"
    mkdir -p "${l_cacheDir}" 2>&1
    if [ ! -d "${l_cacheDir}" ];then
      error "docker.helper.common.fail" "" "*"
    else
      info "docker.helper.common.success" "" "*"
    fi
  fi

  l_fileName="${l_image//\//_}"
  l_fileName="${l_fileName//:/-}-${l_archType//\//-}.tar"

  if [ -f "${l_cacheDir}/${l_fileName}" ];then
    info "docker.helper.delete.existing.file.before.cache" "${l_cacheDir}/${l_fileName}" "-n"
    rm -f "${l_cacheDir}/${l_fileName}"
    if [ "$?" -ne 0 ];then
      warn "docker.helper.common.fail" "" "*"
    else
      info "docker.helper.common.success" "" "*"
    fi
  fi

  l_curDir=$(pwd)
  # shellcheck disable=SC2164
  cd "${l_cacheDir}"

  # shellcheck disable=SC2088
  l_tmpFile="${gTempFileDir}/docker-save-${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"
  info "docker.helper.export.image.to.file.in.dir" "${l_image}#${l_cacheDir}/${l_fileName}"
  info "docker.helper.executing.command" "docker save --platform ${l_archType} -o ${l_fileName} ${l_image}" "-n"
  docker save --platform "${l_archType}" -o "${l_fileName}" "${l_image}" 2>&1 | tee "${l_tmpFile}"
  # shellcheck disable=SC2002
  l_errorLog=$(grep -oE "^.*(Error|failed).*$" <<< "${l_tmpFile}")
  unregisterTempFile "${l_tmpFile}"

  # shellcheck disable=SC2164
  cd "${l_curDir}"

  if [ "${l_errorLog}" ];then
    error "docker.helper.execute.command.fail.with.reason" "${l_errorLog}" "*"
  else
    info "docker.helper.common.success" "" "*"
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
    info "docker.helper.manifest.cache.dir.create" "${l_cacheDir}" "-n"
    mkdir -p "${l_cacheDir}"
    if [ "$?" -ne 0 ];then
      info "docker.helper.common.fail" "" "*"
    else
      info "docker.helper.common.success" "" "*"
    fi
  else
    info "docker.helper.manifest.cache.dir.clear" "${l_cacheDir}" "-n"
    rm -rf "${l_cacheDir:?}/*"
    if [ "$?" -ne 0 ];then
      info "docker.helper.common.fail" "" "*"
    else
      info "docker.helper.common.success" "" "*"
    fi
  fi

  if [ "${l_archType}" == "linux/amd64" ];then
    l_otherArchType="linux/arm64"
  else
    l_otherArchType="linux/amd64"
  fi

  #获取其他架构的镜像名称。
  info "docker.helper.get.existing.image.name.for.arch" "${l_otherArchType}"
  l_otherImage="${l_repoName}/${l_image}-${l_otherArchType//\//-}"
  _readDigestValueOfManifestList "${l_otherImage}" "${l_otherArchType}" "${l_repoName}"
  if [ "${gDefaultRetVal}" != "null" ];then
    if [ "${gDefaultRetVal}" ];then
      l_otherImage="${l_otherImage%:*}@${gDefaultRetVal}"
    fi
    info "docker.helper.get.existing.image.name.for.arch.success" "${l_otherArchType}#${l_otherImage}"
  else
    l_otherImage=""
    warn "docker.helper.get.existing.image.name.for.arch.fail" "${l_otherArchType}"
  fi

  #获取当前架构的镜像名称。
  info "docker.helper.get.existing.image.name.for.arch" "${l_archType}"
  gDefaultRetVal=""
  l_tmpImage="${l_repoName}/${l_image}-${l_archType//\//-}"
  _readDigestValueOfManifestList "${l_tmpImage}" "${l_archType}" "${l_repoName}"
  if [ "${gDefaultRetVal}" ];then
    l_tmpImage="${l_tmpImage%:*}@${gDefaultRetVal}"
    info "docker.helper.get.existing.image.name.for.arch.success" "${l_archType}#${l_tmpImage}"
  else
    warn "docker.helper.get.existing.image.name.for.arch.fail" "${l_archType}"
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
    error "docker.helper.execute.command.fail" "docker manifest create --insecure --amend ${l_repoName}/${l_image} ${l_tmpImage} ${l_otherImage}#${l_result}"
  else
    info "docker.helper.execute.command.success" "docker manifest create --insecure --amend ${l_repoName}/${l_image} ${l_tmpImage} ${l_otherImage}"
  fi

  l_result=$(docker manifest annotate "${l_repoName}/${l_image}" "${l_tmpImage}" --os "${l_archType%%/*}" --arch "${l_archType#*/}" 2>&1)
  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    error "docker.helper.execute.command.fail" "docker manifest annotate ${l_repoName}/${l_image} ${l_tmpImage} --os ${l_archType%%/*} --arch ${l_archType#*/}#${l_result}"
  else
    info "docker.helper.execute.command.success" "docker manifest annotate ${l_repoName}/${l_image} ${l_tmpImage} --os ${l_archType%%/*} --arch ${l_archType#*/}"
  fi

  if [ "${l_otherImage}" ];then
    l_result=$(docker manifest annotate "${l_repoName}/${l_image}" "${l_otherImage}" --os "${l_otherArchType%%/*}" --arch "${l_otherArchType#*/}" 2>&1)
    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ];then
      error "docker.helper.execute.command.fail" "docker manifest annotate ${l_repoName}/${l_image} ${l_otherImage}  --os ${l_otherArchType%%/*} --arch ${l_otherArchType#*/}#${l_result}"
    else
      info "docker.helper.execute.command.success" "docker manifest annotate ${l_repoName}/${l_image} ${l_otherImage} --os ${l_otherArchType%%/*} --arch ${l_otherArchType#*/}"
    fi
  fi

  l_result=$(docker manifest push --insecure --purge "${l_repoName}/${l_image}" 2>&1)
  # shellcheck disable=SC2181
   if [ "$?" -ne 0 ];then
    error "docker.helper.execute.command.fail" "docker manifest push --insecure --purge ${l_repoName}/${l_image}#${l_result}"
  else
    info "docker.helper.execute.command.success" "docker manifest push --insecure --purge ${l_repoName}/${l_image}"
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
    _selfRootDir=$(cd "$(dirname "$0")"; pwd -L)
  fi
  source "${_selfRootDir}/helper/log-helper.sh"
fi
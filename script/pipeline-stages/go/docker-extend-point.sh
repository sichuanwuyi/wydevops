#!/usr/bin/env bash

function _onBeforeCreatingDockerImage_ex() {
  export gDefaultRetVal
  export gBuildPath
  export gDockerBuildDir
  export gHelmBuildDirName
  export gServiceName

  local l_ciCdYamlFile=$1
  local l_archType=$2
  local l_dockerfile=$3

  local l_configMapFile
  local l_configMapFiles

  local l_file
  local l_fileList

  local l_ignoredFiles
  local l_ignoredDirs
  local l_flag

  readParam "${l_ciCdYamlFile}" "globalParams.enableOfflineBuild"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" == "true" ]];then
    info "将编译输出的可执行程序复制到docker构建目录下..."
    cp -f "${gBuildPath}/${gServiceName}-${l_archType%%/*}-${l_archType##*/}.out" "${gDockerBuildDir}/"

    readParam "${l_ciCdYamlFile}" "globalParams.configMapFiles"
    if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
      # shellcheck disable=SC2206
      l_configMapFiles=(${gDefaultRetVal//,/ })
      # shellcheck disable=SC2068
      for l_configMapFile in ${l_configMapFiles[@]};do
        if [[ "${l_configMapFile}" =~ ^([ ]*)(\./) ]];then
          cp -f "${gBuildPath}/${l_configMapFile:2}" "${gDockerBuildDir}/"
        elif [[ "${l_configMapFile}" =~ ^([ ]*)/ ]];then
          cp -f "${l_configMapFile}" "${gDockerBuildDir}/"
        fi
        # shellcheck disable=SC2181
        [[ "$?" -ne 0 ]] && error "复制${l_configMapFile}文件失败"
        info "成功复制${l_configMapFile}文件到docker镜像构建目录中"
      done
    fi

    return
  fi

  l_ignoredFiles=" _global_params.yaml ci-cd.yaml debug.txt ci-cd-config.yaml wydevops-run.sh"
  l_ignoredDirs=" ${gHelmBuildDirName} "

  l_fileList=$(find "${gBuildPath}" -maxdepth 1 -type f)
  # shellcheck disable=SC2068
  for l_file in ${l_fileList[@]};do
    l_ignoredFile=${l_file##*/}
    l_flag=$(grep -E " ${l_ignoredFile} " <<< "${l_ignoredFiles}")
    if [ "${l_flag}" ];then
      warn "忽略${l_ignoredFile}文件"
      continue
    fi
    cp -f "${l_file}" "${gDockerBuildDir}/"
  done

  l_fileList=$(find "${gBuildPath}" -maxdepth 1 -type d)
  # shellcheck disable=SC2068
  for l_file in ${l_fileList[@]};do
    if [ "${l_file}" == "${gBuildPath}" ];then
      continue
    fi

    l_ignoredDir=${l_file##*/}
    l_flag=$(grep -E " ${l_ignoredDir} " <<< "${l_ignoredDirs}")
    if [ "${l_flag}" ];then
      warn "忽略${l_ignoredDir}目录"
      continue
    fi
    cp -rf "${l_file}" "${gDockerBuildDir}/"
  done

}

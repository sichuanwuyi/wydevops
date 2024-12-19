#!/usr/bin/env bash

function _initialGlobalParamsForDockerStage_ex(){
  export gBuildType
  export gBuildPath
  export gProjectBuildOutDir

  if [ "${gBuildType}" != "thirdParty" ];then
    #定义Java项目的编译输出目录
    gProjectBuildOutDir="${gBuildPath}/target"
  fi
}

function _onBeforeCreatingDockerImage_ex() {
  export gDockerBuildDir
  export gProjectBuildOutDir
  export gServiceName

  local l_dockerfile=$3

  local l_jarFiles
  local l_curDir
  local l_subDirs
  local l_subDir
  local l_content

  l_jarFiles=$(find "${gProjectBuildOutDir}" -maxdepth 1 -type f -name "${gServiceName}*.jar")
  [[ ! "${l_jarFiles[0]}" ]] &&  error "${gProjectBuildOutDir##*/}目录中不存在${gServiceName}*.jar文件"

  info "分层解压jar文件: ${l_jarFiles[0]}"
  l_curDir=$(pwd)
  # shellcheck disable=SC2164
  cd "${gDockerBuildDir}"
  l_content=$(java -Djarmode=layertools -jar "${l_jarFiles[0]}" extract 2>&1)
  l_content=$(echo -e "${l_content}" | grep -ioP "^(.*)(Error|failed)(.*)$")
  [[ "${l_content}" ]] && error "分层解压jar文件异常：${l_content}"
  # shellcheck disable=SC2164
  cd "${l_curDir}"

  l_subDirs=("dependencies" "spring-boot-loader" "snapshot-dependencies" "application")
  # shellcheck disable=SC2068
  for l_subDir in ${l_subDirs[@]};do
    #检查分层解压后的结果是否正确。
    if [[ ! -d "${gDockerBuildDir}/${l_subDir}" ]];then
      error "命令(java -Djarmode=layertools -jar ${l_jarFiles[0]} extract)执行异常：请检查${l_jarFiles[0]}包是否能正常运行"
    fi
    #判断子目录是否在l_dockerfile文件内容中出现，如果没有出现则删除之。
    # shellcheck disable=SC2002
    l_content=$(cat "${l_dockerfile}" | grep -ioP "^(COPY).*/${l_subDir//-/\-}(.*)$" )
    if [ ! "${l_content}" ];then
      rm -rf "${gDockerBuildDir:?}/${l_subDir}"
    fi
  done
}

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

function _onAfterInitialingGlobalParamsForDockerStage_ex() {
  export gBuildPath
  export gProjectBuildOutDir
  export gDockerBuildDir

  local l_targetFiles
  local l_targetFile
  local l_resourceDir
  local l_applicationYamls

  if [ "${gBuildType}" != "thirdParty" ];then
    #拷贝java项目中的application.yaml、application-prod.yaml文件到Docker构建目录中
    l_resourceDir="${gBuildPath}/src/main/resources"
    l_applicationYamls=("application.yml" "application-prod.yml")
    # shellcheck disable=SC2068
    # shellcheck disable=SC2167
    for l_targetFile in ${l_applicationYamls[@]};do
      l_targetFiles=$(find "${l_resourceDir}" -maxdepth 2 -type f -name "${l_targetFile}")
      # shellcheck disable=SC2165
      for l_targetFile in ${l_targetFiles[@]};do
        cp -f "${l_targetFile}" "${gDockerBuildDir}" || true
      done
    done
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
  java -Djarmode=layertools -jar "${l_jarFiles[0]}" extract
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

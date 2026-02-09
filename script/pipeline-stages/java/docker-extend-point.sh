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
  export gRuntimeVersion

  local l_dockerfile=$3

  local l_jarFiles
  local l_curDir
  local l_subDirs
  local l_subDir
  local l_content
  local l_command
  local l_jdkVersion

  l_jdkVersion=$(grep -oE "[0-9]+" <<< "${gRuntimeVersion}")

  l_jarFiles=$(find "${gProjectBuildOutDir}" -maxdepth 1 -type f -name "${gServiceName}*.jar")
  [[ ! "${l_jarFiles[0]}" ]] &&  error "${gProjectBuildOutDir##*/}目录中不存在${gServiceName}*.jar文件"

  info "分层解压jar文件: ${l_jarFiles[0]}"
  l_curDir=$(pwd)
  # shellcheck disable=SC2164
  cd "${gDockerBuildDir}"

  info "项目jdk版本: ${l_jdkVersion}"

  if [[ "${l_jdkVersion}" -ge 21 ]];then
    #确保./extract目录存在，且为空目录
    mkdir -p ./extract && rm -rf ./extract/*
    l_command="java -Djarmode=tools -jar ${l_jarFiles[0]} extract --layers --launcher --destination ./extract"
    info "执行命令: ${l_command}"
    if ! java -Djarmode=tools -jar "${l_jarFiles[0]}" extract --layers --launcher --destination ./extract;then
      error "分层解压jar文件异常"
    fi
    #将./extract目录中的所有子目录复制到gDockerBuildDir目录下。
    mv ./extract/* "${gDockerBuildDir}"
    #删除./extract目录
    rm -rf "./extract"
  else
    l_command="java -Djarmode=layertools -jar ${l_jarFiles[0]} extract --layers --launcher"
    info "执行命令: ${l_command}"
    if ! java -Djarmode=layertools -jar "${l_jarFiles[0]}" extract; then
      error "分层解压jar文件异常"
    fi
  fi

  info "分层解压jar文件成功"

  # shellcheck disable=SC2164
  cd "${l_curDir}"

  l_subDirs=("dependencies" "spring-boot-loader" "snapshot-dependencies" "application")
  # shellcheck disable=SC2068
  for l_subDir in ${l_subDirs[@]};do
    #检查分层解压后的结果是否正确。
    if [[ ! -d "${gDockerBuildDir}/${l_subDir}" ]];then
      error "命令(${l_command})执行后缺失${l_subDir}子目录,请检查${l_jarFiles[0]}包是否能正常运行"
    fi
    #判断子目录是否在l_dockerfile文件内容中出现，如果没有出现则删除之。
    # shellcheck disable=SC2002
    l_content=$(grep -ioE "^(COPY).*/${l_subDir//-/\-}(.*)$" "${l_dockerfile}")
    if [ ! "${l_content}" ];then
      rm -rf "${gDockerBuildDir:?}/${l_subDir}"
    fi
  done
}

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
  [[ ! "${l_jarFiles[0]}" ]] &&  error "java.docker.extend.point.jar.not.found.in.dir" "${gProjectBuildOutDir##*/}#${gServiceName}*.jar"

  info "java.docker.extend.point.unzipping.jar.file" "${l_jarFiles[0]}"
  l_curDir=$(pwd)
  # shellcheck disable=SC2164
  cd "${gDockerBuildDir}"

  info "java.docker.extend.point.project.jdk.version" "${l_jdkVersion}"

  if [[ "${l_jdkVersion}" -ge 21 ]];then
    #确保./extract目录存在，且为空目录
    mkdir -p ./extract && rm -rf ./extract/*
    l_command="java -Djarmode=tools -jar ${l_jarFiles[0]} extract --layers --launcher --destination ./extract"
    info "java.docker.extend.point.executing.command" "${l_command}"
    if ! java -Djarmode=tools -jar "${l_jarFiles[0]}" extract --layers --launcher --destination ./extract;then
      error "java.docker.extend.point.unzip.jar.error"
    fi
    #将./extract目录中的所有子目录复制到gDockerBuildDir目录下。
    _overwrite_move "./extract" "${gDockerBuildDir}"
    #删除./extract目录
    rm -rf ./extract
  else
    l_command="java -Djarmode=layertools -jar ${l_jarFiles[0]} extract --layers --launcher"
    info "java.docker.extend.point.executing.command" "${l_command}"
    if ! java -Djarmode=layertools -jar "${l_jarFiles[0]}" extract; then
      error "java.docker.extend.point.unzip.jar.error"
    fi
  fi

  info "java.docker.extend.point.unzip.jar.success"

  # shellcheck disable=SC2164
  cd "${l_curDir}"

  l_subDirs=("dependencies" "spring-boot-loader" "snapshot-dependencies" "application")
  # shellcheck disable=SC2068
  for l_subDir in ${l_subDirs[@]};do
    #检查分层解压后的结果是否正确。
    if [[ ! -d "${gDockerBuildDir}/${l_subDir}" ]];then
      error "java.docker.extend.point.missing.subdirectory.after.command" "${l_command}#${l_subDir}#${l_jarFiles[0]}"
    fi
    #判断子目录是否在l_dockerfile文件内容中出现，如果没有出现则删除之。
    # shellcheck disable=SC2002
    l_content=$(grep -ioE "^(COPY).*/${l_subDir//-/\-}(.*)$" "${l_dockerfile}")
    if [ ! "${l_content}" ];then
      rm -rf "${gDockerBuildDir:?}/${l_subDir}"
    fi
  done
}

function _overwrite_move() {
  local source_dir=$1
  local dest_dir=$2

  local base_name
  local destination_path

  # 检查源目录是否存在
  if [ ! -d "$source_dir" ]; then
    return
  fi

  # 启用 dotglob 以确保 * 能匹配到隐藏文件
  shopt -s dotglob
  for item in "$source_dir"/*; do
    # 检查项目是否存在，以防源目录为空
    if [ -e "$item" ]; then

      base_name=$(basename "$item")
      destination_path="${dest_dir}/${base_name}"

      # 如果目标路径已经存在一个同名的目录，则先删除它
      if [ -d "$destination_path" ]; then
        rm -rf "$destination_path"
      fi

      # 现在执行移动操作
      mv "$item" "$dest_dir"
    fi
  done
  shopt -u dotglob # 操作结束后，恢复 dotglob 的默认行为
}

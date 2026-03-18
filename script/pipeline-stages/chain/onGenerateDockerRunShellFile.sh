#!/usr/bin/env bash

function onGenerateDockerRunShellFile_default() {
  export gDefaultRetVal

  local l_buildPath=$1
  local l_buildType=$2
  local l_index=$3

  local l_generatorFile
  local l_params=("${@}")
  local l_param_count=${#l_params[@]}
  local l_remaining_params=()
  if [ "${l_param_count}" -gt 2 ];then
    l_remaining_params=("${l_params[@]:2}")
  fi

  #读取优先级最高的docker-run-generator.sh文件。
  #优先级从高到低：项目级>语言级>公共级
  readDockerDeployParam "${l_index}" "dockerRunShellGenerator" "docker-run-generator.sh"
  l_generatorFile="${gDefaultRetVal}"

  if [ "${l_generatorFile##*/}" != "docker-run.sh" ];then
    if [[ "${l_buildType}" == "thirdParty" || "${l_buildType}" == "customize" ]];then
      error "on.generate.docker.run.shell.file.not.supported" "${l_index}"
    fi
    info "on.generate.docker.run.shell.file.generating" "${l_generatorFile##*/}"

    #在gBuildPath目录下生成docker-run.sh文件。
    # shellcheck disable=SC1090
    source "${l_generatorFile}" "${l_remaining_params[@]}"
    gDefaultRetVal="${l_buildPath}/docker-run.sh"
  fi
  gDefaultRetVal="true|${gDefaultRetVal}"
}
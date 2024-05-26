#!/usr/bin/env bash

function onGenerateDockerRunShellFile_default() {
  export gDefaultRetVal
  export gBuildPath
  export gBuildType

  local l_index=$1
  local l_generatorFile

  #读取优先级最高的docker-run-generator.sh文件。
  #优先级从高到低：项目级>语言级>公共级
  readDockerDeployParam "${l_index}" "dockerRunShellGenerator" "docker-run-generator.sh"
  l_generatorFile="${gDefaultRetVal}"

  if [ "${l_generatorFile##*/}" != "docker-run.sh" ];then
    if [[ "${gBuildType}" == "thirdParty" || "${gBuildType}" == "customize" ]];then
      error "gBuildType参数为thirdParty或customize时，不支持自动生成docker-run.sh文件。\n请自行编写docker-run.sh文件，并将其配置给package[${l_index}].docker.dockerRunShellGenerator参数"
    fi
    info "调用${l_generatorFile##*/}脚本，在项目主模块目录下生成docker-run.sh文件 ..."
    #在gBuildPath目录下生成docker-run.sh文件。
    # shellcheck disable=SC1090
    source "${l_generatorFile}" "${@}"
    gDefaultRetVal="${gBuildPath}/docker-run.sh"
  fi
}
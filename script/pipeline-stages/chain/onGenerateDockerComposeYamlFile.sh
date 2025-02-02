#!/usr/bin/env bash

function onGenerateDockerComposeYamlFile_default() {
  export gDefaultRetVal

  local l_buildPath=$1
  local l_buildType=$2
  local l_index=$3

  local l_generatorFile

  #读取优先级最高的docker-compose-yaml-generator.sh文件。
  #优先级从高到低：项目级>语言级>公共级
  readDockerDeployParam "${l_index}" "dockerComposeYamlGenerator" "docker-compose-yaml-generator.sh"
  l_generatorFile="${gDefaultRetVal}"

  if [ "${l_generatorFile##*/}" != "docker-compose.yaml" ];then
    if [[ "${l_buildType}" == "thirdParty" || "${l_buildType]}" == "customize" ]];then
      error "gBuildType参数为thirdParty或customize时，不支持自动生成docker-compose.yaml文件。\n请自行编写docker-compose.yaml文件，并将其配置给package[${l_index}].docker.dockerComposeYamlGenerator参数"
    fi
    #在gBuildPath目录下生成docker-compose.yaml文件。
    # shellcheck disable=SC1090
    source "${l_generatorFile}" "${@}"
    gDefaultRetVal="${l_buildPath}/docker-compose.yaml"
  fi

  gDefaultRetVal="true|${gDefaultRetVal}"
}
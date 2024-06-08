#!/usr/bin/env bash

function ingressGenerator_default() {
  export gDefaultRetVal
  export gBuildPath
  #模板中引用了这两个全局变量
  export gCurrentChartName
  export gCurrentChartVersion

  local l_generatorFile=$1
  local l_resourceType=$2
  local l_generatorName=$3
  local l_valuesYaml=$4
  local l_deploymentIndex=$5
  local l_configPath=$6

  local l_templateFile
  local l_targetFile
  local l_content

  #模板中需要的变量以“t_”开头
  local t_gatewayVersion
  local t_deploymentName
  local t_moduleName
  local t_kindType

  t_kindType="${l_resourceType}"
  if [ "${t_kindType}" != "Ingress" ];then
    gDefaultRetVal="false"
    return
  fi

  t_moduleName="deployment${l_deploymentIndex}"
  readParam "${l_valuesYaml}" "${t_moduleName}.${l_configPath}.type"
  if [ "${t_kindType}" != "${gDefaultRetVal}" ];then
    gDefaultRetVal="false"
    return
  fi

  readParam "${l_valuesYaml}" "${t_moduleName}.${l_configPath}.version"
  #todo: t_gatewayVersion变量是模板需要的参数
  t_gatewayVersion="${gDefaultRetVal}"

  readParam "${l_valuesYaml}" "${t_moduleName}.name"
  t_deploymentName="${gDefaultRetVal}"

  l_templateFile="${l_generatorFile%/*}/${l_resourceType,}-${l_generatorName}-template.yaml"
  [[ ! -f "${l_templateFile}" ]] && error "目标模板文件不存在：${l_templateFile}"
  # shellcheck disable=SC2145
  info "加载${l_resourceType}模板文件：${l_templateFile##*/}"

  #设定目标配置文件
  l_targetFile="${l_valuesYaml%/*}/templates/${t_deploymentName}-${l_resourceType,,}.yaml"

 #读取模板文件内容。
  l_content=$(cat "${l_templateFile}")
  #替换模板中的变量。
  eval "l_content=\$(echo -e \"${l_content}\")"
  #将替换后的内容写入配置文件中。
  echo "${l_content}" > "${l_targetFile}"

  gDefaultRetVal="true"
}
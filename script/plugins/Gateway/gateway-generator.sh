#!/usr/bin/env bash

function gatewayGenerator_default() {
  export gServiceName
  export gDefaultRetVal

  local l_valuesYaml=$4
  local l_deploymentIndex=$5
  local l_configPath=$6

  local l_gatewayName

  #模板中需要的变量以“t_”开头
  local t_apiVersion

  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.${l_configPath}.apiVersion"
  #todo: t_apiVersion变量是模板需要的参数
  t_apiVersion="${gDefaultRetVal}"

  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.${l_configPath}.gateway.name"
  l_gatewayName="${gDefaultRetVal}"
  if [ "${l_gatewayName}" != "${gServiceName}-gw" ];then
    warn "检测到网关名称为非默认名称(${gServiceName}-gw),中断默认网关配置自动生成过程。"
    return
  fi

  commonGenerator_default "Gateway" "${@}" "${t_apiVersion}"
}
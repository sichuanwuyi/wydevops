#!/usr/bin/env bash

function virtualServiceGenerator_default() {
  export gDefaultRetVal

  local l_valuesYaml=$4
  local l_deploymentIndex=$5
  local l_configPath=$6

  #模板中需要的变量以“t_”开头
  local t_apiVersion

  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.${l_configPath}.apiVersion"
  #todo: t_apiVersion变量是模板需要的参数
  t_apiVersion="${gDefaultRetVal}"

  readParam "${l_valuesYaml}" "gatewayRoute.enableRewrite"
  if [ "${gDefaultRetVal}" == "false" ];then
    info "不启用路由重写，则删除virtualService.rewrite参数"
    deleteParam "${l_valuesYaml}" \
      "deployment${l_deploymentIndex}.istioRoute.virtualService.rewrite"
  fi

  commonGenerator_default "VirtualService" "${@}"
}
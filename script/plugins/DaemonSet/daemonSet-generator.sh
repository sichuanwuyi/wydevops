#!/usr/bin/env bash

function daemonSetGenerator_default() {
  export gDefaultRetVal
  local l_resourceType=$2
  local l_valuesYaml=$4
  local l_deploymentIndex=$5

  #最终确定采用的ApiVersion版本
  [[ -z "${t_apiVersion}" ]] && t_apiVersion="apps/v1"
  info "${l_resourceType}资源的采用的ApiVersion版本是：${t_apiVersion}"

  gDefaultRetVal="false"
  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.kind"
  if [ "${gDefaultRetVal}" == "${l_resourceType}" ];then
    commonGenerator_default "${gDefaultRetVal}" "${@}"
  fi
}
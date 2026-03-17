#!/usr/bin/env bash

function gatewayGenerator_default() {
  export gServiceName
  export gDefaultRetVal

  local l_resourceType=$2
  local l_valuesYaml=$4
  local l_deploymentIndex=$5
  local l_configPath=$6

  local l_gatewayName
  local l_apiVersion

  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.${l_configPath}.apiVersion"
  l_apiVersion="${gDefaultRetVal}"
  [[ -z "${l_apiVersion}" ]] && l_apiVersion="networking.istio.io/v1"
  [[ -z "${t_apiVersion}" ]] && t_apiVersion="${l_apiVersion}"
  info "plugin.common.k8s.api.version" "${l_resourceType}#${t_apiVersion}"

  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.${l_configPath}.gateway.name"
  l_gatewayName="${gDefaultRetVal}"
  if [ "${l_gatewayName}" != "${gServiceName}-gw" ];then
    warn "gateway.generator.sh.non.default.name" "${gServiceName}-gw"
    return
  fi

  commonGenerator_default "Gateway" "${@}" "${t_apiVersion}"
}
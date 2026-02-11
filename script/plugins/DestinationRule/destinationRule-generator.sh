#!/usr/bin/env bash

function destinationRuleGenerator_default() {
  export gDefaultRetVal

  local l_resourceType=$2
  local l_valuesYaml=$4
  local l_deploymentIndex=$5
  local l_configPath=$6

  local l_apiVersion

  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.${l_configPath}.apiVersion"
  l_apiVersion="${gDefaultRetVal}"
  [[ -z "${l_apiVersion}" ]] && l_apiVersion="networking.istio.io/v1"
  [[ -z "${t_apiVersion}" ]] && t_apiVersion="${l_apiVersion}"
  info "${l_resourceType}资源的采用的ApiVersion版本是：${t_apiVersion}"

  commonGenerator_default "DestinationRule" "${@}"
}
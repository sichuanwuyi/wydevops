#!/usr/bin/env bash

function statefulSetGenerator_default() {
  export gDefaultRetVal
  local l_resourceType=$2
  local l_valuesYaml=$4
  local l_deploymentIndex=$5

  gDefaultRetVal="false"
  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.kind"
  if [ "${gDefaultRetVal}" == "${l_resourceType}" ];then
    commonGenerator_default "${gDefaultRetVal}" "${@}"
  fi
}
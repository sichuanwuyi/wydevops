#!/usr/bin/env bash

#本文件用于读取K8s各种资源的API版本

function tryLoadApiResources() {
  export gApiResourcesInfo

  local l_apiServer="$1"

  local l_array
  local l_ip
  local l_port
  local l_account
  local l_password

  [[ -z "${l_apiServer}" ]] && error "k8s.api.resources.reader.sh.apiserver.empty"

  # shellcheck disable=SC2206
  l_array=(${l_apiServer//\|/ })
  l_ip="${l_array[0]}"
  l_port="${l_array[1]}"
  l_account="${l_array[2]}"

  #尝试先完成免密登录配置
  tryConnectByPasswordless "${l_account}" "${l_ip}"

  #从ApiServer服务器读取各类资源的Api版本，将信息缓存到gApiResourcesInfo变量中。
  gApiResourcesInfo=$(ssh -o "StrictHostKeyChecking no" -p "${l_port}" "${l_account}@${l_ip}" "kubectl api-resources")
  # shellcheck disable=SC2181
  if [[ $? -ne 0 ]]; then
    error "k8s.api.resources.reader.sh.command.failed" "ssh -o \"StrictHostKeyChecking no\" -p ${l_port} ${l_account}@${l_ip} \"kubectl api-resources\""
  fi
}

function getApiVersion() {
  export gDefaultRetVal
  export gApiResourcesInfo

  local l_resourceType="$1"

  [[ -z "${gApiResourcesInfo}" ]] && error "k8s.api.resources.reader.sh.gapiresourcesinfo.empty" "${l_resourceType}"

  #从gApiResourcesInfo变量中提取l_resourceType资源的Api版本
  gDefaultRetVal=$(echo "${gApiResourcesInfo}" | awk -v var="${l_resourceType}" '$NF == var {print $3}')
}

export gApiResourcesInfo
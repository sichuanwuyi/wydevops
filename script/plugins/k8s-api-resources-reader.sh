#!/usr/bin/env bash

#本文件用于读取K8s各种资源的API版本

function tryLoadApiResources() {
  export gApiResourcesInfo

  local l_apiServer="$1"

  local l_array
  local l_ip
  local l_port
  local l_account

  [[ -z "${l_apiServer}" ]] && error "从ApiServer服务器读取各类资源的Api版本时，ApiServer参数不能为空"

  # shellcheck disable=SC2206
  l_array=(${l_apiServer//\|/ })
  l_ip="${l_array[0]}"
  l_port="${l_array[1]}"
  l_account="${l_array[2]}"
  #从ApiServer服务器读取各类资源的Api版本，将信息缓存到gApiResourcesInfo变量中。
  gApiResourcesInfo=$(ssh -o "StrictHostKeyChecking no" -p "${l_port}" "${l_account}@${l_ip}" "kubectl api-resources")
  # shellcheck disable=SC2181
  if [[ $? -ne 0 ]]; then
    error "执行命令失败：ssh -o \"StrictHostKeyChecking no\" -p ${l_port} ${l_account}@${l_ip} \"kubectl api-resources\""
  fi
}

function getApiVersion() {
  export gDefaultRetVal
  export gApiResourcesInfo

  local l_resourceType="$1"

  [[ -z "${gApiResourcesInfo}" ]] && error "获取${l_resourceType}资源的ApiVersion版本时，gApiResourcesInfo参数是空的"

  #从gApiResourcesInfo变量中提取l_resourceType资源的Api版本
  gDefaultRetVal=$(echo "${gApiResourcesInfo}" | awk -v var="${l_resourceType}" '$NF == var {print $3}')
}

export gApiResourcesInfo
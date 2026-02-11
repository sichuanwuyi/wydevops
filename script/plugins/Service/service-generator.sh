#!/usr/bin/env bash

function serviceGenerator_default() {
  local l_resourceType=$2

  #最终确定采用的ApiVersion版本
  [[ -z "${t_apiVersion}" ]] && t_apiVersion="v1"
  info "${l_resourceType}资源的采用的ApiVersion版本是：${t_apiVersion}"

  commonGenerator_default "Service" "${@}"
}
#!/usr/bin/env bash

function serviceAccountGenerator_default() {
  local l_resourceType=$2

  #最终确定采用的ApiVersion版本
  [[ -z "${t_apiVersion}" ]] && t_apiVersion="v1"
  info "plugin.common.k8s.api.version" "${l_resourceType}#${t_apiVersion}"

  commonGenerator_default "ServiceAccount" "${@}"
}
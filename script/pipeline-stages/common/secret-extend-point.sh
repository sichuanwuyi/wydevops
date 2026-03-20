#!/usr/bin/env bash

function decodeSecretInfo_ex() {
  export gDefaultRetVal

  local l_paramName="$1"
  local l_paramValue="$2"

  echo "----------decodeSecretInfo_ex-----------"
  warn "common.secret.extend.point.decoded.secret.info" "${l_paramName}#${l_paramValue}"

  gDefaultRetVal="${l_paramValue}"
}
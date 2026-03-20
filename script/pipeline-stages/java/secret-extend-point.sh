#!/usr/bin/env bash

function _decodeSecretInfo_ex() {
  export gDefaultRetVal

  local l_paramName="$1"
  local l_paramValue="$2"

  echo "----------_decodeSecretInfo_ex-----------"
  warn "global.params.sh.decoded.secret.info" "${l_paramName}#${l_paramValue}"

  gDefaultRetVal="${l_paramValue}"
}
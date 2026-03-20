#!/usr/bin/env bash

function decodeSecretInfo_ex() {
  export gDefaultRetVal

  local l_paramName="$1"
  local l_paramValue="$2"

  echo "----------decodeSecretInfo_ex-----------"

  gDefaultRetVal="${l_paramValue}"
}
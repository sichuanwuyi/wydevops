#!/usr/bin/env bash

function _readDSCredentialParams_ex() {
  export gDefaultRetVal

  local l_valuesYaml=$1

  local l_username
  local l_password

  readParam "${l_valuesYaml}" "params.ds.mysql.master.username" "MySQL#master"
  [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]] && l_username="${gDefaultRetVal}" \
    || warn "java.chart.extend.point.ds.username.not.found"

  readParam "${l_valuesYaml}" "params.ds.mysql.master.password" "MySQL#master"
  [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]] && l_password="${gDefaultRetVal}" \
    || warn "java.chart.extend.point.ds.password.not.found"

  if [[ "${l_username}" && "${l_password}" ]];then
    warn "java.chart.extend.point.ds.secret.generated.success" "MySQL#master"
    gDefaultRetVal="${l_username}|null|${l_password}"
  else
    warn "java.chart.extend.point.ds.secret.generated.failed" "MySQL#master"
    gDefaultRetVal=""
  fi
}
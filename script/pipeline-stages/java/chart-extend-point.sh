#!/usr/bin/env bash

function _readDSCredentialParams_ex() {
  export gDefaultRetVal

  local l_valuesYaml=$1

  local l_username
  local l_password
  local l_key

  declare -A paramMaps
  # 新增顺序索引数组
  declare -a paramKeys

  getAllParamPathAndValue "${l_valuesYaml}" "params.ds" "paramMaps" "paramKeys"
  # 遍历数组
  for l_key in "${paramKeys[@]}"; do
    echo "---${l_key}=${paramMaps[${l_key}]}---"
  done

  readParam "${l_valuesYaml}" "params.ds.mysql.master.username" "MySQL#master"
  [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]] && l_username="${gDefaultRetVal}" \
    || warn "java.chart.extend.point.ds.username.not.found"

  readParam "${l_valuesYaml}" "params.ds.mysql.master.password" "MySQL#master"
  [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]] && l_password="${gDefaultRetVal}" \
    || warn "java.chart.extend.point.ds.password.not.found"

  if [[ "${l_username}" && "${l_password}" ]];then
    warn "java.chart.extend.point.ds.params.reading.success" "MySQL#master"
    gDefaultRetVal="${l_username}|null|${l_password}"
  else
    warn "java.chart.extend.point.ds.params.reading.failed" "MySQL#master"
    gDefaultRetVal=""
  fi
}
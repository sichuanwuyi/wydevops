#!/usr/bin/env bash

function queryNexusComponentId() {
  export gDefaultRetVal

  local l_ipAddr=$1
  local l_restfulPort=$2
  local l_repository=$3
  local l_componentName=$4
  local l_componentVersion=$5

  local l_result
  local l_id

  gDefaultRetVal=""

  echo "curl -X 'GET' -H 'accept: application/json' http://${l_ipAddr}:${l_restfulPort}/service/rest/v1/search?repository=${l_repository}&name=${l_componentName}&version=${l_componentVersion}"
  l_result=$(curl -X 'GET' -H 'accept: application/json' \
    "http://${l_ipAddr}:${l_restfulPort}/service/rest/v1/search?repository=${l_repository}&name=${l_componentName}&version=${l_componentVersion}" 2>&1)
  l_result=$(echo -e "${l_result}" | grep -m 1 -oP "^([ ]*)\"id\" : (.*)$")
  if [ "${l_result}" ];then
    l_id="${l_result#*:}"
    l_id="${l_id%\"*}"
    l_id="${l_id/\"/}"
    l_id="${l_id// /}"
    gDefaultRetVal="${l_id}"
  fi

}

function deleteNexusComponentById() {
  export gDefaultRetVal

  local l_ipAddr=$1
  local l_restfulPort=$2
  local l_componentId=$3

  local l_result
  local l_errorLog

  gDefaultRetVal="false"

  echo "curl -X 'DELETE' -H 'accept: application/json' http://${l_ipAddr}:${l_restfulPort}/service/rest/v1/components/${l_componentId}"
  l_result=$(curl -X 'DELETE' -H 'accept: application/json' "http://${l_ipAddr}:${l_restfulPort}/service/rest/v1/components/${l_componentId}" 2>&1)
  l_errorLog=$(echo -e "${l_result}" |  grep -ioP "^(.*)(Error|Failed)(.*)$")
  [[ ! "${l_errorLog}" ]] && gDefaultRetVal="true"

}

function pushNexusChartComponent(){

  local l_ipAddr=$1
  local l_restfulPort=$2
  local l_repository=$3
  local l_chartFile=$4
  local l_account=$5
  local l_password=$6

  local l_tmpFile
  local l_result
  local l_errorLog

  l_tmpFile="chart-push-${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"

  info "开始推送chart镜像到仓库中..."
  curl -v -F file=@"${l_chartFile}" -u "${l_account}":"${l_password}" \
    "http://${l_ipAddr}:${l_restfulPort}/service/rest/v1/components?repository=${l_repository}" 2>&1 | tee "${l_tmpFile}"
  l_result=$(cat "${l_tmpFile}")
  l_errorLog=$(echo -e "${l_result}" | grep -ioP "^(.*)(Error|Failed)(.*)$")
  if [ "${l_errorLog}" ];then
    error "chart镜像推送失败：\n${l_result}"
  else
    info "chart镜像推送成功"
  fi

  unregisterTempFile "${l_tmpFile}"
}
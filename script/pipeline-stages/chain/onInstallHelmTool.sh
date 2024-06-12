#!/usr/bin/env bash

function onInstallHelmTool_windows() {
  export gDefaultRetVal

  local l_scriptRootDir=$1
  local l_systemType=$2
  local l_archType=$3

  if [ "${l_systemType}" != "windows" ];then
    gDefaultRetVal="false|"
    return
  fi

  _installHelmCommand "${l_scriptRootDir}" "${l_systemType}" "${l_archType}" "helm.exe"

  gDefaultRetVal="true|true"
}

function onInstallHelmTool_linux() {
  export gDefaultRetVal

  local l_scriptRootDir=$1
  local l_systemType=$2
  local l_archType=$3

  if [ "${l_systemType}" != "linux" ];then
    gDefaultRetVal="false|"
    return
  fi

  _installHelmCommand "${l_scriptRootDir}" "${l_systemType}" "${l_archType}" "helm"

  gDefaultRetVal="true|true"
}

function _installHelmCommand() {
  local l_scriptRootDir=$1
  local l_systemType=$2
  local l_archType=$3
  local l_commandName=$4

  info "开始安装tools/${l_systemType}-${l_archType}目录中的helm工具到${HOME}/helm目录中..."
  mkdir -p "${HOME}/helm" || true
  cp -f "${l_scriptRootDir}/tools/${l_systemType}-${l_archType}/${l_commandName}" "${HOME}/helm/${l_commandName}"

  if command -v helm &> /dev/null; then
    info "安装成功" "*"
  else
    error "安装失败"
  fi

}
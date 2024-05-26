#!/usr/bin/env bash

function onInstallCommand_windows() {
  export gDefaultRetVal
  local l_command=$1

  local l_errorLog

  gDefaultRetVal="false"
  l_errorLog=$(winget --version 2>&1 | grep "not found")
  if [ ! "${l_errorLog}" ];then
    info "-------windows系统下安装${l_command}命令--------"

    l_errorLog=$("${l_command}" --version 2>&1 | grep "not found")
    [[ ! "${l_errorLog}" ]] && gDefaultRetVal="true"
  fi
}

function onInstallCommand_ubuntu() {
  export gDefaultRetVal
  local l_command=$1
  local l_errorLog

  gDefaultRetVal="false"
  l_errorLog=$(apt --version 2>&1 | grep "not found")
  if [ ! "${l_errorLog}" ];then
    info "-------ubuntu系统下安装${l_command}命令--------"

    sudo apt install -y "${l_command}" 2>&1

    l_errorLog=$("${l_command}" --version 2>&1 | grep "not found")
    [[ ! "${l_errorLog}" ]] && gDefaultRetVal="true"
  fi
}

function onInstallCommand_centos() {
  export gDefaultRetVal
  local l_command=$1
  info "-------centos系统下安装${l_command}命令--------"
  gDefaultRetVal="false"
}
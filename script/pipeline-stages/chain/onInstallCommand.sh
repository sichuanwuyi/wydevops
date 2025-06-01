#!/usr/bin/env bash

#本调用链主要是用来在不同系统下自动安装需要的命令或工具。

function onInstallCommand_windows() {
  export gDefaultRetVal
  local l_command=$1

  local l_errorLog

  gDefaultRetVal="false"
  if command -v winget >/dev/null 2>&1; then
    info "-------windows系统下安装${l_command}命令--------"

    if command -v "${l_command}" >/dev/null 2>&1; then
        gDefaultRetVal="true"
    fi
  fi

  gDefaultRetVal="true|${gDefaultRetVal}"
}

function onInstallCommand_ubuntu() {
  export gDefaultRetVal
  local l_command=$1
  local l_errorLog

  gDefaultRetVal="false"
  if command -v apt &>/dev/null; then
    info "-------ubuntu系统下安装${l_command}命令--------"

    sudo apt install -y "${l_command}" 2>&1

    if command -v "${l_command}" >/dev/null 2>&1; then
      gDefaultRetVal="true"
    fi
  fi
  gDefaultRetVal="true|${gDefaultRetVal}"
}

function onInstallCommand_centos() {
  export gDefaultRetVal
  local l_command=$1
  info "-------centos系统下安装${l_command}命令--------"
  gDefaultRetVal="false"

  gDefaultRetVal="true|${gDefaultRetVal}"
}
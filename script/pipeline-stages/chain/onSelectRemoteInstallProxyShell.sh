#!/usr/bin/env bash

function onSelectRemoteInstallProxyShell_default() {
  export gDefaultRetVal
  local l_index=$1
  #读取优先级最高的remote-install-proxy.sh文件。
  #优先级从高到低：语言级>公共级
  readDockerDeployParam "${l_index}" "" "remote-install-proxy.sh"
}
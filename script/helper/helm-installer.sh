#!/usr/bin/env bash

#*********************************************************************#
#安装helm工具的助手类
#*********************************************************************#

function installHelmTool() {
  local l_scriptRootDir=$1
  local l_systemType=$2
  local l_archType=$3

  local l_content

  l_content=$(helm version | grep -oP "not found" )
  if [ "${l_content}" ];then
    cp -f "${l_scriptRootDir}/tools/${l_systemType}-${l_archType}"/helm /usr/local/bin/helm
    chmod -R 777 /usr/local/bin/helm
  fi

  l_content=$(helm version | grep -oP "not found" )
  if [ "${l_content}" ];then
    error "安装tools/${l_systemType}-${l_archType}目录中的helm工具失败"
  else
    info "成功安装tools/${l_systemType}-${l_archType}目录中的helm工具"
  fi
}
#!/usr/bin/env bash

function onGetLocalSystemArchInfo_ubuntu() {
  export gDefaultRetVal
  local l_content=$1

  gDefaultRetVal="false"

  if [ ! "${l_content}" ];then
    l_content=$(uname -sm)
  fi

  if [[ ! "${l_content}" =~ ^(.*)(not found)(.*)$ ]];then
    l_content="${l_content// /\/}"
    if [[ ! "${l_content}" =~ ^(.*)(x86_64)(.*)$ ]];then
      l_content="${l_content%%/*}/amd64"
    else
      l_content="${l_content%%/*}/arm64"
    fi
    #全部转小写后返回。
    gDefaultRetVal="${l_content,,}"
  fi
}

function onGetLocalSystemArchInfo_windows() {
  export gDefaultRetVal
  local l_content=$1

  gDefaultRetVal="false"

  if [ ! "${l_content}" ];then
    l_content=$(systeminfo)
  fi

  l_content=$(echo "${l_content}" | grep "Microsoft Windows")
  if [ "${l_content}" ];then
    l_content=$(arch | grep "x86_64")
    [[ "${l_content}" ]] && gDefaultRetVal="windows/amd64" || gDefaultRetVal="windows/arm64"
  fi
}

function onGetLocalSystemArchInfo_centos() {
  export gDefaultRetVal
  #与ubuntu系统相同的方式获取系统架构信息。
  onGetLocalSystemArchInfo_ubuntu "${@}"
}
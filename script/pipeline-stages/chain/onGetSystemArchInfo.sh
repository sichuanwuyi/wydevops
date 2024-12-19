#!/usr/bin/env bash

function onGetSystemArchInfo_ubuntu() {
  export gDefaultRetVal

  local l_ip=$1
  local l_port=$2
  local l_account=$3

  local l_result
  local l_errorLog
  local l_systemType

  gDefaultRetVal="false|"

  #先判断是否是linux系统
  if [ "${l_ip}" ];then
    info "执行命令: ssh -o \"StrictHostKeyChecking no\" -p ${l_port} ${l_account}@${l_ip} uname -sm"
    #3秒超时
    l_result=$(ssh -o "StrictHostKeyChecking no" -p "${l_port}" "${l_account}@${l_ip}" "uname -sm")
  else
    info "执行命令: uname -sm"
    #本地执行uname命令
    l_result=$(uname -sm)
  fi
  info "返回结果：${l_result}"

  #连接被拒绝或超时
  l_errorLog=$(echo -e "${l_result}" | grep -ioP "(refused|timed[ ]*out)")
  [[ "${l_errorLog}" ]] && error "SSH连接${l_ip}服务失败：\n${l_result}"

  #uname命令不存在，肯定不是linux系统，直接返回。
  l_errorLog=$(echo -e "${l_result}" | grep -ioP "not[ ]*found")
  [[ "${l_errorLog}" ]] && return

  #如果命令执行结果中没有linux串，则判定为windows系统
  l_systemType="linux"
  l_errorLog=$(echo -e "${l_result}" | grep -ioP "linux")
  [[ ! "${l_errorLog}" ]] && l_systemType="windows"

  #如果命令执行结果中包含了x86串，则判定为linux/amd64架构，反之为linux/arm64
  l_errorLog=$(echo -e "${l_result}" | grep -ioP "x86")
  if [[ "${l_errorLog}" ]];then
    l_result="${l_systemType}/amd64"
  else
    l_result="${l_systemType}/arm64"
  fi

  #全部转小写后返回。
  gDefaultRetVal="true|${l_result}"

}
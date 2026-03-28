#!/usr/bin/env bash

function onGetSystemArchInfo_ubuntu() {
  export gDefaultRetVal

  local l_ip=$1
  local l_port=$2
  local l_account=$3
  local l_password=$4

  local l_result
  local l_errorLog
  local l_systemType

  gDefaultRetVal="false|"

  #先判断是否是linux系统
  if [ "${l_ip}" ];then
    #尝试先完成免密登录配置
    tryConnectByPasswordless "${l_account}" "${l_password}" "${l_ip}"

    #使用*.pem文件登录，例如登录AWS EC2服务器
    if [[ "${l_password}" =~ ^(.*).pem$ ]];then
      info "on.get.system.arch.info.executing.command.with.pem.file" "${l_password}#${l_port}#${l_account}#${l_ip}"
      #登录AWS EC2服务器后执行uname -sm命令
      l_result=$(ssh -i "${l_password}" -p "${l_port}" "${l_account}@${l_ip}" "uname -sm")
    else
      info "on.get.system.arch.info.executing.command" "${l_port}#${l_account}#${l_ip}"
      #3秒超时
      l_result=$(ssh -o "StrictHostKeyChecking no" -p "${l_port}" "${l_account}@${l_ip}" "uname -sm")
    fi
  else
    info "on.get.system.arch.info.executing.local.command" ""
    #本地执行uname命令
    l_result=$(uname -sm)
  fi
  if [ ! "${l_result}" ];then
    error "on.get.system.arch.info.ssh.connection.failed" "${l_ip}"
  fi
  info "on.get.system.arch.info.command.result" "${l_result}"

  #连接被拒绝或超时
  l_errorLog=$(grep -io "(refused|timed[ ]*out)" <<< "${l_result}")
  [[ "${l_errorLog}" ]] && error "on.get.system.arch.info.ssh.connection.failed.with.reason" "${l_ip}#${l_result}"

  #uname命令不存在，肯定不是linux系统，直接返回。
  l_errorLog=$(grep -io "not[ ]*found" <<< "${l_result}")
  [[ "${l_errorLog}" ]] && return

  #如果命令执行结果中没有linux串，则判定为windows系统
  l_systemType="linux"
  l_errorLog=$(grep -io "linux" <<< "${l_result}")
  [[ ! "${l_errorLog}" ]] && l_systemType="windows"

  #如果命令执行结果中包含了x86串，则判定为linux/amd64架构，反之为linux/arm64
  l_errorLog=$(grep -io "x86" <<< "${l_result}")
  if [[ "${l_errorLog}" ]];then
    l_result="${l_systemType}/amd64"
  else
    l_result="${l_systemType}/arm64"
  fi

  #全部转小写后返回。
  gDefaultRetVal="true|${l_result}"

}
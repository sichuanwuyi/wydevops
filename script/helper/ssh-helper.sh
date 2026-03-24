#!/usr/bin/env bash

function tryConnectByPasswordless() {
  export gDefaultRetVal

  local l_user=$1
  local l_host=$2

  local l_result

  gDefaultRetVal="true"

  # shellcheck disable=SC2088
  if [ ! -f "~/.ssh/id_rsa.pub" ];then
    info "ssh.helper.execute.command.ssh.keygen"
    ssh-keygen -t rsa -b 4096 -C "wydevops@wydevops.com"
    if [ "$?" -ne 0 ];then
      warn "ssh.helper.execute.command.failed" "unknown"
      gDefaultRetVal="false"
      return
    fi
  fi

  info "ssh.helper.execute.command.ssh.copy.id" "${l_host}" "-n"
  l_result=$(ssh-copy-id "${l_user}@${l_host}" 2>&1)
  if [ "$?" -ne 0 ];then
    warn "ssh.helper.execute.command.failed" "\n${l_result}" "*"
    gDefaultRetVal="false"
    return
  fi
  warn "ssh.helper.execute.command.success" "" "*"

}

#!/usr/bin/env bash

function tryConnectByPasswordless() {
  export gDefaultRetVal

  local l_user=$1
  local l_host=$2

  local l_idRSAFile
  local l_result

  gDefaultRetVal="true"

  # shellcheck disable=SC2088
  l_idRSAFile="${HOME}/.ssh/id_rsa"
  # shellcheck disable=SC2088
  if [ ! -f "${l_idRSAFile}" ];then
    info "ssh.helper.execute.command.ssh-keygen"
    l_result=$(ssh-keygen -t rsa -b 4096 -f "${l_idRSAFile}" -N "" -C "wydevops@wydevops.com" 2>&1)
    if [ "$?" -ne 0 ];then
      warn "ssh.helper.execute.ssh-keygen.failed" "\n${l_result}"
      gDefaultRetVal="false"
      return
    fi
  fi

  l_result=$(ssh-copy-id -o "BatchMode=yes" "${l_user}@${l_host}" 2>&1)
  if [ "$?" -ne 0 ];then
    l_result=$(ssh-copy-id "${l_user}@${l_host}")
    if [ "$?" -ne 0 ];then
      warn "ssh.helper.execute.ssh-copy-id.failed" "${l_host}#\n${l_result}"
      gDefaultRetVal="false"
      return
    else
      info "ssh.helper.execute.ssh-copy-id.success" "${l_host}"
    fi
  fi
  warn "ssh.helper.config.passwordless.success" "${l_host}"

}

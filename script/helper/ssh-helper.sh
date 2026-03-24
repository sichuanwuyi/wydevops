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
    ssh-keygen -t rsa -b 4096 -f "${l_idRSAFile}" -N "" -C "wydevops@wydevops.com"
    if [ "$?" -ne 0 ];then
      warn "ssh.helper.execute.ssh-keygen.failed" "unknown"
      gDefaultRetVal="false"
      return
    fi
  fi

  info "ssh.helper.execute.command.ssh-copy-id" "${l_host}" "-n"
  l_result=$(ssh-copy-id -o "BatchMode=yes" "${l_user}@${l_host}" 2>&1)
  echo "--------?=$?-----------"
  if [ "$?" -ne 0 ];then
    warn "ssh.helper.execute.ssh-copy-id.failed" "\n${l_result}" "*"
    gDefaultRetVal="false"
    return
  fi
  warn "ssh.helper.execute.ssh-copy-id.success" "" "*"

}

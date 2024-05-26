#!/usr/bin/env bash

function onCustomizedSetParams_ex() {
  echo "--- onCustomizedSetParams_ex ---"
  local l_namespace=$1

  export gBuildPath
  export gShellExecuteResult

  executeShellScript "${gBuildPath}" "onCustomizedSetParams.sh" "${l_namespace}"
  if [ "${gShellExecuteResult}" == "false" ];then
    echo "未发现扩展文件：onCustomizedSetParams.sh"
  fi
}


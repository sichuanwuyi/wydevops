#!/usr/bin/env bash

#从配置文件中初始化Map对象。
function initialMapFromConfigFile() {
  export gDefaultRetVal

  local l_configFile=$1
  local l_mapName=$2

  local l_content
  local l_lines
  local l_rowNum
  local l_line

  local l_lineCount
  local l_i
  local l_key
  local l_value

  local l_defineMapName
  local l_defineBindingFiles

  # shellcheck disable=SC2002
  l_content=$(cat "${l_configFile}" | grep -noP "^([ ]*)[_a-zA-Z]+")
  stringToArray "${l_content}" "l_lines"
  # shellcheck disable=SC2154
  l_lineCount=${#l_lines[@]}
  for ((l_i = 0; l_i < l_lineCount; l_i++));do
    l_rowNum="${l_lines[${l_i}]%%:*}"
    l_line=$(sed -n "${l_rowNum}p" "${l_configFile}")
    if [[ "${l_line}" =~ ^(.*)=(.*)$ ]];then
      l_key="${l_line%=*}"
      l_value="${l_line##*=}"
      if [ "${l_key}" == "define.exitOnError" ];then
        l_defineMapName="${l_value}"
      elif [ "${l_key}" == "define.bindingFiles" ];then
        l_defineBindingFiles="${l_value}"
      else
        eval "${l_mapName}[\"${l_key}\"]=${l_value}"
      fi
    fi
  done

  gDefaultRetVal="${l_defineMapName}|${l_defineBindingFiles}"
}
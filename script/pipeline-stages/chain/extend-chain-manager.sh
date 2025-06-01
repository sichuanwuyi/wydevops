#!/usr/bin/env bash

function invokeExtendChain() {
  export gInvokeChainRegTables
  export gDefaultRetVal

  local l_chainName=$1
  local l_param=("${@}")

  #删除前1个参数
  # shellcheck disable=SC2184
  unset l_param[0]
  # shellcheck disable=SC2206
  l_param=(${l_param[*]})

  local l_chainContent
  local l_chains
  local l_chain
  local l_shellFile
  local l_content
  local l_funcNames
  local l_funcName

  l_chainContent="${gInvokeChainRegTables[${l_chainName}]}"
  # shellcheck disable=SC2206
  l_chains=(${l_chainContent//;/ })
  gDefaultRetVal="false"
  # shellcheck disable=SC2068
  for l_chain in ${l_chains[@]};do
    l_shellFile="${l_chain%%|*}"
    l_content="${l_chain#*|}"
    # shellcheck disable=SC2206
    l_funcNames=(${l_content//,/ })
    # shellcheck disable=SC2068
    for l_funcName in ${l_funcNames[@]};do
      #如果方法l_funcName不存在，则加载一次l_shellFile文件。
      if ! type -t "${l_funcName}" > /dev/null; then
        #注意l_shellFile文件必须是全路径的，确保能访问到并且有执行权限。
        # shellcheck disable=SC1090
        source "${l_shellFile}"
        if ! type -t "${l_funcName}" > /dev/null; then
          error "调用链${l_chainName}异常:${l_shellFile}脚本文件中不存在${l_funcName}方法"
        fi
      fi
      #依次调用调用链上的方法，直至返回”true“为止。
      # shellcheck disable=SC2068
      "${l_funcName}" ${l_param[@]}
      # shellcheck disable=SC2145
      if [[ "${gDefaultRetVal}" =~ ^(true\|) ]];then
        break
      fi
    done
    if [[ "${gDefaultRetVal}" =~ ^(true\|) ]];then
      break
    fi
  done

  #如果gDefaultRetVal已false开头，则说明没有找到匹配的方法处理传入的参数。
  #直接报错退出。
  if [[ "${gDefaultRetVal}" =~ ^(false\|) ]];then
    error "调用链${l_chainName}执行失败：未找到与传入参数匹配的方法"
  fi

  gDefaultRetVal="${gDefaultRetVal#*|}"
}

function registerChain() {
  export gInvokeChainRegTables

  local l_chainName=$1
  #格式：{脚本文件全路径名称1}|{脚本文件中函数名称1},{脚本文件中函数名称2};{脚本文件全路径名称n}|{脚本文件中函数名称n1},{脚本文件中函数名称n2}...
  local l_funcName=$2
  #是否插入到头部(第一个调用)
  local l_insertHead=$3

  local l_chainContent

  if [ ! "${l_insertHead}" ];then
    l_insertHead="false"
  fi

  # shellcheck disable=SC2128
  if [[ "${l_chainName}" && "${l_funcName}" ]];then
    l_chainContent="${gInvokeChainRegTables[${l_chainName}]}"
    if [ ! "${l_chainContent}" ];then
      gInvokeChainRegTables["${l_chainName}"]="${l_funcName}"
    elif [ "${l_insertHead}" == "true" ];then
      gInvokeChainRegTables["${l_chainName}"]="${l_funcName};${l_chainContent}"
    else
      gInvokeChainRegTables["${l_chainName}"]="${l_chainContent};${l_funcName}"
    fi
  fi
}

function unregisterChain() {
  export gInvokeChainRegTables

  local l_chainName=$1

  if [ "${l_chainName}" ];then
    unset gInvokeChainRegTables["${l_chainName}"]
  fi
}

function loadExtendChain() {
  export gPipelineScriptsDir

  local l_shellList
  local l_shellFile
  local l_chainName
  local l_funcNames
  local l_lines
  local l_lineCount
  local l_i
  local l_funcName
  local l_funcNameStr

  l_shellList=$(find "${gPipelineScriptsDir}/chain" -type f -name "on*.sh")
  # shellcheck disable=SC2068
  for l_shellFile in ${l_shellList[@]};do
    l_chainName="${l_shellFile##*/}"
    l_chainName="${l_chainName%%.*}"
    # shellcheck disable=SC2002
    #l_funcNames=$(cat "${l_shellFile}" | grep -oP "^(function)[ ]+${l_chainName}_(.*)\(\)([ ]*)\{")
    l_funcNames=$(grep -oP "^function\\s+${l_chainName}_\\w+\\s*\\(\\s*\\)\\s*\\{" "${l_shellFile}")
    stringToArray "${l_funcNames}" "l_lines"
    l_lineCount=${#l_lines[@]}

    l_funcNameStr=""
    for ((l_i = 0; l_i < l_lineCount; l_i ++));do
      l_funcName="${l_lines[${l_i}]}"
      l_funcName="${l_funcName// /}"
      l_funcName="${l_funcName//function/}"
      l_funcName="${l_funcName%%(*}"
      l_funcNameStr="${l_funcNameStr},${l_funcName}"
    done

    #注册调用链。
    info "注册${l_chainName}调用链:${l_shellFile##*/}|${l_funcNameStr:1}"
    registerChain "${l_chainName}" "${l_shellFile}|${l_funcNameStr:1}"
    # shellcheck disable=SC1090
    source "${l_shellFile}"
  done
}

#定义全局调用链注册表
declare -A gInvokeChainRegTables
export gInvokeChainRegTables

export gDefaultRetVal

loadExtendChain
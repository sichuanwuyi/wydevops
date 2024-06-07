#!/usr/bin/env bash

function invokeResourceGenerator() {
  export gPluginRegTables
  export gDefaultRetVal

  local l_resourceType=$1
  local l_funcNameSuffix=$2

  local l_param=("${@}")

  #删除前2个参数
  # shellcheck disable=SC2184
  unset l_param[0]
  # shellcheck disable=SC2184
  unset l_param[1]
  # shellcheck disable=SC2206
  l_param=(${l_param[*]})

  local l_registerContent
  local l_funcName
  local l_result

  l_registerContent="${gPluginRegTables[${l_resourceType}]}"
  l_result=$(echo -e "${l_registerContent}," | grep -oP ",${l_funcNameSuffix},")
  if [ "${l_result}" ];then
    l_funcName="${l_resourceType,}Generator_${l_funcNameSuffix}"
    #如果方法l_funcName不存在，则加载一次l_shellFile文件。
    if ! type -t "${l_funcName}" > /dev/null; then
      error "未找到资源生成器方法：${l_funcName}"
    fi
    # shellcheck disable=SC2068
    "${l_funcName}" ${l_param[@]}
  else
    error "未注册的资源生成器方法：${l_funcName}"
  fi

}

function registerPlugin() {
  export gPluginRegTables

  local l_resourceType=$1
  #格式：{生成器函数名称后缀1},{生成器函数名称后缀2},...
  local l_generatorNames=$2
  #是否插入到头部(该文件第一个调用)
  local l_insertHead=$3

  local l_registerContent
  local l_result

  if [ ! "${l_insertHead}" ];then
    l_insertHead="false"
  fi

  # shellcheck disable=SC2128
  if [[ "${l_resourceType}" && "${l_generatorNames}" ]];then
    l_registerContent="${gPluginRegTables[${l_resourceType}]}"
    if [ ! "${l_registerContent}" ];then
      gPluginRegTables["${l_resourceType}"]="${l_generatorNames}"
    elif [ "${l_insertHead}" == "true" ];then
      gPluginRegTables["${l_resourceType}"]="${l_generatorNames},${l_registerContent}"
    else
      gPluginRegTables["${l_resourceType}"]="${l_registerContent},${l_generatorNames}"
    fi
  fi

  #检测生成器方法重复。
  l_registerContent="${gPluginRegTables[${l_resourceType}]}"
  l_result=$(echo -e "${l_registerContent}," | grep -oP "[a-zA-Z0-9_\-]+," | sort | uniq -c | grep -oP "^([ ]*)[2-9]{1}[0-9]*(.*)$")
  l_result=$(echo -e "${l_result}" | grep -oP "[a-zA-Z_]+[a-zA-Z0-9_\-]*")
  [[ "${l_result}" ]] && error "以下资源生成器方法重名:\n${l_result}"

}

function unregisterPlugin() {
  export gPluginRegTables

  local l_resourceType=$1

  if [ "${l_resourceType}" ];then
    unset gPluginRegTables["${l_resourceType}"]
  fi
}

function loadPlugins() {
  export gBuildScriptRootDir
  export gProjectPluginDir

  local l_pluginDirs
  local l_pluginDir

  local l_pluginGeneratorList
  local l_pluginGenerator
  local l_generatorFile
  local l_resourceType

  local l_funcNames
  local l_lines
  local l_lineCount
  local l_i
  local l_funcName
  local l_funcNameStr
  local l_result

  l_pluginDirs=("${gBuildScriptRootDir}/plugins" "${gProjectPluginDir}")
  # shellcheck disable=SC2068
  for l_pluginDir in ${l_pluginDirs[@]};do

    l_pluginGeneratorList=$(find "${l_pluginDir}" -maxdepth 2 -type f -name "*-generator.sh")
    # shellcheck disable=SC2068
    for l_pluginGenerator in ${l_pluginGeneratorList[@]};do
      l_generatorFile="${l_pluginGenerator##*/}"
      l_resourceType="${l_generatorFile%%-*}"
      # shellcheck disable=SC2002
      l_funcNames=$(cat "${l_pluginGenerator}" | grep -oP "^(function) ${l_resourceType,}Generator_(.*)\(\)([ ]*)\{([ ]*)$")
      stringToArray "${l_funcNames}" "l_lines"
      l_lineCount=${#l_lines[@]}

      l_funcNameStr=""
      for ((l_i = 0; l_i < l_lineCount; l_i ++));do
        l_funcName="${l_lines[${l_i}]}"
        l_funcName="${l_funcName// /}"
        l_funcName="${l_funcName//function/}"
        l_funcName="${l_funcName%%(*}"
        l_funcName="${l_funcName//${l_resourceType,}Generator_/}"
        l_result=$(echo -e "${l_funcNameStr}," | grep -oP "${l_funcName},")
        [[ "${l_result}" ]] && error "${l_resourceType}类型的资源生成器名称冲突：${l_resourceType,}Generator_${l_funcName}名称已经存在"
        l_funcNameStr="${l_funcNameStr},${l_funcName}"
      done

      #注册调用链。
      info "注册${l_resourceType}类型的资源生成器插件:${l_funcNameStr:1}"
      registerPlugin "${l_resourceType}" "${l_funcNameStr:1}"
      # shellcheck disable=SC1090
      source "${l_pluginGenerator}"
    done

  done
}

#定义全局调用链注册表
declare -A gPluginRegTables
export gPluginRegTables

export gDefaultRetVal

loadPlugins
#!/usr/bin/env bash

function invokeResourceGenerator() {
  export gPluginRegTables
  export gDefaultRetVal
  export gBuildScriptRootDir

  local l_resourceType=$1
  local l_generatorName=$2
  local l_valuesYaml=$3
  local l_index=$4
  local l_configPath=$5

  local l_registerContent
  local l_registerItems
  local l_registerItemCount
  local l_i

  local l_registerItem
  local l_fileName
  local l_funcName
  local l_result
  local l_isOk
  local l_found

  local l_pluginDirs
  local l_pluginDir
  local l_configFiles
  local l_configFile

  #构造生成器方法名称
  l_funcName="${l_resourceType,}Generator_${l_generatorName}"

  l_registerContent="${gPluginRegTables[${l_resourceType}]}"
  stringToArray "${l_registerContent}" "l_registerItems" ";"
  # shellcheck disable=SC2124
  l_registerItemCount="${#l_registerItems[@]}"

  l_found="false"
  for ((l_i=0; l_i < l_registerItemCount; l_i++));do
    l_registerItem="${l_registerItems[${l_i}]}"
    l_fileName="${l_registerItem%%|*}"
    l_registerItem="${l_registerItem#*|}"
    l_result=$(echo -e "${l_registerItem}" | grep -oP "${l_funcName},")
    if [ "${l_result}" ];then
      info "找到匹配的资源生成器方法：${l_funcName}"
      "${l_funcName}" "${l_fileName}" "${@}"
      l_found="true"
    fi
  done

  [[ "${l_found}" == "true" ]] && return

  warn "未找到匹配的资源生成器方法：${l_funcName}"

  l_isOk="false"
  #查找l_resourceType目录下是否存在配置文件，如果存在则直接拷贝到l_valuesYaml文件所在目录下的templates子目录中
  info "继续查找${l_resourceType}资源配置文件..."
  l_pluginDirs=("${gBuildScriptRootDir}/plugins/${l_resourceType}" "${gProjectPluginDir}/${l_resourceType}")
  # shellcheck disable=SC2068
  for l_pluginDir in ${l_pluginDirs[@]};do
    #目录不存在则继续下一个。
    [[ ! -d "${l_pluginDir}" ]] && continue
    #查找符合条件的配置文件。
    l_configFiles=$(find "${l_pluginDir}" -maxdepth 1 -type f -name "${l_resourceType,}-${l_generatorName}*.yaml")
    [[ ! "${l_configFiles}" ]] && continue
    # shellcheck disable=SC2066
    for l_configFile in ${l_configFiles[@]};do
      [[ "${l_configFile}" =~ ^(.*)-template.yaml ]] && continue
      info "找到${l_configFile##*/}资源配置文件,拷贝到当前chart镜像的templates目录中"
      cp -f "${l_configFile}" "${l_valuesYaml%/*}/templates/"
      l_isOk="true"
    done
  done

  [[ "${l_isOk}" == "false" ]] && error "未能找到${l_resourceType}资源配置文件"

}

function registerPlugin() {
  export gPluginRegTables

  local l_resourceType=$1
  #格式：{shell文件全路径名称1}|{生成器函数名称后缀1},{生成器函数名称后缀2},...;{shell文件全路径名称2}|{生成器函数名称后缀1}...
  local l_generatorNames=$2

  local l_registerContent
  local l_result

  # shellcheck disable=SC2128
  if [[ "${l_resourceType}" && "${l_generatorNames}" ]];then
    l_registerContent="${gPluginRegTables[${l_resourceType}]}"
    if [ ! "${l_registerContent}" ];then
      gPluginRegTables["${l_resourceType}"]="${l_generatorNames}"
    else
      l_registerContent="${l_registerContent};${l_generatorNames}"

      #检测生成器方法是否存在重复。
      l_result=$(echo -e "${l_registerContent}" | grep -oP "[a-zA-Z0-9_\-]+," | sort | uniq -c | grep -oP "^([ ]*)[2-9]{1}[0-9]*(.*)$")
      l_result=$(echo -e "${l_result}" | grep -oP "[a-zA-Z_]+[a-zA-Z0-9_\-]*")
      [[ "${l_result}" ]] && error "以下资源生成器方法重名:${l_result}"

      gPluginRegTables["${l_resourceType}"]="${l_registerContent}"
    fi
  fi
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
  export gBuildPath
  export gHelmBuildDirName
  export gProjectPluginDirName

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

  l_pluginDirs=("${gBuildScriptRootDir}/plugins" "${gBuildPath}/${gHelmBuildDirName}/${gProjectPluginDirName}")
  # shellcheck disable=SC2068
  for l_pluginDir in ${l_pluginDirs[@]};do
    [[ ! -d "${l_pluginDir}" ]] && continue
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
        l_result=$(echo -e "${l_funcNameStr}," | grep -oP "${l_funcName},")
        [[ "${l_result}" ]] && error "${l_resourceType}类型的资源生成器名称冲突：${l_resourceType,}Generator_${l_funcName}名称已经存在"
        l_funcNameStr="${l_funcNameStr}${l_funcName},"
      done
      #注册调用链。
      info "注册${l_resourceType^}类型的资源生成器插件:${l_funcNameStr}"
      registerPlugin "${l_resourceType^}" "${l_pluginGenerator}|${l_funcNameStr}"
      # shellcheck disable=SC1090
      source "${l_pluginGenerator}"
    done

  done
}

function commonGenerator_default() {
  export gDefaultRetVal
  export gBuildPath
  #模板中引用了这两个全局变量
  export gCurrentChartName
  export gCurrentChartVersion

  local l_expectResourceType=$1
  local l_generatorFile=$2
  local l_resourceType=$3
  local l_generatorName=$4
  local l_valuesYaml=$5
  local l_deploymentIndex=$6
  local l_configPath=$7

  local l_templateFile
  local l_targetFile
  local l_content

  #模板中需要的变量以“t_”开头
  local t_deploymentName
  local t_moduleName
  local t_kindType

  t_kindType="${l_resourceType}"
  if [ "${t_kindType}" != "${l_expectResourceType}" ];then
    gDefaultRetVal="false"
    return
  fi

  t_moduleName="deployment${l_deploymentIndex}"
  readParam "${l_valuesYaml}" "${t_moduleName}.name"
  t_deploymentName="${gDefaultRetVal}"

  l_templateFile="${l_generatorFile%/*}/${l_resourceType,}-${l_generatorName}-template.yaml"
  [[ ! -f "${l_templateFile}" ]] && error "目标模板文件不存在：${l_templateFile}"
  # shellcheck disable=SC2145
  info "加载${l_resourceType}模板文件：${l_templateFile##*/}"

  #设定目标配置文件
  l_targetFile="${l_valuesYaml%/*}/templates/${t_deploymentName}-${l_resourceType,,}.yaml"

 #读取模板文件内容。
  l_content=$(cat "${l_templateFile}")
  #替换模板中的变量。
  eval "l_content=\$(echo -e \"${l_content}\")"
  #将替换后的内容写入配置文件中。
  echo "${l_content}" > "${l_targetFile}"

  gDefaultRetVal="true"
}

#定义全局调用链注册表
declare -A gPluginRegTables
export gPluginRegTables

export gDefaultRetVal

loadPlugins
#!/usr/bin/env bash

#------------------------语言级扩展方法------------------------#

function _initGlobalParams_ex() {
  export gLanguage
  debug "针对${gLanguage}语言项目，修改或新增全局参数..."

  export gBuildPath
  export gReleaseNoteFileName
  export gReleaseNotePath

  debug "1.设置項目更新历史文件(${gReleaseNoteFileName})所在的目录"
  gReleaseNotePath="${gBuildPath}/src/main/resources"

}

function _createCiCdConfigFile_ex() {
  export gLanguage
  local l_tmpCiCdConfigFile=$2

  declare -A _configFileMap
  declare -A _javaYamlParamMap
  declare -A _javaPomParamMap

  invokeExtendPointFunc "initialParamLoadConfigMap" "参数加载方式配置MAP二次初始化扩展"
  invokeExtendPointFunc "initCiCdConfigFileByParamLoadMap" "_ci-cd-config.yaml文件中参数的初始化" "${l_tmpCiCdConfigFile}"
}

function _initCiCdConfigFileByParamLoadMap_ex() {
  export gBuildPath
  export _configFileMap

  local l_yamlFile=$1

  local l_key
  local l_value
  local l_exitFlag

  # shellcheck disable=SC2068
  for l_key in ${!_configFileMap[@]};do
    l_value=${_configFileMap["${l_key}"]}
    if [ "${l_value}" ];then
      info "从${l_value}系列文件中读取需要的全局参数初始化值:"
      if [[ "${l_key}" =~ ^(.*)\|(.*)$ ]];then
        l_exitFlag="${l_key#*|}"
      else
        l_exitFlag=""
      fi
      _processJavaProjectParamMap "${l_value}" "${l_yamlFile}" "${l_key%%|*}" "${l_exitFlag}"
    fi
  done
}

function _initialParamLoadConfigMap_ex() {
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gBuildPath
  export gLanguage

  export _configFileMap
  export _javaYamlParamMap
  export _javaPomParamMap

  local l_configFile

  l_configFile="${gBuildPath}/ci-cd/read-param-initial-value-from-yaml-file.config"
  if [ ! -f "${l_configFile}" ];then
    l_configFile="${gBuildScriptRootDir}/templates/config/${gLanguage}/read-param-initial-value-from-yaml-file.config"
  fi

  if [ -f "${l_configFile}" ];then
    initialMapFromConfigFile "${l_configFile}" "_javaYamlParamMap"
    _configFileMap["_javaYamlParamMap|${gDefaultRetVal%%|*}"]="${gDefaultRetVal#*|}"
  fi

  l_configFile="${gBuildPath}/ci-cd/read-param-initial-value-from-xml-file.config"
  if [ ! -f "${l_configFile}" ];then
    l_configFile="${gBuildScriptRootDir}/templates/config/${gLanguage}/read-param-initial-value-from-xml-file.config"
  fi

  if [ -f "${l_configFile}" ];then
    initialMapFromConfigFile "${l_configFile}" "_javaPomParamMap"
    _configFileMap["_javaPomParamMap|${gDefaultRetVal%%|*}"]="${gDefaultRetVal#*|}"
  fi
}

function _onBeforeReplaceParamPlaceholder_ex() {
  export gBuildPath

  local l_pomXmlFile
  local l_module

  l_pomXmlFile="${gBuildPath}/pom.xml"
  if [ ! -f "${l_pomXmlFile}" ];then
    error "未找到Java项目的pom.xml文件"
  fi

  debug "多模块项目符合性检测..."
  l_module=$(xmllint --xpath  '/*[local-name()="project"]/*[local-name()="modules"]/*[local-name()="module"]/text()' "${l_pomXmlFile}" 2>&1)
  if [[ ${l_module} && ${l_module} != "XPath set is empty" && ${gBuildPath} == './' ]];then
    error "多模块项目符合性检测失败：实际是多模块的项目，配置的gBuildPath参数不能以\"/\"结尾"
  fi
}

#-------------------------私有方法----------------------------#

function _processJavaProjectParamMap() {
  export gDefaultRetVal

  #文件列表，以空格隔开。
  local l_sourceFiles=$1
  local l_cicdConfigFile=$2
  local l_targetMapName=$3
  local l_exitOnFailure=$4

  local l_shortFileNames
  local l_paramTotal
  local l_targetMapKey
  local l_key
  local l_value

  local l_keyItems
  local l_keyItem
  local l_paramPath
  local l_readMode
  local l_subKeyItems
  local l_paramValue

  local l_valueItems
  local l_valueItemCount
  local l_valueItem
  local l_subValueItems

  local l_paramCount
  local l_hasError

  if [ ! "${l_exitOnFailure}" ];then
    l_exitOnFailure="false"
  fi

  # shellcheck disable=SC2206
  l_keyItems=(${l_sourceFiles})
  l_shortFileNames=""
  # shellcheck disable=SC2068
  for l_keyItem in ${l_keyItems[@]};do
    if [ ! "${l_shortFileNames}" ];then
      l_shortFileNames="${l_keyItem##*/}"
    else
      l_shortFileNames="${l_shortFileNames}、${l_keyItem##*/}"
    fi
  done

  eval "l_paramTotal=\${#${l_targetMapName}[@]}"

  #读取Map对象的所有Key赋值给l_targetMapKey变量。
  eval "l_targetMapKey=\${!${l_targetMapName}[@]}"
  ((l_paramCount = 0))

  for l_key in ${l_targetMapKey}; do
    info "从${l_shortFileNames}文件中读取参数${l_key}..."
    #读取需要设置的l_cicdConfigFile文件中的参数名称列表。
    l_value=$(eval "echo -e \${${l_targetMapName}[\"${l_key}\"]}")
    if [ ! "${l_value}" ];then
      #该参数已经处理过了，直接跳过。
      info "参数${l_key}已读取过了，直接跳过该参数"
      continue
    fi

    #将l_value转换为数组l_valueItems。
    stringToArray "${l_value}" "l_valueItems" $';'

    l_hasError="false"
    stringToArray "${l_key}" "l_keyItems" $';'
    # shellcheck disable=SC2068
    for l_keyItem in ${l_keyItems[@]};do
      #如果l_keyItem包含“=”号，则是前置条件。
      if [[ "${l_keyItem}" =~ ^(.*)=(.*)$ ]];then
        stringToArray "${l_keyItem}" "l_subKeyItems" $'='
        #取实际的参数路径（l_keyItem中可能带有参数读取模式类型）
        #取从右向左最后一个“|”符号的左边部分赋值给l_paramPath
        l_paramPath="${l_subKeyItems[0]%%|*}"
        if [[ "${l_subKeyItems[0]}" =~ ^(.*)\|(.*)$ ]];then
          #取从左向右第一个“|”的右边部分赋值给l_readMode
          l_readMode="${l_subKeyItems[0]#*|}"
        else
          l_readMode="0"
        fi
        _readParamValueEx "${l_sourceFiles}" "${l_paramPath}" "${l_readMode}"
        l_paramValue="${gDefaultRetVal}"
        #如果指定参数不存在，则跳过该参数。
        if [ "${l_paramValue}" == "null" ];then
          warn "从${l_shortFileNames}文件中读取${l_paramPath}参数失败"
          l_hasError="true"
          break
        fi
        #如果读取的参数值与要求的参数值不匹配并且也不相等，则跳过该参数
        if [[ "${l_subKeyItems[1]}" =~ ^\^ ]];then
          if [[ ! "${l_paramValue}" =~ ${l_subKeyItems[1]} ]];then
            #如果不匹配，则跳过该参数。
            warn "参数${l_paramPath}的值${l_paramValue}与配置的正则表达式${l_subKeyItems[1]}不匹配"
            l_hasError="true"
            break
          fi
        else
          if [[ "${l_paramValue}" =~ ^([ ]*)(\") ]];then
            #去掉前后引号
            l_paramValue="${l_paramValue:1}"
            l_paramValue="${l_paramValue%\"*}"
          fi
          if [ "${l_paramValue}" != "${l_subKeyItems[1]}" ];then
            #如果不匹配，则跳过该参数。
            warn "参数${l_paramPath}的值${l_paramValue}与配置值${l_subKeyItems[1]}不相等"
            l_hasError="true"
            break
          fi
        fi
      else
        #取实际的参数路径（l_keyItem中可能带有参数读取模式类型）
        #取从右向左最后一个“|”符号的左边部分赋值给l_paramPath
        l_paramPath="${l_keyItem%%|*}"
        if [[ "${l_keyItem}" =~ ^(.*)\|(.*)$ ]];then
          #取从左向右第一个“|”的右边部分赋值给l_readMode
          l_readMode="${l_keyItem#*|}"
        else
          l_readMode="0"
        fi

        #读取参数的值，并更新文件中指定的参数。
        _readParamValueEx "${l_sourceFiles}" "${l_paramPath}" "${l_readMode}"
        l_paramValue="${gDefaultRetVal}"

        #循环更新文件中的参数。
        for l_valueItem in ${l_valueItems[@]};do
          #转换为数组,取第一个数组项作为目标参数。
          stringToArray "${l_valueItem}" "l_subValueItems" $'|'
          l_valueItemCount="${#l_subValueItems[@]}"

          #如果l_paramValue为null,则继续检查默认值和优先值变量。
          if [[ ! "${l_paramValue}" || "${l_paramValue}" == "null" ]];then
            #没有读取到参数值，则读取默认值
            if [[ "${l_valueItemCount}" -ge 2 && "${l_subValueItems[1]}" ]];then
              l_paramValue="${l_subValueItems[1]}"
            fi
          fi

          if [ "${l_paramValue}" == "null" ];then
            l_hasError="true"
            break
          fi

          #更新文件中的指定参数的值。
          updateParam "${l_cicdConfigFile}" "${l_subValueItems[0]}" "${l_paramValue}"
          if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
            warn "更新${l_cicdConfigFile##*/}文件中${l_subValueItems[0]}参数失败"
            l_hasError="true"
            break
          else
            info "更新${l_cicdConfigFile##*/}文件中${l_subValueItems[0]}参数值为:${l_paramValue}"
            l_hasError="false"
          fi

        done
      fi
    done

    if [ "${l_hasError}" == "false" ];then
      #清除Map项的值，标识该参数已经读取过了
      eval "${l_targetMapName}[\"${l_key}\"]=\"\""
      #累计处理的参数数量。
      ((l_paramCount = l_paramCount + 1))
    fi

  done

  #显示读取失败的参数
  if [ "${l_paramCount}" -ne "${l_paramTotal}" ];then
    l_error=""
    # shellcheck disable=SC2068
    for l_key in ${l_targetMapKey}; do
      l_value=$(eval "echo -e \${${l_targetMapName}[\"${l_key}\"]}")
      #从l_value中读取参数的默认值。如果没有默认值(没有“|”符号)，则认定为错误。
      if [ "${l_value}" ];then
        l_error="${l_error}\n从${l_shortFileNames}文件中读取参数${l_key}失败"
      fi
    done

    if [ "${l_error}" ];then
      if [ "${l_exitOnFailure}" == "true" ];then
        error "${l_error}"
      else
        warn "${l_error}"
      fi
    fi
  fi
}

function _readParamValueEx() {
  export gDefaultRetVal
  export gBuildPath

  #多个文件间用空格隔开。
  local l_targetFiles=$1
  local l_paramPath=$2
  local l_readMode=$3

  local l_sourceFiles
  local l_sourceFile

  gDefaultRetVal="null"

  # shellcheck disable=SC2206
  l_sourceFiles=(${l_targetFiles})
  # shellcheck disable=SC2068
  for l_sourceFile in ${l_sourceFiles[@]};do
    l_sourceFile=${l_sourceFile//\"/}
    if [[ "${l_sourceFile}" =~ ^(\./) ]];then
      l_sourceFile="${gBuildPath}/${l_sourceFile#*/}"
    fi
    if [[ "${l_sourceFile}" =~ ^(.*)\.xml$ ]];then
      _readParamValueFromXmlFile "${l_sourceFile}" "${l_paramPath}" "${l_readMode}"
    else
      readParam "${l_sourceFile}" "${l_paramPath}"
    fi
    if [ "${gDefaultRetVal}" != "null" ];then
      break
    fi
  done
}

function _readParamValueFromXmlFile() {
  export gDefaultRetVal

  #多个文件间用空格隔开。
  local l_sourceFile=$1
  local l_paramPath=$2
  local l_readMode=$3

  local l_subPaths
  local l_subPath
  local l_xmlPath

  local l_arrayLen
  local l_paramName
  local l_array
  local l_item

  gDefaultRetVal="null"

  stringToArray "${l_paramPath}" "l_subPaths" $'.'
  if [ "${l_readMode}" == "1" ];then
    #读取中文信息的方式
    l_arrayLen="${#l_subPaths[@]}"
    ((l_arrayLen = l_arrayLen - 1))
    l_paramName="${l_subPaths[l_arrayLen]}"
    # shellcheck disable=SC2002
    l_item=$(cat "${l_sourceFile}" | grep "<${l_paramName}>")
    if [ "${l_item}" ];then
      # shellcheck disable=SC2206
      l_array=(${l_item})
      l_item="${l_array[0]}"
      l_item="${l_item//<${l_paramName}>/}"
      l_item="${l_item//<\/${l_paramName}>/}"
      gDefaultRetVal="${l_item}"
    fi
  else
    l_xmlPath=""
    # shellcheck disable=SC2068
    for l_subPath in ${l_subPaths[@]};do
      l_xmlPath="${l_xmlPath}/*[local-name()=\"${l_subPath}\"]"
    done
    l_xmlPath="${l_xmlPath}/text()"
    l_item=$(xmllint --xpath  "${l_xmlPath}" "${l_sourceFile}" 2>&1)
    if [ "${l_item}" != "XPath set is empty" ];then
      gDefaultRetVal="${l_item}"
    fi
  fi
}
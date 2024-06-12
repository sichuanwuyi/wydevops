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

  local l_exitOnError
  local l_defineBindingFiles
  local l_configMapFiles

  local l_array

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
        l_exitOnError="${l_value}"
      elif [[ "${l_key}" =~ ^(define\.bindingFiles) ]];then
        l_defineBindingFiles="${l_value}"
        if [[ "${l_key}" =~ ^(.*)\|true(\|.*$|$) ]];then
          # shellcheck disable=SC2206
          l_array=(${l_key//|/ })
          if [ "${#l_array[@]}" -gt 2 ];then
            #带上configMapName一起输出。
            l_configMapFiles="${l_configMapFiles},${l_array[2]}=${l_value}"
          else
            l_configMapFiles="${l_configMapFiles},${l_value}"
          fi
        fi
      else
        eval "${l_mapName}[\"${l_key}\"]=${l_value}"
      fi
    fi
  done

  gDefaultRetVal="${l_exitOnError}|${l_defineBindingFiles}|${l_configMapFiles:1}"
}

function initialParamValueByMappingConfigFiles() {
  local l_buildPath=$1
  local l_yamlFile=$2
  local l_key=$3
  local l_value=$4
  local l_mapName=$5

  local l_exitFlag

  if [ "${l_value}" ];then
    info "从${l_value}系列文件中读取需要的全局参数初始化值:"
    if [[ "${l_key}" =~ ^(.*)\|(.*)$ ]];then
      l_exitFlag="${l_key#*|}"
    else
      l_exitFlag="false"
    fi

    #将项目参数映射到wydevops对应的参数。
    _processProjectParamMapping "${l_buildPath}" "${l_value}" "${l_yamlFile}" "${l_key%%|*}" "${l_exitFlag}" "${l_mapName}"

  fi
}

#------------------------私有方法--开始-------------------------#

function _processProjectParamMapping() {
  export gDefaultRetVal
  export _alreadyProcessedParamMap

  #文件列表，以空格隔开。
  local l_buildPath=$1
  local l_sourceFiles=$2
  local l_cicdConfigFile=$3
  local l_targetMapName=$4
  local l_exitOnFailure=$5
  local l_mapName=$6

  local l_shortFileNames
  local l_paramTotal
  local l_targetMapKey
  local l_key
  local l_value

  local l_keyItems
  local l_keyItem
  local l_paramPath
  local l_subKeyItems
  local l_paramValue

  local l_valueItems
  local l_valueItemCount
  local l_valueItem
  local l_subValueItems
  local l_tmpParamNames

  local l_paramCount
  local l_hasError
  local l_array

  # shellcheck disable=SC2206
  l_keyItems=(${l_sourceFiles//,/ })
  l_shortFileNames=""
  # shellcheck disable=SC2068
  for l_keyItem in ${l_keyItems[@]};do
    l_shortFileNames="${l_shortFileNames}、${l_keyItem##*/}"
  done
  l_shortFileNames="${l_shortFileNames:1}"

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

        _parseParamKey "${l_subKeyItems[0]}" "${l_exitOnFailure}"
        # shellcheck disable=SC2206
        l_array=(${gDefaultRetVal})
        _readParamValueEx "${l_buildPath}" "${l_sourceFiles}" "${l_paramPath}" "${l_array[0]}" "${l_array[1]}"
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

        _parseParamKey "${l_keyItem}" "${l_exitOnFailure}"
        # shellcheck disable=SC2206
        l_array=(${gDefaultRetVal})
        #读取参数的值，并更新文件中指定的参数。
        _readParamValueEx "${l_buildPath}" "${l_sourceFiles}" "${l_paramPath}" "${l_array[0]}" "${l_array[1]}"
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

          #判断是否已经赋值过该参数了，如果已经赋值过则不再赋值。
          l_tmpParamNames=$(eval "echo -e \${!${l_mapName}[@]}")
          if [[ "${l_tmpParamNames}" =~ ${l_subValueItems[0]}( |$) ]];then
            warn "${l_cicdConfigFile##*/}文件中${l_subValueItems[0]}参数已经赋值，禁止再次赋值"
            continue
          fi

          #更新文件中的指定参数的值。
          updateParam "${l_cicdConfigFile}" "${l_subValueItems[0]}" "${l_paramValue}"
          if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
            warn "更新${l_cicdConfigFile##*/}文件中${l_subValueItems[0]}参数失败"
            l_hasError="true"
            break
          else
            #记录已经赋过值的参数。
            eval "${l_mapName}[${l_subValueItems[0]}]=\"${l_paramValue}\""
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
        error "${l_error:2}"
      else
        warn "${l_error:2}"
      fi
    fi
  fi
}

function _parseParamKey() {
  export gDefaultRetVal

  local l_paramKey=$1
  local l_exitOnFailure=$2

  local l_exitOnFailure1
  local l_readMode
  local l_array

  l_exitOnFailure1="${l_exitOnFailure}"
  l_readMode="0"
  if [[ "${l_paramKey}" =~ ^(.*)\|(.*)$ ]];then
    #尝试读取参数实际的路径和错误退出标志值。
    # shellcheck disable=SC2206
    l_array=(${l_paramKey//\|/ })
    #${l_array[1]}存放的是该参数读取失败退出标志
    if [[ "${l_array[1]}" == "true" || "${l_array[1]}" == "false" ]];then
      l_exitOnFailure1="${l_array[1]}"
    elif [[ "${#l_array[@]}" -gt 2 && "${l_array[2]}" =~ ^[0-9]+$ ]];then
      #${l_array[2]}存放的是该参数读取方式
      l_readMode="${l_array[2]}"
    fi
  fi

  gDefaultRetVal="${l_exitOnFailure1} ${l_readMode}"
}

function _readParamValueEx() {
  export gDefaultRetVal

  #多个文件间用空格隔开。
  local l_buildPath=$1
  local l_targetFiles=$2
  local l_paramPath=$3
  local l_exitOnFailure=$4
  local l_readMode=$5

  local l_sourceFiles
  local l_sourceFile
  local l_found

  gDefaultRetVal="null"
  l_found="false"
  # shellcheck disable=SC2206
  l_sourceFiles=(${l_targetFiles//,/ })
  # shellcheck disable=SC2068
  for l_sourceFile in ${l_sourceFiles[@]};do
    #去掉引号
    l_sourceFile=${l_sourceFile//\"/}
    #相对路径转绝对路径
    if [[ "${l_sourceFile}" =~ ^(\./) ]];then
      l_sourceFile="${l_buildPath}/${l_sourceFile#*/}"
    fi

    if [ ! -f "${l_sourceFile}" ];then
      warn "${l_sourceFile##*/}文件不存在，直接跳过"
      continue
    fi

    #调用从不同文件中获取参数值方法。
    invokeExtendChain "onReadParamValueFromFile" "${l_sourceFile}" "${l_paramPath}" "${l_readMode}"

    if [ "${gDefaultRetVal}" != "null" ];then
      l_found="true"
      break
    fi
  done

  if [[ "${l_found}" == "false" ]];then
    if [[ "${l_exitOnFailure}" == "true" ]];then
      error "从${l_sourceFile##*/}文件中读取${l_paramPath}参数失败，请确保该参数存在。"
    else
      warn "从${l_sourceFile##*/}文件中读取${l_paramPath}参数失败，请确保该参数存在。"
    fi
  fi
}

#------------------------私有方法--结束-------------------------#
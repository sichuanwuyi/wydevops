#!/usr/bin/env bash

function onReadParamValueFromXmlFile_english() {
  export gDefaultRetVal

  local l_sourceFile=$1
  local l_paramPath=$2
  local l_readMode=$3

  if [ "${l_readMode}" != "0" ];then
    gDefaultRetVal="false|"
    return
  fi

  local l_subPaths
  local l_subPath
  local l_xmlPath
  local l_item

  gDefaultRetVal="null"

  stringToArray "${l_paramPath}" "l_subPaths" $'.'
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
  gDefaultRetVal="true|${gDefaultRetVal}"
}

#从XML文件中读取中文参数值。使用这个方法可以避免中文乱码问题。
function onReadParamValueFromXmlFile_chinese() {
  export gDefaultRetVal

  local l_sourceFile=$1
  local l_paramPath=$2
  local l_readMode=$3

  if [ "${l_readMode}" != "1" ];then
    gDefaultRetVal="false|"
    return
  fi

  local l_subPaths

  local l_arrayLen
  local l_paramName
  local l_array
  local l_item

  gDefaultRetVal="null"

  stringToArray "${l_paramPath}" "l_subPaths" $'.'
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

  gDefaultRetVal="true|${gDefaultRetVal}"
}
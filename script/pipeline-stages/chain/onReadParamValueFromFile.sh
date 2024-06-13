#!/usr/bin/env bash

function onReadParamValueFromFile_yaml() {
  export gDefaultRetVal

  local l_sourceFile=$1
  local l_paramPath=$2

  #不是yaml文件则直接返回(gDefaultRetVal=false)继续调用下一个方法
  if [[ ! "${l_sourceFile##*/}" =~ ^(.*)\.(yaml|yml)$ ]];then
    gDefaultRetVal="false|"
    return
  fi
  readParam "${l_sourceFile}" "${l_paramPath}"
  gDefaultRetVal="true|${gDefaultRetVal}"
}

function onReadParamValueFromFile_xml() {
  export gDefaultRetVal

  local l_sourceFile=$1
  local l_paramPath=$2
  local l_readMode=$3

  #不是xml文件则直接返回(gDefaultRetVal=false)继续调用下一个方法
  if [[ ! "${l_sourceFile##*/}" =~ ^(.*)\.xml$ ]];then
    gDefaultRetVal="false|"
    return
  fi

  #调用不同读取模式的方法。
  invokeExtendChain "onReadParamValueFromXmlFile" "${l_sourceFile}" "${l_paramPath}" "${l_readMode}"
  gDefaultRetVal="true|${gDefaultRetVal}"
}

function onReadParamValueFromFile_ini() {
  export gDefaultRetVal

  local l_sourceFile=$1
  local l_paramPath=$2
  local l_readMode=$3

  #不是xml文件则直接返回(gDefaultRetVal=false)继续调用下一个方法
  if [[ ! "${l_sourceFile##*/}" =~ ^(.*)\.ini$ ]];then
    gDefaultRetVal="false|"
    return
  fi

  #todo: 暂时未实现
}

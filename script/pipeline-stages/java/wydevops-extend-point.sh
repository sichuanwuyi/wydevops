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

  local l_templateFile=$1
  local l_tmpCiCdConfigFile=$2

  local l_tmpFile

  l_tmpFile="${l_tmpCiCdConfigFile}"
  [[ ! -f "${l_tmpCiCdConfigFile}" ]] && l_tmpFile="${l_templateFile}"

  invokeExtendPointFunc "loadParamMappingConfigFiles" "加载${gLanguage}语言级参数映射配置文件"
  invokeExtendPointFunc "initParamValueByMappingConfigFiles" "根据参数映射配置文件初始化${l_tmpFile##*/}文件中的参数" "${l_tmpFile}"

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


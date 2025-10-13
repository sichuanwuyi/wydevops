#!/usr/bin/env bash

#------------------------语言级扩展方法------------------------#

function _onBeforeInitGlobalParams_ex() {
  export gBuildPath
  export gRuntimeVersion

  local l_pomXmlFile
  local l_tmpVersion

  #xmllint命令检查
  if ! command -v xmllint &> /dev/null; then
    error "xmllint命令未找到，请先安装libxml2工具包"
  fi

  l_pomXmlFile="${gBuildPath}/pom.xml"
  if [ ! -f "${l_pomXmlFile}" ];then
      error "未找到Java项目的pom.xml文件"
  fi

  #读取JDK的版本
  l_tmpVersion=$(xmllint --xpath  '/*[local-name()="project"]/*[local-name()="properties"]/*[local-name()="maven.compiler.target"]/text()' "${l_pomXmlFile}" 2>&1)
  if [ ! "${l_tmpVersion}" ];then
    l_tmpVersion=$(xmllint --xpath  '/*[local-name()="project"]/*[local-name()="properties"]/*[local-name()="maven.compiler.source"]/text()' "${l_pomXmlFile}" 2>&1)
  fi

  #数值校验（支持整数和小数）
  if ! [[ "${l_tmpVersion}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    l_pomXmlFile=$(dirname "${gBuildPath%/}")
    l_pomXmlFile="${l_pomXmlFile}/pom.xml"
    if [ ! -f "${l_pomXmlFile}" ];then
      error "未找到Java项目的pom.xml文件"
    fi

    #再次读取JDK的版本
    l_tmpVersion=$(xmllint --xpath  '/*[local-name()="project"]/*[local-name()="properties"]/*[local-name()="maven.compiler.target"]/text()' "${l_pomXmlFile}" 2>&1)
    if [ ! "${l_tmpVersion}" ];then
      l_tmpVersion=$(xmllint --xpath  '/*[local-name()="project"]/*[local-name()="properties"]/*[local-name()="maven.compiler.source"]/text()' "${l_pomXmlFile}" 2>&1)
    fi
  fi

  if ! [[ "${l_tmpVersion}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    error "未找到Java项目的pom.xml文件中的maven.compiler.target或maven.compiler.source参数:${l_tmpVersion}"
  fi

  gRuntimeVersion="jdk${l_tmpVersion}"

  mkdir -p "${gBuildPath}/wydevops/templates/" || true
  if [ -d "${gBuildPath}/src/main/resources/templates/chart" ];then
    #将项目resources/templates目录下的chart目录复制到${gBuildPath}/wydevops/templates目录中
    cp -rf "${gBuildPath}/src/main/resources/templates/chart" "${gBuildPath}/wydevops/templates/" || true
  fi

  if [ -d "${gBuildPath}/src/main/resources/templates/docker" ];then
    #将项目resources/templates目录下的docker目录复制到${gBuildPath}/wydevops/templates目录中
    cp -rf "${gBuildPath}/src/main/resources/templates/docker" "${gBuildPath}/wydevops/templates/" || true
  fi

}

function _initialCiCdConfigFileByParamMappingFiles_ex() {
    export gLanguage
    local l_templateFile=$1
    local l_tmpCiCdConfigFile=$2

    local l_version

    debug "针对${gLanguage}语言项目，处理从映射文件中加载的参数值..."

    #读取globalParams.businessVersion参数的值。
#    readParam "${l_templateFile}" "globalParams.businessVersion"
#    if [ "${gDefaultRetVal}" == "null" ];then
#      error "${l_templateFile}文件中globalParams.businessVersion参数不能为空"
#    fi
#
#    if [[ "${gDefaultRetVal}" =~ ^(.*)-SNAPSHOT$ ]];then
#      l_version="${gDefaultRetVal//-SNAPSHOT/}"
#    fi
}

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
  export gRuntimeVersion

  local l_cicdFile=$1
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

function _onLoadMatchedAdditionalConfigFiles_ex() {
  export gDefaultRetVal
  export gActiveProfile

  local l_configFiles=$1

  local l_resourcesDir
  local l_yamlList
  local l_ymalFile
  local l_configFileName
  local l_configFile
  local l_targetFile

  l_configFileName="application.yml"
  if [[ "${l_configFiles}" != *"${l_configFileName}"* ]];then
    gDefaultRetVal=""
    return
  fi

  l_targetFile=""
  l_resourcesDir="${gBuildPath}/src/main/resources"
  info "读取spring.profiles.active参数的值"
  l_yamlList=$(find "${l_resourcesDir}" -maxdepth 2 -type f  -name "application*.yml")
  if [ "${l_yamlList}" ];then
    # shellcheck disable=SC2068
    for l_ymalFile in ${l_yamlList[@]}
    do
      readParam "${l_ymalFile}" "spring.profiles.active"
      if [ "${gDefaultRetVal}" != "null" ];then
        #去掉注释部分
        gActiveProfile="${gDefaultRetVal%%#*}"
        #去掉左右空格
        gActiveProfile="${gActiveProfile#"${gActiveProfile%%[![:space:]]*}"}"
        gActiveProfile="${gActiveProfile%"${gActiveProfile##*[^[:space:]]}"}"
        warn "spring.profiles.active参数的值为:${gActiveProfile}"
        l_configFileName="application-${gActiveProfile}.yml"
        l_configFile="${l_ymalFile%/*}/${l_configFileName}"
        if [ -f "${l_configFile}" ];then
           if [[ "${l_configFiles}" != *"${l_configFileName}"* ]];then
             l_targetFile=".${l_configFile//${gBuildPath}/}"
           fi
         fi
        break
      fi
    done
  fi
  gDefaultRetVal="${l_targetFile}"
}

function _onFailToLoadingParamMappingFiles_ex(){
  export gLanguage
  error "缺少${gLanguage}语言级的参数映射配置文件，该配置文件定义了如何从项目配置文件中读取wyDevops需要的参数。"
}

export gActiveProfile
export gRuntimeVersion

#-------------------------私有方法----------------------------#

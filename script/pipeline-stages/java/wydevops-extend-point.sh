#!/usr/bin/env bash

#------------------------语言级扩展方法------------------------#

function _checkMultipleModelProjectInJenkins_ex(){
  #直接调用本地模式下的多模块检测方法。
  _checkMultipleModelProjectInLocal_ex
}

function _checkMultipleModelProjectInLocal_ex(){
  export gBuildPath
  export gMultipleModelProject

  #获取 ${gBuildPath} 的父目录
  info "java.wydevops.extend.point.current.project.build.dir" "${gBuildPath}"
  parent_dir=$(dirname "${gBuildPath}")

  # 使用 [ -f ] 判断 pom.xml 文件是否存在于父目录中
  if [ -f "${parent_dir}/pom.xml" ]; then
    info "java.wydevops.extend.point.pom.exists.in.parent.dir" "${parent_dir}"
    gMultipleModelProject="true"
  else
    info "java.wydevops.extend.point.pom.not.exists.in.parent.dir" "${parent_dir}"
    gMultipleModelProject="false"
  fi

}

function _onBeforeInitGlobalParams_ex() {
  export gBuildPath
  export gRuntimeVersion

  local l_pomXmlFile
  local l_tmpVersion

  #xmllint命令检查
  if ! command -v xmllint &> /dev/null; then
    error "java.wydevops.extend.point.xmllint.not.found"
  fi

  l_pomXmlFile="${gBuildPath}/pom.xml"
  if [ ! -f "${l_pomXmlFile}" ];then
      error "java.wydevops.extend.point.pom.not.found"
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
      error "java.wydevops.extend.point.pom.not.found"
    fi

    #再次读取JDK的版本
    l_tmpVersion=$(xmllint --xpath  '/*[local-name()="project"]/*[local-name()="properties"]/*[local-name()="maven.compiler.target"]/text()' "${l_pomXmlFile}" 2>&1)
    if [ ! "${l_tmpVersion}" ];then
      l_tmpVersion=$(xmllint --xpath  '/*[local-name()="project"]/*[local-name()="properties"]/*[local-name()="maven.compiler.source"]/text()' "${l_pomXmlFile}" 2>&1)
    fi
  fi

  if ! [[ "${l_tmpVersion}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    error "java.wydevops.extend.point.maven.compiler.param.not.found" "${l_tmpVersion}"
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

    info "java.wydevops.extend.point.processing.params.from.mapping.files" "${gLanguage}"

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
  info "java.wydevops.extend.point.modifying.or.adding.global.params" "${gLanguage}"

  export gBuildPath
  export gReleaseNoteFileName
  export gReleaseNotePath

  debug "java.wydevops.extend.point.setting.release.note.dir" "${gReleaseNoteFileName}"
  gReleaseNotePath="${gBuildPath}/src/main/resources"

}

function _createCiCdConfigFile_ex() {
  export gLanguage

  local l_templateFile=$1
  local l_tmpCiCdConfigFile=$2

  local l_tmpFile

  l_tmpFile="${l_tmpCiCdConfigFile}"
  [[ ! -f "${l_tmpCiCdConfigFile}" ]] && l_tmpFile="${l_templateFile}"

  invokeExtendPointFunc "loadParamMappingConfigFiles" "java.wydevops.extend.point.loading.param.mapping.config.files" "${gLanguage}"
  invokeExtendPointFunc "initParamValueByMappingConfigFiles" "java.wydevops.extend.point.initializing.params.by.mapping.config.files" "${l_tmpFile##*/}" "${l_tmpFile}"

}


function _onBeforeReplaceParamPlaceholder_ex() {
  export gBuildPath
  export gRuntimeVersion

  local l_cicdFile=$1
  local l_pomXmlFile
  local l_module

  l_pomXmlFile="${gBuildPath}/pom.xml"
  if [ ! -f "${l_pomXmlFile}" ];then
    error "java.wydevops.extend.point.pom.not.found"
  fi

  debug "java.wydevops.extend.point.multi.module.project.compliance.check"
  l_module=$(xmllint --xpath  '/*[local-name()="project"]/*[local-name()="modules"]/*[local-name()="module"]/text()' "${l_pomXmlFile}" 2>&1)
  if [[ ${l_module} && ${l_module} != "XPath set is empty" && ${gBuildPath} == './' ]];then
    error "java.wydevops.extend.point.multi.module.project.compliance.check.failed"
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
  info "java.wydevops.extend.point.reading.spring.profiles.active" "spring.profiles.active"
  l_yamlList=$(find "${l_resourcesDir}" -maxdepth 2 -type f  -name "application*.yml")
  if [ "${l_yamlList}" ];then
    # shellcheck disable=SC2068
    for l_ymalFile in ${l_yamlList[@]}
    do
      echo "------l_ymalFile=${l_ymalFile}--------"
      readParam "${l_ymalFile}" "spring.profiles.active"
      if [ "${gDefaultRetVal}" != "null" ];then
        #去掉注释部分
        gActiveProfile="${gDefaultRetVal%%#*}"
        #去掉左右空格
        gActiveProfile="${gActiveProfile#"${gActiveProfile%%[![:space:]]*}"}"
        gActiveProfile="${gActiveProfile%"${gActiveProfile##*[^[:space:]]}"}"
        warn "java.wydevops.extend.point.spring.profiles.active.value" "spring.profiles.active#${gActiveProfile}"

        if [ "${gActiveProfile}" == "dev" ];then
          warn "java.wydevops.extend.point.force.update.spring.profiles.active" "spring.profiles.active#prod"
          updateParam "${l_ymalFile}" "spring.profiles.active" "prod"
          gActiveProfile="prod"
        fi

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
  echo "------l_targetFile=${l_targetFile}--------"
  gDefaultRetVal="${l_targetFile}"
}

function _onFailToLoadingParamMappingFiles_ex(){
  export gLanguage
  error "java.wydevops.extend.point.missing.param.mapping.config.files" "${gLanguage}"
}

export gActiveProfile
export gRuntimeVersion

#-------------------------私有方法----------------------------#

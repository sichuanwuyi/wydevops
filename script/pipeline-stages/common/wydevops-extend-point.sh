#!/usr/bin/env bash

function onBeforeInitGlobalParams_ex() {
  _onBeforeInitGlobalParams
}

#全局参数初始化
function initGlobalParams_ex() {
  _initGlobalParams
}

function onAfterInitGlobalParams_ex() {
  _onAfterInitGlobalParams
}

function onBeforeReplaceParamPlaceholder_ex() {
  export gBuildType
  export gDockerImageNameWithInstance
  export gDockerRepoInstanceName
  export gDockerRepoType

  local l_cicdYaml=$1
  local l_placeholders
  local l_placeholder

  readParam "${l_cicdYaml}" "globalParams.gatewayPath"
  if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "/" ]];then
    updateParam "${l_cicdYaml}" "globalParams.enableRewrite" "false"
    updateParam "${l_cicdYaml}" "globalParams.apisixRouteRegexUri" "[]"
    updateParam "${l_cicdYaml}" "globalParams.apisixIngressTargetRegex" ""
    info "判定是否启用网关路径重写功能: 禁用"
  else
    updateParam "${l_cicdYaml}" "globalParams.enableRewrite" "true"
    updateParam "${l_cicdYaml}" "globalParams.apisixRouteRegexUri" "[ \"^\${gatewayPath}(.*)\", \"\/\$1\" ]"
    updateParam "${l_cicdYaml}" "globalParams.apisixIngressTargetRegex" "^\${gatewayPath}/(.*)"
    info "判定是否启用网关路径重写功能: 启用"
  fi

  #为业务镜像和基础镜像添加项目名称前缀。
  if [[ "${gDockerRepoType}" == "harbor" || ("${gDockerRepoInstanceName}" && "${gDockerImageNameWithInstance}" == "true") ]];then
    info "为业务镜像和基础镜像添加仓库名称（nexus）或项目名称(harbor)前缀..."
    readParam "${l_cicdYaml}" "globalParams.businessImage"
    info "更新globalParams.businessImage参数的值为:${gDockerRepoInstanceName}/${gDefaultRetVal}"
    updateParam "${l_cicdYaml}" "globalParams.businessImage" "${gDockerRepoInstanceName}/${gDefaultRetVal}"

    readParam "${l_cicdYaml}" "globalParams.baseImage"
    info "更新globalParams.baseImage参数的值为:${gDockerRepoInstanceName}/${gDefaultRetVal}"
    updateParam "${l_cicdYaml}" "globalParams.baseImage" "${gDockerRepoInstanceName}/${gDefaultRetVal}"
  fi

  info "根据构建类型对ci-cd.yaml文件中globalParams.baseWorkDir参数的值添加后缀"
  l_paramName="globalParams.baseWorkDir"
  readParam "${l_cicdYaml}" "${l_paramName}"
  [[ "${gDefaultRetVal}" == "null" ]] && error "${l_cicdYaml##*/}文件中缺少${l_paramName}参数"

  l_paramValue="${gDefaultRetVal}-double"
  [[ "${gBuildType}" == "single" ]] && l_paramValue="${gDefaultRetVal}-single"

  insertParam "${l_cicdYaml}" "${l_paramName}" "${l_paramValue}"
  if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
    error "更新${l_cicdYaml##*/}文件中${l_paramName}参数失败"
  else
    info "更新${l_cicdYaml##*/}文件中${l_paramName}参数的值为:${l_paramValue}"
  fi

  info "将命令行接收的全局参数值写入配置文件中..."
  if [ "${gBuildType}" ];then
    #初始化gBuildType参数。
    updateParam "${l_cicdYaml}" "globalParams.buildType" "${gBuildType}"
  fi

  if [ "${gArchTypes}" ];then
    updateParam "${l_cicdYaml}" "globalParams.archTypes" "${gArchTypes}"
  fi

  if [ "${gOfflineArchTypes}" ];then
    updateParam "${l_cicdYaml}" "globalParams.offlineArchTypes" "${gOfflineArchTypes}"
  fi

  if [ "${gUseTemplate}" ];then
    updateParam "${l_cicdYaml}" "globalParams.useTemplate" "${gUseTemplate}"
  fi

  if [ "${gValidBuildStages}" ];then
    updateParam "${l_cicdYaml}" "globalParams.validBuildStages" "${gValidBuildStages}"
  fi

  #检查文件中是否存在未定义好的占位符号。
  # shellcheck disable=SC2002
  l_placeholders=$(cat "${l_cicdYaml}" | grep -oP "^([ ]*[a-zA-Z_\-]+)" |grep -oP "_([A-Z]?[A-Z0-9\-]+)_" | sort | uniq -c)
  # shellcheck disable=SC2068
  for l_placeholder in ${l_placeholders[@]};do
    if [[ "${l_placeholder}" =~ ^(_).*$ ]];then
      warn "${l_cicdYaml}文件中占位符${l_placeholder}未定义值"
    fi
  done

  if [ "${l_placeholders}" ];then
    error "${l_cicdYaml}文件中存在未定义的占位符"
  fi
}

function replaceParamPlaceholder_ex() {
  _replaceParamPlaceholder "${@}"
}

function createCiCdTemplateFile_ex() {
  export gDefaultRetVal
  export gBuildPath
  export gHelmBuildDirName
  export gCiCdTemplateFileName
  export gBuildScriptRootDir
  export gLanguage

  local l_cicdTemplateFile=$1

  local l_templateFile
  local l_info

  l_templateFile="${gBuildPath}/${gHelmBuildDirName}/templates/config/_${gCiCdTemplateFileName}"
  if [ -f "${l_templateFile}" ];then
    l_info="将项目级_ci-cd-template.yaml模板文件内容复制到${l_cicdTemplateFile##*/}文件中"
  else
    l_templateFile="${gBuildScriptRootDir}/templates/config/${gLanguage}/_${gCiCdTemplateFileName}"
    if [ -f "${l_templateFile}" ];then
      l_info="将语言级_ci-cd-template.yaml模板文件内容复制到${l_cicdTemplateFile##*/}文件中"
    else
      l_templateFile="${gBuildScriptRootDir}/templates/config/_ci-cd-template.yaml"
      l_info="将公共级_ci-cd-template.yaml模板文件内容复制到${l_cicdTemplateFile##*/}文件中"
    fi
  fi

  if [ ! -f "${l_templateFile}" ];then
    error "未找到匹配的_ci-cd-template.yaml模板文件"
  fi

  info "${l_info}"
  cat "${l_templateFile}" > "${l_cicdTemplateFile}"
}

#先尝试复制语言级_ci-cd-config.yaml创建一个项目级的_ci-cd-config.yaml
#如果不存在语言级_ci-cd-config.yaml文件，
#则依据_ci-cd-template.yaml文件创建项目级的_ci-cd-config.yaml
function createCiCdConfigFile_ex() {
  export gBuildScriptRootDir
  export gLanguage

  local l_cicdTemplateFile=$1
  #需要创建的目标文件。
  local l_cicdConfigFile=$2

  #语言级_ci-cd-config.yaml的全路径名称。
  local l_tmpCicdConfigFile
  local l_content
  local l_itemCount
  local l_i

  l_tmpCicdConfigFile="${gBuildScriptRootDir}/templates/config/${gLanguage}/_ci-cd-config.yaml"
  if [ -f "${l_tmpCicdConfigFile}" ];then
    info "复制${gLanguage}类项目的_ci-cd-config.yaml模板文件，创建一个项目级的_ci-cd-config.yaml"
    cat "${l_tmpCicdConfigFile}" > "${l_cicdConfigFile}"
  fi
}

function initialCiCdConfigFileByParamMappingFiles_ex() {
  export gDefaultRetVal
  export gLanguage
  export gBuildPath
  export gHelmBuildDirName
  export gBuildScriptRootDir
  export gParamMappingDirName

  local l_templateFile=$1
  local l_tmpCiCdConfigFile=$2

  local l_cicdTargetFile

  local l_dirList
  local l_mappingFileDir
  local l_paramMappingFiles
  local l_mappingFile
  local l_loadOk
  local l_array
  local l_configMapFiles
  local l_tmpFile
  local l_mapKeys
  local l_mapKey
  local l_mapValue
  local l_index
  local l_content

  #文件及其已经处理过的参数Map。
  # shellcheck disable=SC2034
  declare -A _alreadyProcessedParamMap
  #configMapName与其内的文件Map
  declare -A configMapNameAndFilesMap

  l_cicdTargetFile="${l_tmpCiCdConfigFile}"
  [[ ! -f "${l_tmpCiCdConfigFile}" ]] && l_cicdTargetFile="${l_templateFile}"

  #项目级参数应用文件优先级更高，放置_dirList中最前面的位置。
  l_dirList=("${gBuildPath}/${gHelmBuildDirName}/templates/config/${gLanguage}/${gParamMappingDirName}" "${gBuildScriptRootDir}/templates/config/${gLanguage}/${gParamMappingDirName}")
  #预先定义好各个参数映射文件对应的

  l_loadOk="false"
  # shellcheck disable=SC2068
  for l_mappingFileDir in ${l_dirList[@]};do
    #读取参数映射目录中的配置文件。
    if [ -d "${l_mappingFileDir}" ];then
      l_paramMappingFiles=$(find "${l_mappingFileDir}" -maxdepth 1 -type f -name "*.config")
      if [ "${l_paramMappingFiles}" ];then
        # shellcheck disable=SC2068
        for l_mappingFile in ${l_paramMappingFiles[@]};do

          declare -A _paramMappingMap
          #将参数映射文件中的配置读取到_paramMappingMap变量中。
          initialMapFromConfigFile "${l_mappingFile}" "_paramMappingMap"

          if [ "${#_paramMappingMap[@]}" -gt 0 ];then
            # shellcheck disable=SC2206
            l_array=(${gDefaultRetVal//|/ })
            #收集部署时需要打包到ConfigMap中的配置文件
            if [ "${#l_array[@]}" -gt 2 ];then
              if [[ ! "${l_configMapFiles}" =~ ${l_array[2]//\"/}(,|$) ]];then
                l_configMapFiles="${l_configMapFiles},${l_array[2]//\"/}"
              fi
            fi

            gDefaultRetVal=""
            #如果${l_array[1]}里面包含了application.yml文件，则尝试读取当前环境的配置文件。
            invokeExtendPointFunc "onLoadMatchedAdditionalConfigFiles" "获取当前部署环境对应的配置文件" "${l_array[1]//\"/}"
            if [ "${gDefaultRetVal}" ] && [ "${gDefaultRetVal}" != "null" ];then
              l_array[1]="${gDefaultRetVal},${l_array[1]//\"/}"
              l_configMapFiles="${gDefaultRetVal},${l_configMapFiles:1}"
            fi

            if [ "${#_paramMappingMap[@]}" -gt 0 ];then
              #根据参数映射文件初始化l_cicdTargetFile文件中的参数。
              initialParamValueByMappingConfigFiles "${gBuildPath}" "${l_cicdTargetFile}" \
                "_paramMappingMap|${l_array[0]}" "${l_array[1]}" "_alreadyProcessedParamMap"
              l_loadOk="true"
            fi
          fi
          unset _paramMappingMap
        done
      fi
    fi
  done

  if [ "${l_loadOk}" == "false" ];then
    invokeExtendPointFunc "onFailToLoadingParamMappingFiles" "处理加载参数映射文件失败异常" "${l_array[1]}"
  fi

  [[ "${l_configMapFiles}" =~ ^(,) ]] && l_configMapFiles="${l_configMapFiles:1}"

  #初始化l_cicdTargetFile文件中的configMapFiles参数。
  if [ "${l_configMapFiles}" ];then
    # shellcheck disable=SC2206
    l_array=(${l_configMapFiles//,/ })
    # shellcheck disable=SC2068
    for l_tmpFile in ${l_array[@]};do
      if [[ "${l_tmpFile}" =~ ^(.*)=(.*)$ ]];then
        configMapNameAndFilesMap["${l_tmpFile%%=*}"]="${configMapNameAndFilesMap[${l_tmpFile%%=*}]},${l_tmpFile#*=}"
      else
        configMapNameAndFilesMap["_A_"]="${configMapNameAndFilesMap[_A_]},${l_tmpFile}"
      fi
    done
    # shellcheck disable=SC2124
    l_mapKeys=${!configMapNameAndFilesMap[@]}
    # shellcheck disable=SC2145
    (( l_index = 1))
    # shellcheck disable=SC2068
    for l_mapKey in ${l_mapKeys[@]};do
      l_mapValue="${configMapNameAndFilesMap[${l_mapKey}]}"
      if [ "${l_mapKey}" == "_A_" ];then
        info "初始化${l_cicdTargetFile##*/}文件中的configMapFiles参数的值为:${l_mapValue:1}"
        insertParam "${l_cicdTargetFile}" "globalParams.configMapFiles" "${l_mapValue:1}"
      else
        info "初始化${l_cicdTargetFile##*/}文件中的chart[0].deployments[0].configMaps[${l_index}].files参数的值为:${l_mapValue:1}"
        l_content="name: ${l_mapKey}\nfiles: ${l_mapValue:1}"
        insertParam "${l_cicdTargetFile}" "chart[0].deployments[0].configMaps[${l_index}]" "${l_content}"
        ((l_index = l_index + 1))
      fi
    done
  fi

}

#------------------------私有方法--开始-------------------------#

function _onBeforeInitGlobalParams() {
  export gWorkMode
  export gGitProjectName
  export gBuildPath
  export gLanguage
  export gWorkSpace
  export gMultipleModelProject
  export gCiCdYamlFileName
  export gClearCachedParams

  local l_value
  local l_array

  if [ ! "${gWorkMode}" ];then
    error "未指定工作模式"
  fi

  if [ ! "${gLanguage}" ];then
    error "未指定项目语言类型"
  fi

  if [ "${gWorkMode}" == "jenkins" ];then
    info "从Jenkins全局参数中初始化全局变量"
    _loadJenkinsGlobalParams

    if [ ! "${gBuildPath}" ];then
      error "未指定构建项目主模块路径"
    fi

    info "检测项目是否是多模块项目,并确定项目的构建根目录"
    #修正构建项目根路径。
    if [[ "${gBuildPath}" =~ ^(\.\/[a-zA-Z]+) ]];then
      #将gBuildPath赋值为绝对路径。
      gBuildPath="${gWorkSpace}/${gGitProjectName}/${gBuildPath:2}"
      #多模块工程在build时会回退到上级目录执行build。
      gMultipleModelProject="true"
      info "--->检测到当前项目为多模块项目"
    elif [[ "${gBuildPath}" =~ ^(\.\/) ]];then
      #将gBuildPath赋值为绝对路径。
      gBuildPath="${gWorkSpace}/${gGitProjectName}"
      gMultipleModelProject="false"
      info "--->检测到当前项目为单模块项目"
    fi

    if [ "${gClearCachedParams}" == "true" ];then
      info "删除当前存在的ci-cd.yaml文件"
      rm -rf "${gBuildPath:?}/${gCiCdYamlFileName}"
    fi

  else
    if [[ "${gBuildPath}" =~ ^(\.\/[a-zA-Z_]+) ]];then
      error "本地构建项目时，主模块路径（gBuildPath）必须是绝对路径"
    fi

    info "检测项目是否是多模块项目,并确定项目的构建根目录"
    if [[ "${gBuildPath}" =~ ^(.*)\/$ ]];then
      #以/结尾，表示单模块工程。
      gMultipleModelProject="false"
      gBuildPath="${gBuildPath%/*}"
      info "--->当前项目是单模块项目"
    else
      #不是以/结尾，表示多模块工程。
      gMultipleModelProject="true"
      info "--->当前项目是多模块项目"
    fi

    #本地模式下，读取git提交随机码
    if [ ! "${gGitHash}" ];then
      l_value=$(git log -n 1 2>&1)
      if [[ ${l_value} && ! ${l_value} =~ ^(fatal:)  ]];then
        # shellcheck disable=SC2206
        l_array=(${l_value})
        gGitHash=${l_array[1]}
        info "--->获取git提交随机码(gGitHash):${gGitHash}"
      else
        warn "--->获取git提交随机码失败：执行命令失败(git log -n 1)"
      fi
    fi

  fi
}

function _initGlobalParams() {
  export gWorkMode
  export gBuildPath
  export gLanguage

  export gCiCdTemplateFileName
  export gCiCdConfigYamlFileName

  export gCiCdYamlFileName
  export gCiCdYamlFile

  export gBuildScriptRootDir
  export gDockerTemplateDir

  export gBuildType

  local l_templateFile
  local l_ciCdConfigFile
  local l_tmpCiCdConfigFile

  #项目本地_ci-cd-template.yaml文件。
  l_templateFile="${gBuildPath}/_${gCiCdTemplateFileName}"

  #获取ci-cd.yaml文件的绝对路径。
  gCiCdYamlFile="${gBuildPath}/${gCiCdYamlFileName}"

  #判断项目中是否存在ci-cd.yaml配置文件？
  if [ ! -f "${gCiCdYamlFile}" ];then
    #如果不存在，则复制语言级公共模板(_ci-cd-template.yaml)创建一个项目级的_ci-cd-template.yaml文件。
    info "未检测到自定义模板文件，使用默认的_${gCiCdTemplateFileName}模板文件 ..."
    invokeExtendPointFunc "createCiCdTemplateFile" "创建_ci-cd-template.yaml配置文件" "${l_templateFile}"

    info "获取项目级_ci-cd-config.yaml配置文件 ..."
    l_tmpCiCdConfigFile="${gBuildPath}/_${gCiCdConfigYamlFileName}"
    #尝试复制语言级_ci-cd-config.yaml创建一个项目级的_ci-cd-config.yaml
    #注意：语言级_ci-cd-config.yaml模板文件中对大部分的参数都配置了默认值。
    #如果不存在语言级_ci-cd-config.yaml文件，则直接返回。后续直接将l_ciCdConfigFile文件的内容合并到l_templateFile文件，
    invokeExtendPointFunc "createCiCdConfigFile" "获取_ci-cd-config.yaml配置文件" "${l_templateFile}" "${l_tmpCiCdConfigFile}"

    #根据参数映射文件中的配置，初始化_ci-cd-config.yaml文件。
    #如果_ci-cd-config.yaml文件不存在，则直接初始化l_templateFile文件。
    invokeExtendPointFunc "initialCiCdConfigFileByParamMappingFiles" "获取_ci-cd-config.yaml配置文件" "${l_templateFile}" "${l_tmpCiCdConfigFile}"

    #继续判断项目中是否存在ci-cd-config.yaml配置文件？
    #注意:项目中配置的ci-cd-config.yaml文件内容可能只是_ci-cd-config.yaml文件的子集。
    l_ciCdConfigFile="${gBuildPath}/${gCiCdConfigYamlFileName}"
    if [ -f  "${l_ciCdConfigFile}" ];then
      info "检测到项目中存在ci-cd-config.yaml配置文件"
      if [ -f "${l_tmpCiCdConfigFile}" ];then
        info "检测到系统中配置有${gLanguage}语言级_ci-cd-config.yaml配置文件"
        info "先将ci-cd-config.yaml文件内容合并到_ci-cd-config.yaml文件中"
        combine "${l_ciCdConfigFile}" "${l_tmpCiCdConfigFile}" "" "" "true" "true" "true"
        echo -e "\n"
        info "再将_ci-cd-config.yaml文件内容合并到_ci-cd-template.yaml文件中"
        combine "${l_tmpCiCdConfigFile}" "${l_templateFile}" "" "" "true" "true"
      else
        warn "系统中未检测到${gLanguage}语言级_ci-cd-config.yaml配置文件"
        info "直接将ci-cd-config.yaml配置文件的内容合并到_ci-cd-template.yaml文件中"
        combine "${l_ciCdConfigFile}" "${l_templateFile}" "" "" "true" "true"
      fi
    elif [ -f "${l_tmpCiCdConfigFile}" ];then
      info "检测到系统中配置有${gLanguage}语言级_ci-cd-config.yaml配置文件"
      info "直接将_ci-cd-config.yaml配置文件的内容合并到_ci-cd-template.yaml文件中"
      combine "${l_tmpCiCdConfigFile}" "${l_templateFile}" "" "" "true" "true"
    fi
    #删除临时文件
    rm -f "${l_tmpCiCdConfigFile}" || true

    info "从_ci-cd-template.yaml文件创建ci-cd.yaml文件"
    #将ci-cd-template.yaml文件更名为ci-cd.yaml文件中。
    cat "${l_templateFile}" > "${gCiCdYamlFile}"

    #删除临时文件
    rm -f "${l_templateFile}" || true

    #调用：替换变量引用前扩展点。
    invokeExtendPointFunc "onBeforeReplaceParamPlaceholder" "ci-cd.yaml文件中变量引用处理前" "${gCiCdYamlFile}"
    #调用：替换变量引用扩展点。
    invokeExtendPointFunc "replaceParamPlaceholder" "处理ci-cd.yaml文件中变量引用" "${gCiCdYamlFile}"
    #调用：替换变量引用后扩展点。
    invokeExtendPointFunc "onAfterReplaceParamPlaceholder" "ci-cd.yaml文件中变量引用处理后" "${gCiCdYamlFile}"

  fi

  info "从ci-cd.yaml文件中统一读取全局配置参数..."
  _loadGlobalParamsFromCiCdYaml "${gCiCdYamlFile}"

  gDockerTemplateDir="${gBuildScriptRootDir}/templates/docker"
  info "初始化docker模板文件的路径:${gDockerTemplateDir}"

  #清理并创建需要的全局目录
  _createGlobalDirectory
}

function _createGlobalDirectory() {
  export gBuildPath
  export gHelmBuildDirName
  export gHelmBuildDir
  export gHelmBuildOutDirName
  export gHelmBuildOutDir
  export gDockerBuildDirName
  export gDockerBuildDir
  export gChartBuildDirName
  export gChartBuildDir
  export gTempFileDirName
  export gTempFileDir
  export gProjectShellDirName
  export gProjectShellDir
  export gProjectChartTemplatesDir
  export gProjectPluginDirName
  export gProjectPluginDir
  export gParamMappingDirName
  export gParamMappingDir
  export gProjectTemplateDirName
  export gProjectTemplateDir
  export gProjectDockerTemplateDirName
  export gProjectDockerTemplateDir

  gHelmBuildDir="${gBuildPath}/${gHelmBuildDirName}"
  if [[ ! -d "${gHelmBuildDir}" ]];then
    info "初始化构建主目录:${gHelmBuildDir}"
    mkdir -p "${gHelmBuildDir}"
  fi

  gHelmBuildOutDir="${gHelmBuildDir}/${gHelmBuildOutDirName}"
  if [[ ! -d "${gHelmBuildOutDir}" ]];then
    info "初始化构建输出目录:${gHelmBuildOutDir}"
    mkdir -p "${gHelmBuildOutDir}"
  fi

  gDockerBuildDir="${gHelmBuildDir}/${gDockerBuildDirName}"
  if [[ -d "${gDockerBuildDir}" ]];then
    rm -rf "${gDockerBuildDir:?}"
  fi
  info "初始化docker镜像构建目录:${gDockerBuildDir}"
  mkdir -p "${gDockerBuildDir}"

  gChartBuildDir="${gHelmBuildDir}/${gChartBuildDirName}"
  if [[ -d "${gChartBuildDir}" ]];then
    rm -rf "${gChartBuildDir:?}"
  fi
  info "初始化chart镜像构建目录:${gChartBuildDir}"
  mkdir -p "${gChartBuildDir}"

  gTempFileDir="${gHelmBuildDir}/${gTempFileDirName}"
  if [ -d "${gTempFileDir}" ];then
    #如果不为空，则删除该临时目录。
    rm -rf "${gTempFileDir:?}"
  fi
  info "初始化临时文件存储目录:${gTempFileDir}"
  mkdir -p "${gTempFileDir}"

  gParamMappingDir=${gHelmBuildDir}/${gParamMappingDirName}
  if [ ! -d "${gTempFileDir}" ];then
    info "初始化项目参数映射配置文件存储目录:${gParamMappingDir}"
    mkdir -p "${gParamMappingDir}"
  fi

  gProjectShellDir="${gHelmBuildDir}/${gProjectShellDirName}"
  if [ ! -d "${gProjectShellDir}" ];then
    info "初始化项目级脚本文件存储目录:${gProjectShellDir}"
    mkdir -p "${gProjectShellDir}"
  fi

  gProjectPluginDir="${gHelmBuildDir}/${gProjectPluginDirName}"
  if [ ! -d "${gProjectPluginDir}" ];then
    info "初始化项目级资源生成器插件存储目录:${gProjectPluginDir}"
    mkdir -p "${gProjectPluginDir}"
  fi

 gProjectTemplateDir="${gHelmBuildDir}/${gProjectTemplateDirName}"
 if [ ! -d "${gProjectTemplateDir}" ];then
   info "初始化项目级模板文件存储目录:${gProjectTemplateDir}"
   mkdir -p "${gProjectTemplateDir}"
 fi

 gProjectDockerTemplateDir="${gProjectTemplateDir}/${gProjectDockerTemplateDirName}"
 if [ ! -d "${gProjectDockerTemplateDir}" ];then
   info "初始化项目级Dockerfile模板文件存储目录:${gProjectDockerTemplateDir}"
   mkdir -p "${gProjectDockerTemplateDir}"
 fi

}

function _checkGlobalDirectory() {
  export gBuildPath
  export gHelmBuildDirName
  export gHelmBuildDir
  export gHelmBuildOutDirName
  export gHelmBuildOutDir
  export gDockerBuildDirName
  export gDockerBuildDir
  export gChartBuildDirName
  export gChartBuildDir
  export gTempFileDirName
  export gTempFileDir
  export gProjectShellDirName
  export gProjectShellDir
  export gProjectChartTemplatesDir
  export gProjectPluginDirName
  export gProjectPluginDir
  export gParamMappingDirName
  export gParamMappingDir

  info "检查并创建缺失的全局目录..."

  gHelmBuildDir="${gBuildPath}/${gHelmBuildDirName}"
  if [[ ! -d "${gHelmBuildDir}" ]];then
    info "初始化构建主目录:${gHelmBuildDir}"
    mkdir -p "${gHelmBuildDir}"
  fi

  gHelmBuildOutDir="${gHelmBuildDir}/${gHelmBuildOutDirName}"
  if [[ ! -d "${gHelmBuildOutDir}" ]];then
    info "初始化构建输出目录:${gHelmBuildOutDir}"
    mkdir -p "${gHelmBuildOutDir}"
  fi

  gDockerBuildDir="${gHelmBuildDir}/${gDockerBuildDirName}"
  if [[ ! -d "${gDockerBuildDir}" ]];then
    info "初始化docker镜像构建目录:${gDockerBuildDir}"
    mkdir -p "${gDockerBuildDir}"
  else
    info "清空docker镜像构建目录"
    rm -rf "${gDockerBuildDir:?}/*"
  fi

  gChartBuildDir="${gHelmBuildDir}/${gChartBuildDirName}"
  if [[ ! -d "${gChartBuildDir}" ]];then
    info "初始化chart镜像构建目录:${gChartBuildDir}"
    mkdir -p "${gChartBuildDir}"
  else
    info "清空chart镜像构建目录"
    rm -rf "${gChartBuildDir:?}/*"
  fi

  gTempFileDir="${gHelmBuildDir}/${gTempFileDirName}"
  if [ ! -d "${gTempFileDir}" ];then
    info "初始化临时文件存储目录:${gTempFileDir}"
    mkdir -p "${gTempFileDir}"
  else
    info "清空临时文件存储目录"
    rm -rf "${gTempFileDir:?}/*"
  fi

  gParamMappingDir=${gHelmBuildDir}/${gParamMappingDirName}
  if [ ! -d "${gTempFileDir}" ];then
    info "初始化项目参数映射配置文件存储目录:${gParamMappingDir}"
    mkdir -p "${gParamMappingDir}"
  fi

  gProjectShellDir="${gHelmBuildDir}/${gProjectShellDirName}"
  if [ ! -d "${gProjectShellDir}" ];then
    info "初始化项目级脚本文件存储目录:${gProjectShellDir}"
    mkdir -p "${gProjectShellDir}"
  fi

  gProjectPluginDir="${gHelmBuildDir}/${gProjectPluginDirName}"
  if [ ! -d "${gProjectPluginDir}" ];then
    info "初始化项目级资源生成器插件存储目录:${gProjectPluginDir}"
    mkdir -p "${gProjectPluginDir}"
  fi

   gProjectTemplateDir="${gHelmBuildDir}/${gProjectTemplateDirName}"
   if [ ! -d "${gProjectTemplateDir}" ];then
     info "初始化项目级模板文件存储目录:${gProjectTemplateDir}"
     mkdir -p "${gProjectTemplateDir}"
   fi

   gProjectDockerTemplateDir="${gProjectTemplateDir}/${gProjectDockerTemplateDirName}"
   if [ ! -d "${gProjectDockerTemplateDir}" ];then
     info "初始化项目级Dockerfile模板文件存储目录:${gProjectDockerTemplateDir}"
     mkdir -p "${gProjectDockerTemplateDir}"
   fi
}

function _onAfterInitGlobalParams(){
  export gReleaseNotePath
  export gReleaseNoteFileName
  export gUpdateNote

  local l_releaseNotes
  local l_releaseNote

  debug "1.读取項目更新历史文件中最新内容"
  if [ "${gReleaseNotePath}" ];then
    #读取項目更新历史文件中最新内容。
    l_releaseNotes=$(find "${gReleaseNotePath}" -type f -name "${gReleaseNoteFileName}")
    if [ "${l_releaseNotes}" ];then
      # shellcheck disable=SC2068
      for l_releaseNote in ${l_releaseNotes[@]}
      do
        #仅读取文件中第一个空行前的内容。
        gUpdateNote=$(awk 'BEGIN{RS="\n\n"} {print} {exit}' "${l_releaseNote}")
        if [ ! "${gUpdateNote}" ];then
          warn "項目更新历史文件是空文件，或者第一个空行前没有有效内容"
        fi
        break
      done
    else
      warn "項目更新历史文件${gReleaseNoteFileName}不存在"
    fi
  else
    warn "項目更新历史文件存放目录参数(gReleaseNotePath)未配置"
  fi
}

function _loadJenkinsGlobalParams() {
  local l_value

  #构建脚本根目录。
  export gBuildScriptRootDir="${BUILD_SCRIPT_ROOT}"
  if [ ! "${gBuildScriptRootDir}" ];then
    error "未指定构建脚本根目录(BUILD_SCRIPT_ROOT)"
  fi
  info "--->设置gBuildScriptRootDir=\${BUILD_SCRIPT_ROOT}"

  export gGitProjectName="${GIT_PROJECT_NAME}"
  if [ ! "${gGitProjectName}" ];then
    error "未指定需要构建的Git项目名称(GIT_PROJECT_NAME)"
  fi
  info "--->设置gGitProjectName=\${GIT_PROJECT_NAME}"

  export gBuildPath="${BUILD_PATH}"
  if [ ! "${gBuildPath}" ];then
    error "未指定项目构建的根目录(BUILD_PATH)"
  fi
  info "--->设置gBuildPath=\${BUILD_PATH}"

  #解析Docker镜像仓库
  parseDockerRepoInfo "${DOCKER_REPO_INFO}"

  if [ ! "${gDockerRepoType}" ];then
    error "未配置Docker镜像仓库类型(nexus或harbor)(DOCKER_REPO_TYPE)"
  fi
  info "--->gDockerRepoType=\${DOCKER_REPO_TYPE}"

  if [ ! "${gDockerRepoInstanceName}" ];then
    error "未配置Docker镜像仓库实例名称(nexus)或项目名称(harbor)(DOCKER_REPO_INSTANCE_NAME)"
  fi
  info "--->gDockerRepoInstanceName=\${DOCKER_REPO_INSTANCE_NAME}"

  if [ ! "${gDockerRepoName}" ];then
    error "未配置Docker镜像仓库名称(DOCKER_REPO_NAME)"
  fi
  info "--->设置gDockerRepoName=\${DOCKER_REPO_NAME}"

  if [ ! "${gDockerRepoAccount}" ];then
    error "未配置Docker镜像仓库登录账号(DOCKER_REPO_ACCOUNT)"
  fi
  info "--->设置gDockerRepoAccount=\${DOCKER_REPO_ACCOUNT}"

  if [ ! "${gDockerRepoPassword}" ];then
    error "未配置Docker镜像仓库登录密码(DOCKER_REPO_PASSWORD)"
  fi
  info "--->设置gDockerRepoPassword=\${DOCKER_REPO_PASSWORD}"

  if [ ! "${gDockerRepoWebPort}" ];then
    error "未配置Docker镜像仓Web管理端口(DOCKER_REPO_WEB_PORT)"
  fi
  info "--->gDockerRepoWebPort=\${DOCKER_REPO_WEB_PORT}"

  #解析Chart镜像仓库
  parseChartRepoInfo "${CHART_REPO_INFO}"

  if [ ! "${gChartRepoType}" ];then
    error "未配置Chart镜像仓库类型(nexus或harbor)(CHART_REPO_TYPE)"
  fi
  info "--->gChartRepoType=\${CHART_REPO_TYPE}"

  if [ ! "${gChartRepoInstanceName}" ];then
    error "未配置Docker镜像仓库实例名称(nexus)或项目名称(harbor)(CHART_REPO_INSTANCE_NAME)"
  fi
  info "--->gChartRepoInstanceName=\${CHART_REPO_INSTANCE_NAME}"

  if [ ! "${gChartRepoName}" ];then
    error "未配置Chart镜像仓库名称(CHART_REPO_NAME)"
  fi
  info "--->设置gChartRepoName=\${CHART_REPO_NAME}"

  if [ ! "${gChartRepoAccount}" ];then
    error "未配置Chart镜像仓库登录账号(CHART_REPO_ACCOUNT)"
  fi
  info "--->设置gChartRepoAccount=\${CHART_REPO_ACCOUNT}"

  if [ ! "${gChartRepoPassword}" ];then
    error "未配置Chart镜像仓库登录密码(CHART_REPO_PASSWORD)"
  fi
  info "--->设置gChartRepoPassword=\${CHART_REPO_PASSWORD}"

  if [ ! "${gChartRepoWebPort}" ];then
    error "未配置Chart镜像仓库Web管理端口(CHART_REPO_WEB_PORT)"
  fi
  info "--->gChartRepoWebPort=\${CHART_REPO_WEB_PORT}"

  export gExternalNotifyUrl="${EXTERNAL_NOTIFY_URL}"
  if [ ! "${gExternalNotifyUrl}" ];then
    warn "未配置发布管理平台构建进度通知接口URL(EXTERNAL_NOTIFY_URL)"
  else
    info "--->设置gExternalNotifyUrl=\${EXTERNAL_NOTIFY_URL}"
  fi

  export gUpdateNotifyUrl="${DEPLOY_NOTIFY_URL}"
  if [ ! "${gUpdateNotifyUrl}" ];then
    warn "未配置发布管理平台构建结果通知接口URL(DEPLOY_NOTIFY_URL)"
  else
    info "--->设置gUpdateNotifyUrl=\${DEPLOY_NOTIFY_URL}"
  fi

  l_value="${DEPLOY_TARGET_NODES}"
  if [ ! "${l_value}" ];then
    warn "未配置部署服务的目标节点服务器(DEPLOY_TARGET_NODES)"
  else
    info "--->设置gDeployTargetNodes=\${DEPLOY_TARGET_NODES}"
    # shellcheck disable=SC2206
    export gDeployTargetNodes=(${l_value//,/ })
  fi

  export gGitHash="${GIT_COMMIT}"
  export gJenkinsBuildNumber="${BUILD_NUMBER}"
  export gWorkSpace="${WORKSPACE}"
  export gGitBranch="${GIT_BRANCH}"

}

#读取yaml文件中templates配置节的参数值，替换读取位置之后的出现的同名参数引用。
function _replaceParamPlaceholder() {
  export gDefaultRetVal

  local l_cicdYaml=$1

  local l_lines
  local l_line
  local l_arrayLen
  local l_i
  local l_paramName
  local l_paramValue
  local l_paramValue1

  local l_paramRef
  local l_refItems
  local l_itemCount
  local l_j
  local l_refItem

  #定一个Map类型变量
  declare -A l_rowDataMap

  readParam "${l_cicdYaml}" "globalParams"
  l_content="${gDefaultRetVal}"
  stringToArray "${l_content}" "l_lines"

  # shellcheck disable=SC2154
  l_content="${gFileContentMap[${l_cicdYaml}]}"

  l_arrayLen="${#l_lines[@]}"
  for (( l_i = 0; l_i < l_arrayLen; l_i++ )); do
    l_line="${l_lines[${l_i}]}"
    #如果是空行或注释行，则跳过该行
    if [[ ! "${l_line}"  || "${l_line}" =~ ^([ ]*|^([ ]*)#(.*))$ ]];then
      continue
    fi
    l_paramName="${l_line%%:*}"
    l_paramValue="${l_line#*:}"
    #删除头尾空格
    l_paramValue=$(echo -e "${l_paramValue}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    #保留参数值中的引号
    l_paramValue="${l_paramValue//\\\"/\\\\\"}"
    #保留参数值中的“/”符号
    l_paramValue="${l_paramValue//\//\\/}"
    #保留参数值中的“-”符号
    l_paramValue="${l_paramValue//\-/\\-}"

    if [[ "${l_paramValue}" =~ ^(.*)\$\{(.*)$ ]];then
      l_paramRef=$(echo -e "${l_paramValue}" | grep -oP "\\$\\{[a-zA-Z0-9_\\-]+\\}")
      stringToArray "${l_paramRef}" "l_refItems"
      l_itemCount="${#l_refItems[@]}"
      for (( l_j = 0; l_j < l_itemCount; l_j++ )); do
        #获取参数${param},并删除前后的大括号。
        l_refItem="${l_refItems[${l_j}]}"
        l_refItem="${l_refItem#*{}"
        l_refItem="${l_refItem%\}*}"
        #得到引用的参数值。
        l_paramRef="${l_rowDataMap[${l_refItem}]}"
        #删除参数值的头尾空格
        l_paramRef=$(echo -e "${l_paramRef}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        l_paramValue="${l_paramValue//\$\{${l_refItem}\}/${l_paramRef}}"
      done
    fi
    l_rowDataMap["${l_paramName}"]="${l_paramValue}"
    info "---将${l_paramName}替换为${l_paramValue}"
    #替换文件中的占位符。
    l_content=$(echo -e "${l_content}" | sed "s/\\\${${l_paramName}}/${l_paramValue}/g")
  done

  #替换文件中的\“"为\",”\“替换为\“
  l_content=$(echo -e "${l_content}" | sed 's/\\\"\"/\\\"/g' | sed 's/\"\\\"/\\\"/g')

  #更新缓存内容。
  gFileContentMap["${l_cicdYaml}"]="${l_content}"
  #将内容回写到文件中。
  clearCachedFileContent "${l_cicdYaml}"

  # shellcheck disable=SC2002
  l_lines=$(echo -e "${l_content}" | grep -oP "\\\$\{[a-zA-Z0-9_\-]+\}" | sort | uniq -c)
  if [ "${lines}" ];then
    error "ci-cd.yaml文件中存在未明确配置的参数:\n${lines}"
  fi

}

#从ci-cd.yaml文件初始化全局变量的值。
function _loadGlobalParamsFromCiCdYaml() {
  local l_cicdYaml=$1

  #yaml-help.sh文件中定义的函数默认返回值变量。
  export gDefaultRetVal

  #以下3个配置参数以命令行输入值为最高优先级的配置值。
  export gUseTemplate
  export gRuntimeVersion
  export gBuildType
  export gArchTypes
  export gOfflineArchTypes
  export gValidBuildStages

  #以下4个配置参数以ci-cid.yaml文件中的内容为最高优先级的配置值。
  export gRollback
  export gTargetNamespace
  export gTargetGatewayHosts
  export gServiceName

  if [ ! "${gRuntimeVersion}" ];then
    #初始化gRuntimeVersion参数。
    readParam "${l_cicdYaml}" "globalParams.runtimeVersion"
    gRuntimeVersion="${gDefaultRetVal}"
  fi
  info "gRuntimeVersion参数高优先配置值为：${gRuntimeVersion}"

  if [ ! "${gBuildType}" ];then
    #初始化gBuildType参数。
    readParam "${l_cicdYaml}" "globalParams.buildType"
    gBuildType="${gDefaultRetVal}"
  fi
  info "gBuildType参数高优先配置值为：${gBuildType}"

  if [ ! "${gArchTypes}" ];then
    #初始化gArchTypes参数。
    readParam "${l_cicdYaml}" "globalParams.archTypes"
    if [ "${gDefaultRetVal}" != "null" ];then
      gArchTypes="${gDefaultRetVal}"
    else
      gArchTypes="linux/amd64,linux/arm64"
    fi
  fi
  info "gArchTypes参数高优先配置值为：${gArchTypes}"

  if [ ! "${gOfflineArchTypes}" ];then
    #初始化gOfflineArchTypes参数。
    readParam "${l_cicdYaml}" "globalParams.offlineArchTypes"
    if [ "${gDefaultRetVal}" != "null" ];then
      gOfflineArchTypes="${gDefaultRetVal}"
    else
      gOfflineArchTypes="linux/amd64,linux/arm64"
    fi
  fi
  info "gOfflineArchTypes参数高优先配置值为：${gOfflineArchTypes}"

  if [ ! "${gUseTemplate}" ];then
    #初始化gUseTemplate参数。
    readParam "${l_cicdYaml}" "globalParams.useTemplate"
    if [ "${gDefaultRetVal}" != "null" ];then
      gUseTemplate="${gDefaultRetVal}"
    else
      gUseTemplate="false"
    fi
  fi
  info "gUseTemplate参数高优先配置值为：${gUseTemplate}"

  if [ ! "${gValidBuildStages}" ];then
    readParam "${l_cicdYaml}" "globalParams.validBuildStages"
    if [ "${gDefaultRetVal}" != "null" ];then
      gValidBuildStages="${gDefaultRetVal}"
    else
      gValidBuildStages="all"
    fi
  fi
  info "gValidBuildStages参数高优先配置值为：${gValidBuildStages}"

  #初始化gRollback参数。
  readParam "${l_cicdYaml}" "globalParams.rollback"
  if [ "${gDefaultRetVal}" == "false" ];then
    gRollback="false"
  else
    gRollback="true"
  fi
  info "gRollback:从配置文件中读取配置值(${gRollback})"

  #初始化gTargetNamespace参数。
  readParam "${l_cicdYaml}" "globalParams.targetNamespace"
  if [ "${gDefaultRetVal}" != "null" ];then
    gTargetNamespace="${gDefaultRetVal}"
  else
    gTargetNamespace="default"
  fi
  info "gTargetNamespace:从配置文件中读取配置值(${gTargetNamespace})"

  #初始化gTargetGatewayHosts参数。
  readParam "${l_cicdYaml}" "globalParams.gatewayHost"
  if [ "${gDefaultRetVal}" != "null" ];then
    gTargetGatewayHosts="${gDefaultRetVal}"
  else
    gTargetGatewayHosts=""
  fi
  info "gTargetGatewayHosts:从配置文件中读取配置值(${gTargetGatewayHosts})"

  #初始化gServiceName参数。
  readParam "${l_cicdYaml}" "globalParams.serviceName"
  if [ "${gDefaultRetVal}" == "null" ];then
    error "${l_cicdYaml}文件中globalParams.serviceName参数不能为空"
  fi
  gServiceName="${gDefaultRetVal}"
  info "gServiceName:从配置文件中读取配置值(${gServiceName})"
}

#------------------------私有方法--结束-------------------------#

#加载语言级脚本扩展文件
loadExtendScriptFileForLanguage "wydevops"
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

function clearDeprecatedFiles_ex(){
  export gHelmBuildOutDir
  export gArchTypes

  local l_array
  local l_archType

  # shellcheck disable=SC2206
  l_array=(${gArchTypes//,/ })
  # shellcheck disable=SC2068
  for l_archType in ${l_array[@]};do
    info "wydevops.sh.delete.pushed.images.file" "${gHelmBuildOutDir}#${l_archType//\//-}"
    rm -f "${gHelmBuildOutDir}/${l_archType//\//-}/pushed-images.yaml"
  done
}

function onBeforeReplaceParamPlaceholder_ex() {
  export gBuildType
  export gDockerImageNameWithInstance
  export gDockerRepoInstanceName
  export gDockerRepoType

  local l_cicdYaml=$1
  local l_placeholders
  local l_placeholder
  local l_tmpVersion

  readParam "${l_cicdYaml}" "globalParams.businessVersion"
  if [[ "${gDefaultRetVal}" != "null" ]];then
    l_tmpVersion="${gDefaultRetVal,,}"
    #如果版本号包含大写字母，则转换为小写
    if [[ "${l_tmpVersion}" != "${gDefaultRetVal}" ]];then
      #回写小写的版本号。
      updateParam "${l_cicdYaml}" "globalParams.businessVersion" "${l_tmpVersion}"
    fi
    #回写版本后缀参数
    l_tmpVersion="${l_tmpVersion//./-}"
    updateParam "${l_cicdYaml}" "globalParams.versionSuffix" "${l_tmpVersion}"
  fi

  readParam "${l_cicdYaml}" "globalParams.gatewayPath"
  if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "/" ]];then
    updateParam "${l_cicdYaml}" "globalParams.enableRewrite" "false"
    updateParam "${l_cicdYaml}" "globalParams.apisixRouteRegexUri" "[]"
    updateParam "${l_cicdYaml}" "globalParams.apisixIngressTargetRegex" ""
    info "common.wydevops.extend.point.gateway.rewrite.disabled"
  else
    updateParam "${l_cicdYaml}" "globalParams.enableRewrite" "true"
    updateParam "${l_cicdYaml}" "globalParams.apisixRouteRegexUri" "[ \"^\${gatewayPath}(?:/|$)(.*)\", \"/\$1\" ]"
    updateParam "${l_cicdYaml}" "globalParams.apisixIngressTargetRegex" "^\${gatewayPath}(?:/|$)/(.*)"
    info "common.wydevops.extend.point.gateway.rewrite.enabled"
  fi

  #为业务镜像和基础镜像添加项目名称前缀。
  #if [[ "${gDockerRepoType}" == "harbor" || ("${gDockerRepoInstanceName}" && "${gDockerImageNameWithInstance}" == "true") ]];then
  if [[ "${gDockerRepoType}" == "harbor" ]];then
    info "common.wydevops.extend.point.adding.repo.prefix"
    readParam "${l_cicdYaml}" "globalParams.businessImage"
    info "common.wydevops.extend.point.updating.param.value" "globalParams.businessImage#${gDockerRepoInstanceName}/${gDefaultRetVal}"
    updateParam "${l_cicdYaml}" "globalParams.businessImage" "${gDockerRepoInstanceName}/${gDefaultRetVal}"

    readParam "${l_cicdYaml}" "globalParams.baseImage"
    info "common.wydevops.extend.point.updating.param.value" "globalParams.baseImage#${gDockerRepoInstanceName}/${gDefaultRetVal}"
    updateParam "${l_cicdYaml}" "globalParams.baseImage" "${gDockerRepoInstanceName}/${gDefaultRetVal}"
  fi

  info "common.wydevops.extend.point.adding.suffix.to.baseworkdir"
  l_paramName="globalParams.baseWorkDir"
  readParam "${l_cicdYaml}" "${l_paramName}"
  [[ "${gDefaultRetVal}" == "null" ]] && error "common.wydevops.extend.point.param.missing" "${l_cicdYaml##*/}#${l_paramName}"

  l_paramValue="${gDefaultRetVal}-double"
  [[ "${gBuildType}" == "single" ]] && l_paramValue="${gDefaultRetVal}-single"

  insertParam "${l_cicdYaml}" "${l_paramName}" "${l_paramValue}"
  if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
    error "common.wydevops.extend.point.update.param.failed" "${l_cicdYaml##*/}#${l_paramName}"
  else
    info "common.wydevops.extend.point.update.param.success" "${l_cicdYaml##*/}#${l_paramName}#${l_paramValue}"
  fi

  info "common.wydevops.extend.point.writing.cli.params.to.config"
  if [ "${gBuildType}" ];then
    info "common.wydevops.extend.point.updating.param.value" "globalParams.buildType#${gBuildType}"
    #初始化gBuildType参数。
    updateParam "${l_cicdYaml}" "globalParams.buildType" "${gBuildType}"
  fi

  if [ "${gArchTypes}" ];then
    info "common.wydevops.extend.point.updating.param.value" "globalParams.archTypes#${gArchTypes}"
    updateParam "${l_cicdYaml}" "globalParams.archTypes" "${gArchTypes}"
  fi

  if [ "${gOfflineArchTypes}" ];then
    info "common.wydevops.extend.point.updating.param.value" "globalParams.offlineArchTypes#${gOfflineArchTypes}"
    updateParam "${l_cicdYaml}" "globalParams.offlineArchTypes" "${gOfflineArchTypes}"
  fi

  if [ "${gUseTemplate}" ];then
    info "common.wydevops.extend.point.updating.param.value" "globalParams.useTemplate#${gUseTemplate}"
    updateParam "${l_cicdYaml}" "globalParams.useTemplate" "${gUseTemplate}"
  fi

  if [ "${gValidBuildStages}" ];then
    info "common.wydevops.extend.point.updating.param.value" "globalParams.validBuildStages#${gValidBuildStages}"
    updateParam "${l_cicdYaml}" "globalParams.validBuildStages" "${gValidBuildStages}"
  fi

  #检查文件中是否存在未定义好的占位符号。
  # shellcheck disable=SC2002
  #l_placeholders=$(cat "${l_cicdYaml}" | grep -oP "^([ ]*[a-zA-Z_\-]+)" |grep -oP "_([A-Z]?[A-Z0-9\-]+)_" | sort | uniq -c)
  l_placeholders=$(grep -E '^[^#]' <<< "${l_cicdYaml}" | grep -oP "(?<![A-Za-z0-9])_[A-Z0-9\-]+_(?![A-Za-z0-9])" | sort | uniq -c)
  # shellcheck disable=SC2068
  for l_placeholder in ${l_placeholders[@]};do
    if [[ "${l_placeholder}" =~ ^_[A-Z0-9\-]+_$ ]];then
      warn "common.wydevops.extend.point.placeholder.not.defined" "${l_cicdYaml}#${l_placeholder}"
    fi
  done

  if [ "${l_placeholders}" ];then
    error "common.wydevops.extend.point.undefined.placeholders.exist" "${l_cicdYaml}"
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
  export gRuntimeVersion

  local l_cicdTemplateFile=$1

  local l_runtimeVersion
  local l_templateFile

  l_runtimeVersion=""
  [[ "${gRuntimeVersion}" ]] && l_runtimeVersion="${gRuntimeVersion}/"

  l_templateFile="${gBuildPath}/${gHelmBuildDirName}/templates/config/_${gCiCdTemplateFileName}"
  if [ -f "${l_templateFile}" ];then
    info "common.wydevops.extend.point.copying.project.template" "${l_cicdTemplateFile##*/}"
  else
    l_templateFile="${gBuildScriptRootDir}/templates/config/${gLanguage}/${l_runtimeVersion}_${gCiCdTemplateFileName}"
    if [ -f "${l_templateFile}" ];then
      info "common.wydevops.extend.point.copying.language.template" "${l_cicdTemplateFile##*/}"
    else
      l_templateFile="${gBuildScriptRootDir}/templates/config/_ci-cd-template.yaml"
      info "common.wydevops.extend.point.copying.common.template" "${l_cicdTemplateFile##*/}"
    fi
  fi

  if [ ! -f "${l_templateFile}" ];then
    error "common.wydevops.extend.point.template.not.found"
  fi

  cat "${l_templateFile}" > "${l_cicdTemplateFile}"
}

#先尝试复制语言级_ci-cd-config.yaml创建一个项目级的_ci-cd-config.yaml
#如果不存在语言级_ci-cd-config.yaml文件，
#则依据_ci-cd-template.yaml文件创建项目级的_ci-cd-config.yaml
function createCiCdConfigFile_ex() {
  export gBuildScriptRootDir
  export gLanguage
  export gRuntimeVersion

  local l_cicdTemplateFile=$1
  #需要创建的目标文件。
  local l_cicdConfigFile=$2

  local l_runtimeVersion
  #语言级_ci-cd-config.yaml的全路径名称。
  local l_tmpCicdConfigFile
  local l_content
  local l_itemCount
  local l_i

  l_runtimeVersion=""
  [[ "${gRuntimeVersion}" ]] && l_runtimeVersion="${gRuntimeVersion}/"

  l_tmpCicdConfigFile="${gBuildScriptRootDir}/templates/config/${gLanguage}/${l_runtimeVersion}_ci-cd-config.yaml"
  if [ -f "${l_tmpCicdConfigFile}" ];then
    info "common.wydevops.extend.point.copying.language.config.template" "${gLanguage}"
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
  export gRuntimeVersion

  local l_templateFile=$1
  local l_tmpCiCdConfigFile=$2

  local l_cicdTargetFile

  local l_runtimeVersion
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

  local _orderedKeys

  #文件及其已经处理过的参数Map。
  # shellcheck disable=SC2034
  declare -A _alreadyProcessedParamMap
  #configMapName与其内的文件Map
  declare -A configMapNameAndFilesMap

  l_cicdTargetFile="${l_tmpCiCdConfigFile}"
  [[ ! -f "${l_tmpCiCdConfigFile}" ]] && l_cicdTargetFile="${l_templateFile}"

  l_runtimeVersion=""
  [[ "${gRuntimeVersion}" ]] && l_runtimeVersion="${gRuntimeVersion}/"

  #项目级参数应用文件优先级更高，放置_dirList中最前面的位置。
  l_dirList=("${gBuildPath}/${gHelmBuildDirName}/templates/config/${gLanguage}/${gParamMappingDirName}" "${gBuildScriptRootDir}/templates/config/${gLanguage}/${l_runtimeVersion}${gParamMappingDirName}")
  #预先定义好各个参数映射文件对应的

  l_loadOk="false"
  # shellcheck disable=SC2068
  for l_mappingFileDir in ${l_dirList[@]};do
    #读取参数映射目录中的配置文件。
    if [ -d "${l_mappingFileDir}" ];then
      l_paramMappingFiles=$(find "${l_mappingFileDir}" -maxdepth 1 -type f -name "*.config")
      if [ "${l_paramMappingFiles}" ];then
        # shellcheck disable=SC2068
        _orderedKeys=""
        for l_mappingFile in ${l_paramMappingFiles[@]};do
          declare -A _paramMappingMap
          #将参数映射文件中的配置读取到_paramMappingMap变量中。
          initialMapFromConfigFile "${l_mappingFile}" "_paramMappingMap" "_orderedKeys"

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
            invokeExtendPointFunc "onLoadMatchedAdditionalConfigFiles" "common.wydevops.extend.point.getting.env.config.files" "" "${l_array[1]//\"/}"
            if [ "${gDefaultRetVal}" ] && [ "${gDefaultRetVal}" != "null" ];then
              l_array[1]="${gDefaultRetVal},${l_array[1]//\"/}"
              l_configMapFiles="${gDefaultRetVal},${l_configMapFiles:1}"
            fi

            if [ "${#_paramMappingMap[@]}" -gt 0 ];then
              info "common.wydevops.extend.point.init.param.by.mapping.config.files" "${l_array[1]}#${l_cicdTargetFile}"
              initialParamValueByMappingConfigFiles "${gBuildPath}" "${l_cicdTargetFile}" \
                "_orderedKeys|_paramMappingMap|${l_array[0]}" "${l_array[1]}" "_alreadyProcessedParamMap"
              l_loadOk="true"
            fi
          fi
          unset _paramMappingMap
        done
      fi
    fi
  done

  if [ "${l_loadOk}" == "false" ];then
    invokeExtendPointFunc "onFailToLoadingParamMappingFiles" "common.wydevops.extend.point.fail.to.load.mapping.files" "" "${l_array[1]}"
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
        info "common.wydevops.extend.point.init.configmap.files" "${l_cicdTargetFile##*/}#${l_mapValue:1}"
        insertParam "${l_cicdTargetFile}" "globalParams.configMapFiles" "${l_mapValue:1}"
      else
        info "common.wydevops.extend.point.init.deployment.configmap.files" "${l_cicdTargetFile##*/}#chart[0].deployments[0].configMaps[${l_index}].files#${l_mapValue:1}"
        l_content="name: ${l_mapKey}\nfiles: ${l_mapValue:1}"
        insertParam "${l_cicdTargetFile}" "chart[0].deployments[0].configMaps[${l_index}]" "${l_content}"
        ((l_index = l_index + 1))
      fi
    done
  fi

}

function checkMultipleModelProjectInJenkins_ex(){
  export gBuildPath
  export gMultipleModelProject

  #修正构建项目根路径。
  if [[ "${gBuildPath}" =~ ^(\.\/[a-zA-Z]+) ]];then
    #将gBuildPath赋值为绝对路径。
    gBuildPath="${gWorkSpace}/${gGitProjectName}/${gBuildPath:2}"
    #多模块工程在build时会回退到上级目录执行build。
    gMultipleModelProject="true"
  elif [[ "${gBuildPath}" =~ ^(\.\/) ]];then
    #将gBuildPath赋值为绝对路径。
    gBuildPath="${gWorkSpace}/${gGitProjectName}"
    gMultipleModelProject="false"
  fi
}

function checkMultipleModelProjectInLocal_ex(){
  export gBuildPath
  export gMultipleModelProject

  if [[ "${gBuildPath}" =~ ^(.*)\/$ ]];then
    #以/结尾，表示单模块工程。
    gMultipleModelProject="false"
    gBuildPath="${gBuildPath%/*}"
  else
    #不是以/结尾，表示多模块工程。
    gMultipleModelProject="true"
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
    error "common.wydevops.extend.point.unspecified.work.mode"
  fi

  if [ ! "${gLanguage}" ];then
    error "common.wydevops.extend.point.unspecified.language"
  fi

  if [ "${gWorkMode}" == "jenkins" ];then
    info "common.wydevops.extend.point.init.from.jenkins.params"
    _loadJenkinsGlobalParams

    if [ ! "${gBuildPath}" ];then
      error "common.wydevops.extend.point.unspecified.build.path"
    fi

    info "common.wydevops.extend.point.detect.multi.module"
    invokeExtendPointFunc "checkMultipleModelProjectInJenkins" "common.wydevops.extend.point.jenkins.multi.module.check" ""
    if [ "${gMultipleModelProject}" == "true" ];then
      info "common.wydevops.extend.point.is.multi.module"
    else
      info "common.wydevops.extend.point.is.single.module"
    fi

    if [ "${gClearCachedParams}" == "true" ];then
      info "common.wydevops.extend.point.delete.existing.cicd.yaml"
      rm -rf "${gBuildPath:?}/${gCiCdYamlFileName}"
    fi

  else
    if [[ "${gBuildPath}" =~ ^(\.\/[a-zA-Z_]+) ]];then
      error "common.wydevops.extend.point.local.build.path.absolute"
    fi

    invokeExtendPointFunc "checkMultipleModelProjectInLocal" "common.wydevops.extend.point.local.multi.module.check" ""
    if [ "${gMultipleModelProject}" == "true" ];then
      info "common.wydevops.extend.point.is.multi.module"
    else
      info "common.wydevops.extend.point.is.single.module"
    fi

    #本地模式下，读取git提交随机码
    if [ ! "${gGitHash}" ];then
      l_value=$(git log -n 1 2>&1)
      if [[ ${l_value} && ! ${l_value} =~ ^(fatal:)  ]];then
        # shellcheck disable=SC2206
        l_array=(${l_value})
        gGitHash=${l_array[1]}
        info "common.wydevops.extend.point.get.git.hash.success" "${gGitHash}"
      else
        warn "common.wydevops.extend.point.get.git.hash.failed"
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
    info "common.wydevops.extend.point.no.custom.template" "_${gCiCdTemplateFileName}"
    invokeExtendPointFunc "createCiCdTemplateFile" "common.wydevops.extend.point.create.cicd.template.file" "_ci-cd-template.yaml" "${l_templateFile}"

    info "common.wydevops.extend.point.get.project.cicd.config" "_ci-cd-config.yaml"
    l_tmpCiCdConfigFile="${gBuildPath}/_${gCiCdConfigYamlFileName}"
    #尝试复制语言级_ci-cd-config.yaml创建一个项目级的_ci-cd-config.yaml
    #注意：语言级_ci-cd-config.yaml模板文件中对大部分的参数都配置了默认值。
    #如果不存在语言级_ci-cd-config.yaml文件，则直接返回。后续直接将l_ciCdConfigFile文件的内容合并到l_templateFile文件，
    invokeExtendPointFunc "createCiCdConfigFile" "common.wydevops.extend.point.get.cicd.config.file" "_ci-cd-config.yaml" "${l_templateFile}" "${l_tmpCiCdConfigFile}"

    #根据参数映射文件中的配置，初始化_ci-cd-config.yaml文件。
    #如果_ci-cd-config.yaml文件不存在，则直接初始化l_templateFile文件。
    invokeExtendPointFunc "initialCiCdConfigFileByParamMappingFiles" "common.wydevops.extend.point.init.cicd.config.file" "_ci-cd-config.yaml" "${l_templateFile}" "${l_tmpCiCdConfigFile}"

    #继续判断项目中是否存在ci-cd-config.yaml配置文件？
    #注意:项目中配置的ci-cd-config.yaml文件内容可能只是_ci-cd-config.yaml文件的子集。
    l_ciCdConfigFile="${gBuildPath}/${gCiCdConfigYamlFileName}"
    if [ -f  "${l_ciCdConfigFile}" ];then
      info "common.wydevops.extend.point.project.cicd.config.exists" "ci-cd-config.yaml"
      if [ -f "${l_tmpCiCdConfigFile}" ];then
        info "common.wydevops.extend.point.language.cicd.config.exists" "${gLanguage}#_ci-cd-config.yaml"
        info "common.wydevops.extend.point.merge.cicd.config.to.underscore" "ci-cd-config.yaml#_ci-cd-config.yaml"
        combine "${l_ciCdConfigFile}" "${l_tmpCiCdConfigFile}" "" "" "true" "true" "true"
        echo -e "\n"
        info "common.wydevops.extend.point.merge.underscore.config.to.template" "_ci-cd-config.yaml#_ci-cd-template.yaml"
        combine "${l_tmpCiCdConfigFile}" "${l_templateFile}" "" "" "true" "true"
      else
        warn "common.wydevops.extend.point.no.language.cicd.config" "${gLanguage}#_ci-cd-config.yaml"
        info "common.wydevops.extend.point.merge.underscore.config.to.template.direct" "ci-cd-config.yaml#_ci-cd-template.yaml"
        combine "${l_ciCdConfigFile}" "${l_templateFile}" "" "" "true" "true"
      fi
    elif [ -f "${l_tmpCiCdConfigFile}" ];then
      info "common.wydevops.extend.point.language.cicd.config.exists" "${gLanguage}#_ci-cd-config.yaml"
      info "common.wydevops.extend.point.merge.underscore.config.to.template.direct" "_ci-cd-config.yaml#_ci-cd-template.yaml"
      combine "${l_tmpCiCdConfigFile}" "${l_templateFile}" "" "" "true" "true"
    fi
    #删除临时文件
    rm -f "${l_tmpCiCdConfigFile}" || true

    info "common.wydevops.extend.point.create.cicd.yaml.from.template" "_ci-cd-template.yaml#ci-cd.yaml"
    #将_ci-cd-template.yaml文件内容复制到ci-cd.yaml文件中。
    cat "${l_templateFile}" > "${gCiCdYamlFile}"

    #删除临时文件
    rm -f "${l_templateFile}" || true

    #调用：替换变量引用前扩展点。
    invokeExtendPointFunc "onBeforeReplaceParamPlaceholder" "common.wydevops.extend.point.before.replace.placeholder" "ci-cd.yaml" "${gCiCdYamlFile}"
    #调用：替换变量引用扩展点。
    invokeExtendPointFunc "replaceParamPlaceholder" "common.wydevops.extend.point.replace.placeholder" "ci-cd.yaml" "${gCiCdYamlFile}"
    #调用：替换变量引用后扩展点。
    invokeExtendPointFunc "onAfterReplaceParamPlaceholder" "common.wydevops.extend.point.after.replace.placeholder" "ci-cd.yaml" "${gCiCdYamlFile}"

  fi

  info "common.wydevops.extend.point.load.global.params.from.cicd.yaml" "ci-cd.yaml"
  _loadGlobalParamsFromCiCdYaml "${gCiCdYamlFile}"

  gDockerTemplateDir="${gBuildScriptRootDir}/templates/docker"
  info "common.wydevops.extend.point.init.docker.template.path" "${gDockerTemplateDir}"

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
    info "common.wydevops.extend.point.init.build.main.dir" "${gHelmBuildDir}"
    mkdir -p "${gHelmBuildDir}"
  fi

  gHelmBuildOutDir="${gHelmBuildDir}/${gHelmBuildOutDirName}"
  if [[ ! -d "${gHelmBuildOutDir}" ]];then
    info "common.wydevops.extend.point.init.build.out.dir" "${gHelmBuildOutDir}"
    mkdir -p "${gHelmBuildOutDir}"
  fi

  gDockerBuildDir="${gHelmBuildDir}/${gDockerBuildDirName}"
  if [[ -d "${gDockerBuildDir}" ]];then
    rm -rf "${gDockerBuildDir:?}"
  fi
  info "common.wydevops.extend.point.init.docker.build.dir" "${gDockerBuildDir}"
  mkdir -p "${gDockerBuildDir}"

  gChartBuildDir="${gHelmBuildDir}/${gChartBuildDirName}"
  if [[ -d "${gChartBuildDir}" ]];then
    rm -rf "${gChartBuildDir:?}"
  fi
  info "common.wydevops.extend.point.init.chart.build.dir" "${gChartBuildDir}"
  mkdir -p "${gChartBuildDir}"

  gTempFileDir="${gHelmBuildDir}/${gTempFileDirName}"
  if [ -d "${gTempFileDir}" ];then
    #如果不为空，则删除该临时目录。
    rm -rf "${gTempFileDir:?}"
  fi
  info "common.wydevops.extend.point.init.temp.file.dir" "${gTempFileDir}"
  mkdir -p "${gTempFileDir}"

  gParamMappingDir=${gHelmBuildDir}/${gParamMappingDirName}
  if [ ! -d "${gTempFileDir}" ];then
    info "common.wydevops.extend.point.init.param.mapping.dir" "${gParamMappingDir}"
    mkdir -p "${gParamMappingDir}"
  fi

  gProjectShellDir="${gHelmBuildDir}/${gProjectShellDirName}"
  if [ ! -d "${gProjectShellDir}" ];then
    info "common.wydevops.extend.point.init.project.shell.dir" "${gProjectShellDir}"
    mkdir -p "${gProjectShellDir}"
  fi

  gProjectPluginDir="${gHelmBuildDir}/${gProjectPluginDirName}"
  if [ ! -d "${gProjectPluginDir}" ];then
    info "common.wydevops.extend.point.init.project.plugin.dir" "${gProjectPluginDir}"
    mkdir -p "${gProjectPluginDir}"
  fi

 gProjectTemplateDir="${gHelmBuildDir}/${gProjectTemplateDirName}"
 if [ ! -d "${gProjectTemplateDir}" ];then
   info "common.wydevops.extend.point.init.project.template.dir" "${gProjectTemplateDir}"
   mkdir -p "${gProjectTemplateDir}"
 fi

 gProjectDockerTemplateDir="${gProjectTemplateDir}/${gProjectDockerTemplateDirName}"
 if [ ! -d "${gProjectDockerTemplateDir}" ];then
   info "common.wydevops.extend.point.init.project.docker.template.dir" "${gProjectDockerTemplateDir}"
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

  info "common.wydevops.extend.point.check.create.missing.dirs"

  gHelmBuildDir="${gBuildPath}/${gHelmBuildDirName}"
  if [[ ! -d "${gHelmBuildDir}" ]];then
    info "common.wydevops.extend.point.init.build.main.dir" "${gHelmBuildDir}"
    mkdir -p "${gHelmBuildDir}"
  fi

  gHelmBuildOutDir="${gHelmBuildDir}/${gHelmBuildOutDirName}"
  if [[ ! -d "${gHelmBuildOutDir}" ]];then
    info "common.wydevops.extend.point.init.build.out.dir" "${gHelmBuildOutDir}"
    mkdir -p "${gHelmBuildOutDir}"
  fi

  gDockerBuildDir="${gHelmBuildDir}/${gDockerBuildDirName}"
  if [[ ! -d "${gDockerBuildDir}" ]];then
    info "common.wydevops.extend.point.init.docker.build.dir" "${gDockerBuildDir}"
    mkdir -p "${gDockerBuildDir}"
  else
    info "common.wydevops.extend.point.clear.docker.build.dir"
    rm -rf "${gDockerBuildDir:?}/*"
  fi

  gChartBuildDir="${gHelmBuildDir}/${gChartBuildDirName}"
  if [[ ! -d "${gChartBuildDir}" ]];then
    info "common.wydevops.extend.point.init.chart.build.dir" "${gChartBuildDir}"
    mkdir -p "${gChartBuildDir}"
  else
    info "common.wydevops.extend.point.clear.chart.build.dir"
    rm -rf "${gChartBuildDir:?}/*"
  fi

  gTempFileDir="${gHelmBuildDir}/${gTempFileDirName}"
  if [ ! -d "${gTempFileDir}" ];then
    info "common.wydevops.extend.point.init.temp.file.dir" "${gTempFileDir}"
    mkdir -p "${gTempFileDir}"
  else
    info "common.wydevops.extend.point.clear.temp.file.dir" "${gTempFileDir:-?}"
    rm -rf "${gTempFileDir:-?}/*"
  fi

  gParamMappingDir=${gHelmBuildDir}/${gParamMappingDirName}
  if [ ! -d "${gTempFileDir}" ];then
    info "common.wydevops.extend.point.init.param.mapping.dir" "${gParamMappingDir}"
    mkdir -p "${gParamMappingDir}"
  fi

  gProjectShellDir="${gHelmBuildDir}/${gProjectShellDirName}"
  if [ ! -d "${gProjectShellDir}" ];then
    info "common.wydevops.extend.point.init.project.shell.dir" "${gProjectShellDir}"
    mkdir -p "${gProjectShellDir}"
  fi

  gProjectPluginDir="${gHelmBuildDir}/${gProjectPluginDirName}"
  if [ ! -d "${gProjectPluginDir}" ];then
    info "common.wydevops.extend.point.init.project.plugin.dir" "${gProjectPluginDir}"
    mkdir -p "${gProjectPluginDir}"
  fi

   gProjectTemplateDir="${gHelmBuildDir}/${gProjectTemplateDirName}"
   if [ ! -d "${gProjectTemplateDir}" ];then
     info "common.wydevops.extend.point.init.project.template.dir" "${gProjectTemplateDir}"
     mkdir -p "${gProjectTemplateDir}"
   fi

   gProjectDockerTemplateDir="${gProjectTemplateDir}/${gProjectDockerTemplateDirName}"
   if [ ! -d "${gProjectDockerTemplateDir}" ];then
     info "common.wydevops.extend.point.init.project.docker.template.dir" "${gProjectDockerTemplateDir}"
     mkdir -p "${gProjectDockerTemplateDir}"
   fi
}

function _onAfterInitGlobalParams(){
  export gReleaseNotePath
  export gReleaseNoteFileName
  export gUpdateNote

  local l_releaseNotes
  local l_releaseNote

  info "common.wydevops.extend.point.read.release.note"
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
          warn "common.wydevops.extend.point.release.note.empty"
        fi
        break
      done
    else
      warn "common.wydevops.extend.point.release.note.not.exist" "${gReleaseNoteFileName}"
    fi
  else
    warn "common.wydevops.extend.point.release.note.path.not.configured"
  fi
}

function _loadJenkinsGlobalParams() {
  local l_value

  #构建脚本根目录。
  export gBuildScriptRootDir="${BUILD_SCRIPT_ROOT}"
  if [ ! "${gBuildScriptRootDir}" ];then
    error "common.wydevops.extend.point.build.script.root.not.specified"
  fi
  info "common.wydevops.extend.point.set.build.script.root.dir"

  export gGitProjectName="${GIT_PROJECT_NAME}"
  if [ ! "${gGitProjectName}" ];then
    error "common.wydevops.extend.point.git.project.name.not.specified"
  fi
  info "common.wydevops.extend.point.set.git.project.name"

  export gBuildPath="${BUILD_PATH}"
  if [ ! "${gBuildPath}" ];then
    error "common.wydevops.extend.point.build.path.not.specified"
  fi
  info "common.wydevops.extend.point.set.build.path"

  #解析Docker镜像仓库
  parseDockerRepoInfo "${DOCKER_REPO_INFO}"

  if [ ! "${gDockerRepoType}" ];then
    error "common.wydevops.extend.point.docker.repo.type.not.configured"
  fi
  info "common.wydevops.extend.point.set.docker.repo.type"

  if [ ! "${gDockerRepoInstanceName}" ];then
    error "common.wydevops.extend.point.docker.repo.instance.name.not.configured"
  fi
  info "common.wydevops.extend.point.set.docker.repo.instance.name"

  if [ ! "${gDockerRepoName}" ];then
    error "common.wydevops.extend.point.docker.repo.name.not.configured"
  fi
  info "common.wydevops.extend.point.set.docker.repo.name"

  if [ ! "${gDockerRepoAccount}" ];then
    error "common.wydevops.extend.point.docker.repo.account.not.configured"
  fi
  info "common.wydevops.extend.point.set.docker.repo.account"

  if [ ! "${gDockerRepoPassword}" ];then
    error "common.wydevops.extend.point.docker.repo.password.not.configured"
  fi
  info "common.wydevops.extend.point.set.docker.repo.password"

  if [ ! "${gDockerRepoWebPort}" ];then
    error "common.wydevops.extend.point.docker.repo.web.port.not.configured"
  fi
  info "common.wydevops.extend.point.set.docker.repo.web.port"

  #解析Chart镜像仓库
  parseChartRepoInfo "${CHART_REPO_INFO}"

  if [ ! "${gChartRepoType}" ];then
    error "common.wydevops.extend.point.chart.repo.type.not.configured"
  fi
  info "common.wydevops.extend.point.set.chart.repo.type"

  if [ ! "${gChartRepoInstanceName}" ];then
    error "common.wydevops.extend.point.chart.repo.instance.name.not.configured"
  fi
  info "common.wydevops.extend.point.set.chart.repo.instance.name"

  if [ ! "${gChartRepoName}" ];then
    error "common.wydevops.extend.point.chart.repo.name.not.configured"
  fi
  info "common.wydevops.extend.point.set.chart.repo.name"

  if [ ! "${gChartRepoAccount}" ];then
    error "common.wydevops.extend.point.chart.repo.account.not.configured"
  fi
  info "common.wydevops.extend.point.set.chart.repo.account"

  if [ ! "${gChartRepoPassword}" ];then
    error "common.wydevops.extend.point.chart.repo.password.not.configured"
  fi
  info "common.wydevops.extend.point.set.chart.repo.password"

  if [ ! "${gChartRepoWebPort}" ];then
    error "common.wydevops.extend.point.chart.repo.web.port.not.configured"
  fi
  info "common.wydevops.extend.point.set.chart.repo.web.port"

  export gExternalNotifyUrl="${EXTERNAL_NOTIFY_URL}"
  if [ ! "${gExternalNotifyUrl}" ];then
    warn "common.wydevops.extend.point.external.notify.url.not.configured"
  else
    info "common.wydevops.extend.point.set.external.notify.url"
  fi

  export gUpdateNotifyUrl="${DEPLOY_NOTIFY_URL}"
  if [ ! "${gUpdateNotifyUrl}" ];then
    warn "common.wydevops.extend.point.deploy.notify.url.not.configured"
  else
    info "common.wydevops.extend.point.set.deploy.notify.url"
  fi

  l_value="${DEPLOY_TARGET_NODES}"
  if [ ! "${l_value}" ];then
    warn "common.wydevops.extend.point.deploy.target.nodes.not.configured"
  else
    info "common.wydevops.extend.point.set.deploy.target.nodes"
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

    #去掉头部和尾部的空格。
    l_paramValue="${l_paramValue#"${l_paramValue%%[![:space:]]*}"}"
    l_paramValue="${l_paramValue%"${l_paramValue##*[![:space:]]}"}"

    #保留参数值中的引号
    l_paramValue="${l_paramValue//\\\"/\\\\\"}"
    #保留参数值中的“/”符号
    l_paramValue="${l_paramValue//\//\\/}"
    #保留参数值中的“-”符号
    l_paramValue="${l_paramValue//\-/\\-}"

    if [[ "${l_paramValue}" =~ ^(.*)\$\{(.*)$ ]];then
      l_paramRef=$(grep -oE "\\$\\{[a-zA-Z0-9_\\-]+\\}" <<< "${l_paramValue}")
      stringToArray "${l_paramRef}" "l_refItems"
      l_itemCount="${#l_refItems[@]}"
      for (( l_j = 0; l_j < l_itemCount; l_j++ )); do
        #获取参数${param},并删除前后的大括号。
        l_refItem="${l_refItems[${l_j}]}"
        l_refItem="${l_refItem#*{}"
        l_refItem="${l_refItem%\}*}"
        #得到引用的参数值。
        l_paramRef="${l_rowDataMap[${l_refItem}]}"

        #去掉头部和尾部的空格。
        l_paramRef="${l_paramRef#"${l_paramRef%%[![:space:]]*}"}"
        l_paramRef="${l_paramRef%"${l_paramRef##*[![:space:]]}"}"

        l_paramValue="${l_paramValue//\$\{${l_refItem}\}/${l_paramRef}}"
      done
    fi
    l_rowDataMap["${l_paramName}"]="${l_paramValue}"
    info "common.wydevops.extend.point.replace.placeholder.info" "${l_paramName}#${l_paramValue}"
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
  l_lines=$(grep -oE "\\\$\{[a-zA-Z0-9_\-]+\}" <<< "${l_content}" | sort | uniq -c)
  if [ "${lines}" ];then
    error "common.wydevops.extend.point.unconfigured.params.in.cicd.yaml" "${lines}"
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
  export gTargetApiServer
  export gTargetNamespace
  export gTargetGatewayHosts
  export gGatewayPath
  export gServiceName

  if [ ! "${gRuntimeVersion}" ];then
    #初始化gRuntimeVersion参数。
    readParam "${l_cicdYaml}" "globalParams.runtimeVersion"
    gRuntimeVersion="${gDefaultRetVal}"
  fi
  info "common.wydevops.extend.point.runtime.version.priority" "${gRuntimeVersion}"

  if [ ! "${gBuildType}" ];then
    #初始化gBuildType参数。
    readParam "${l_cicdYaml}" "globalParams.buildType"
    gBuildType="${gDefaultRetVal}"
  fi
  info "common.wydevops.extend.point.build.type.priority" "${gBuildType}"

  if [ ! "${gArchTypes}" ];then
    #初始化gArchTypes参数。
    readParam "${l_cicdYaml}" "globalParams.archTypes"
    if [ "${gDefaultRetVal}" != "null" ];then
      gArchTypes="${gDefaultRetVal}"
    else
      gArchTypes="linux/amd64,linux/arm64"
    fi
  fi
  info "common.wydevops.extend.point.arch.types.priority" "${gArchTypes}"

  if [ ! "${gOfflineArchTypes}" ];then
    #初始化gOfflineArchTypes参数。
    readParam "${l_cicdYaml}" "globalParams.offlineArchTypes"
    if [ "${gDefaultRetVal}" != "null" ];then
      gOfflineArchTypes="${gDefaultRetVal}"
    else
      gOfflineArchTypes="linux/amd64,linux/arm64"
    fi
  fi
  info "common.wydevops.extend.point.offline.arch.types.priority" "${gOfflineArchTypes}"

  if [ ! "${gUseTemplate}" ];then
    #初始化gUseTemplate参数。
    readParam "${l_cicdYaml}" "globalParams.useTemplate"
    if [ "${gDefaultRetVal}" != "null" ];then
      gUseTemplate="${gDefaultRetVal}"
    else
      gUseTemplate="false"
    fi
  fi
  info "common.wydevops.extend.point.use.template.priority" "${gUseTemplate}"

  if [ ! "${gValidBuildStages}" ];then
    readParam "${l_cicdYaml}" "globalParams.validBuildStages"
    if [ "${gDefaultRetVal}" != "null" ];then
      gValidBuildStages="${gDefaultRetVal}"
    else
      gValidBuildStages="all"
    fi
  fi
  info "common.wydevops.extend.point.valid.build.stages.priority" "${gValidBuildStages}"

  #初始化gRollback参数。
  readParam "${l_cicdYaml}" "globalParams.rollback"
  if [ "${gDefaultRetVal}" == "false" ];then
    gRollback="false"
  else
    gRollback="true"
  fi
  info "common.wydevops.extend.point.rollback.config.value" "${gRollback}"

  #初始化gTargetApiServer参数。
  readParam "${l_cicdYaml}" "globalParams.targetApiServer"
  if [ "${gDefaultRetVal}" != "null" ];then
    #调用解密接口解密gTargetApiServer参数值。
    invokeExtendPointFunc "decodeSecretInfo" "common.wydevops.extend.point.decoding.secret.info" \
      "gTargetApiServer" "gTargetApiServer" "${gDefaultRetVal}"
    gTargetApiServer="${gDefaultRetVal}"
  else
    gTargetApiServer=""
  fi
  info "common.wydevops.extend.point.target.api.server.config.value" "${gTargetApiServer}"

  #初始化gTargetNamespace参数。
  readParam "${l_cicdYaml}" "globalParams.targetNamespace"
  if [ "${gDefaultRetVal}" != "null" ];then
    gTargetNamespace="${gDefaultRetVal}"
  else
    gTargetNamespace="default"
  fi
  info "common.wydevops.extend.point.target.namespace.config.value" "${gTargetNamespace}"

  #初始化gTargetGatewayHosts参数。
  readParam "${l_cicdYaml}" "globalParams.gatewayHost"
  if [ "${gDefaultRetVal}" != "null" ];then
    gTargetGatewayHosts="${gDefaultRetVal}"
  else
    gTargetGatewayHosts=""
  fi
  info "common.wydevops.extend.point.target.gateway.hosts.config.value" "${gTargetGatewayHosts}"

  #初始化gGatewayPath参数。
  readParam "${l_cicdYaml}" "globalParams.gatewayPath"
  if [ "${gDefaultRetVal}" != "null" ];then
    gGatewayPath="${gDefaultRetVal}"
  else
    gGatewayPath=""
  fi
  info "common.wydevops.extend.point.gateway.path.config.value" "${gGatewayPath}"

  #初始化gServiceName参数。
  readParam "${l_cicdYaml}" "globalParams.serviceName"
  if [ "${gDefaultRetVal}" == "null" ];then
    error "common.wydevops.extend.point.service.name.not.empty" "${l_cicdYaml}#globalParams.serviceName"
  fi
  gServiceName="${gDefaultRetVal}"
  info "common.wydevops.extend.point.service.name.config.value" "${gServiceName}"

  #初始化gBusinessVersion参数。
  readParam "${l_cicdYaml}" "globalParams.businessVersion"
  if [ "${gDefaultRetVal}" == "null" ];then
    error "common.wydevops.extend.point.service.name.not.empty" "${l_cicdYaml}#globalParams.businessVersion"
  fi
  gBusinessVersion="${gDefaultRetVal}"
  info "common.wydevops.extend.point.business.version.config.value" "${gBusinessVersion}"
}

#------------------------私有方法--结束-------------------------#

#加载语言级脚本扩展文件
loadExtendScriptFileForLanguage "wydevops"
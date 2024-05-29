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
  local l_cicdYaml=$1
  local l_placeholders
  local l_placeholder

  #检查文件中是否存在未定义好的占位符号。
  # shellcheck disable=SC2002
  l_placeholders=$(cat "${l_cicdYaml}" | grep -oP "_([A-Z]?[A-Z0-9\-]+)_" | sort | uniq -c)
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
  export gBuildScriptRootDir
  export gLanguage

  local l_cicdTemplateFile=$1

  local l_templateFile
  local l_info

  l_info="将/templates/config/${gLanguage}/_ci-cd-template.yaml模板文件内容复制到${l_cicdTemplateFile##*/}文件中"
  l_templateFile="${gBuildScriptRootDir}/templates/config/${gLanguage}/_ci-cd-template.yaml"
  if [ ! -f "${l_templateFile}" ];then
    l_info="将/templates/config/_ci-cd-template.yaml模板文件内容复制到${l_cicdTemplateFile##*/}文件中"
    l_templateFile="${gBuildScriptRootDir}/templates/config/_ci-cd-template.yaml"
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
#  else
#    info "依据_ci-cd-template.yaml文件创建项目级的_ci-cd-config.yaml"
#    debug "--->将_ci-cd-template.yaml文件中的globalParams配置节复制到_ci-cd-config.yaml文件中"
#    readParam "${l_cicdTemplateFile}" "globalParams"
#    l_content="${gDefaultRetVal}"
#    if [ "${l_content}" != "null" ];then
#       insertParam "${l_cicdConfigFile}" "globalParams" "${l_content}"
#    fi
#
#    debug "--->将_ci-cd-template.yaml文件中的docker.thirdParties配置节复制到_ci-cd-config.yaml文件的thirdParties配置节中"
#    readParam "${l_cicdTemplateFile}" "docker.thirdParties"
#    if [ "${gDefaultRetVal}" != "null" ];then
#      insertParam "${l_cicdConfigFile}" "thirdParties" "${gDefaultRetVal}"
#    fi
#
#    debug "--->将_ci-cd-template.yaml文件中的chart[].params配置节复制到_ci-cd-config.yaml文件的params配置节中"
#    readParam "${l_cicdTemplateFile}" "chart"
#    if [ "${gDefaultRetVal}" != "null" ];then
#      l_itemCount=$(echo -e "${gDefaultRetVal}" | grep -oP "^(\- )" | wc -l)
#      for ((l_i = 0; l_i < l_itemCount; l_i++));do
#        readParam "${l_cicdTemplateFile}" "chart[${l_i}].params"
#        if [ "${gDefaultRetVal}" != "null" ];then
#          insertParam "${l_cicdConfigFile}" "params[${l_i}]" "${gDefaultRetVal}"
#        fi
#      done
#    else
#      error "_ci-cd-template.yaml模板文件异常：读取chart配置节失败"
#    fi
  fi
}

#------------------------私有函数--------------------------#

function _onBeforeInitGlobalParams() {
  export gWorkMode
  export gGitProjectName
  export gBuildPath
  export gLanguage
  export gWorkSpace
  export gMultipleModelProject

  local l_value
  local l_array

  if [ ! "${gWorkMode}" ];then
    error "未指定工作模式"
  fi

  if [ ! "${gLanguage}" ];then
    error "未指定项目语言类型"
  fi

  if [ ! "${gBuildPath}" ];then
    error "未指定构建项目主模块路径"
  fi

  if [ "${gWorkMode}" == "jenkins" ];then
    info "从Jenkins全局参数中初始化全局变量"
    _loadJenkinsGlobalParams

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

  export gBuildType

  local l_templateFile
  local l_tmpTemplateFile
  local l_ciCdConfigFile
  local l_tmpCiCdConfigFile

  l_templateFile="${gBuildPath}/${gLanguage}/_${gCiCdTemplateFileName}"
  if [ ! -f "${l_templateFile}" ];then
    l_templateFile="${gBuildPath}/_${gCiCdTemplateFileName}"
    info "使用公共配置文件：_${gCiCdTemplateFileName}"
  else
    info "使用${gLanguage}语言级配置文件：${gLanguage}/_${gCiCdTemplateFileName}"
  fi

  l_tmpTemplateFile="${gBuildPath}/${gCiCdTemplateFileName}"
  #判断项目中是否存在ci-cd-template.yaml配置文件？
  if [ ! -f "${l_tmpTemplateFile}" ];then
    #如果不存在，则复制公共模板(ci-cd-template.yaml)创建一个项目级的_ci-cd-template.yaml文件。
    info "未检测到自定义模板文件，使用默认的_${gCiCdTemplateFileName}模板文件 ..."
    invokeExtendPointFunc "createCiCdTemplateFile" "创建_ci-cd-template.yaml配置文件" "${l_templateFile}"

    info "创建项目级_ci-cd-config.yaml配置文件 ..."
    l_tmpCiCdConfigFile="${gBuildPath}/_${gCiCdConfigYamlFileName}"
    #首先尝试复制语言级_ci-cd-config.yaml创建一个项目级的_ci-cd-config.yaml
    #注意：语言级_ci-cd-config.yaml模板文件中对大部分的参数都配置了默认值。
    #如果不存在语言级_ci-cd-config.yaml文件，
    #则依据_ci-cd-template.yaml文件创建项目级的_ci-cd-config.yaml
    #注意：这样创建的_ci-cd-config.yaml文件，大部分参数都没有配置默认值，需要在初始化方法中完成默认值配置。
    invokeExtendPointFunc "createCiCdConfigFile" "创建_ci-cd-config.yaml配置文件" "${l_templateFile}" "${l_tmpCiCdConfigFile}"

    #继续判断项目中是否存在ci-cd-config.yaml配置文件？
    #注意:项目中配置的ci-cd-config.yaml文件内容可能只是_ci-cd-config.yaml文件的子集。
    l_ciCdConfigFile="${gBuildPath}/${gCiCdConfigYamlFileName}"
    if [ -f  "${l_ciCdConfigFile}" ];then
      info "检测到项目中存在ci-cd-config.yaml配置文件"
      if [ -f "${l_tmpCiCdConfigFile}" ];then
        info "检测到系统中配置有${gLanguage}语言级_ci-cd-config.yaml配置文件"
        info "先将ci-cd-config.yaml文件内容合并到_ci-cd-config.yaml文件中"
        combine "${l_ciCdConfigFile}" "${l_tmpCiCdConfigFile}" "" "false" "false" "true"
        echo -e "\n"
        info "再将_ci-cd-config.yaml文件内容合并到_ci-cd-template.yaml文件中"
        combine "${l_tmpCiCdConfigFile}" "${l_templateFile}" "" "false" "false"
      else
        warn "系统中未检测到${gLanguage}语言级_ci-cd-config.yaml配置文件"
        info "直接将ci-cd-config.yaml配置文件的内容合并到_ci-cd-template.yaml文件中"
        combine "${l_ciCdConfigFile}" "${l_templateFile}" "" "true" "true" "true"
      fi
    elif [ -f "${l_tmpCiCdConfigFile}" ];then
      info "检测到系统中配置有${gLanguage}语言级_ci-cd-config.yaml配置文件"
      info "直接将_ci-cd-config.yaml配置文件的内容合并到_ci-cd-template.yaml文件中"
      combine "${l_tmpCiCdConfigFile}" "${l_templateFile}" "" "true" "true" "true"
    fi

    #删除临时文件
    rm -f "${l_tmpCiCdConfigFile}" || true

  else
    info "检测到自定义配置文件：${gCiCdTemplateFileName}"
    cat "${l_tmpTemplateFile}" > "${l_templateFile}"
  fi

  info "从_ci-cd-template.yaml文件创建ci-cd.yaml文件"
  #获取ci-cd.yaml文件的绝对路径。
  gCiCdYamlFile="${gBuildPath}/${gCiCdYamlFileName}"
  #将ci-cd-template.yaml文件更名为ci-cd.yaml文件中。
  cat "${l_templateFile}" > "${gCiCdYamlFile}"

  if [ ! -f "${gCiCdYamlFile}" ];then
    error "未找到${gCiCdYamlFileName}文件：${gCiCdYamlFile}"
  fi

  #调用：替换变量引用前扩展点。
  invokeExtendPointFunc "onBeforeReplaceParamPlaceholder" "ci-cd.yaml文件中变量引用处理前" "${gCiCdYamlFile}"
  #调用：替换变量引用扩展点。
  invokeExtendPointFunc "replaceParamPlaceholder" "处理ci-cd.yaml文件中变量引用" "${gCiCdYamlFile}"
  #调用：替换变量引用后扩展点。
  invokeExtendPointFunc "onAfterReplaceParamPlaceholder" "ci-cd.yaml文件中变量引用处理后" "${gCiCdYamlFile}"

  info "从ci-cd.yaml文件中统一读取全局配置参数..."
  _loadGlobalParamsFromCiCdYaml "${gCiCdYamlFile}"

  gDockerTemplateDir="${gBuildScriptRootDir}/templates/docker"
  info "初始化docker模板文件的路径:${gDockerTemplateDir}"

  gHelmBuildDir="${gBuildPath}/${gHelmBuildDirName}"
  info "初始化构建主目录:${gHelmBuildDir}"
  if [[ ! -d "${gHelmBuildDir}" ]];then
    mkdir -p "${gHelmBuildDir}"
  fi

  gHelmBuildOutDir="${gHelmBuildDir}/${gHelmBuildOutDirName}"
  info "初始化构建输出目录:${gHelmBuildOutDir}"
  if [[ ! -d "${gHelmBuildDir}" ]];then
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

  if [ "${gTempFileDir}" ];then
    #如果不为空，则删除该临时目录。
    # shellcheck disable=SC2115
    rm -rf "${gTempFileDir}/"
  fi
  gTempFileDir="${gBuildPath}/${gTempFileDirName}"
  if [[ -d "${gTempFileDir}" ]];then
    rm -rf "${gTempFileDir:?}"
  fi
  info "初始化临时文件存储目录:${gTempFileDir}"
  mkdir -p "${gTempFileDir}"
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

  export gDockerRepoName="${DOCKER_REPO_NAME}"
  if [ ! "${gDockerRepoName}" ];then
    error "未配置Docker镜像仓库名称(DOCKER_REPO_NAME)"
  fi
  info "--->设置gDockerRepoName=\${DOCKER_REPO_NAME}"

  export gDockerRepoAccount="${DOCKER_REPO_ACCOUNT}"
  if [ ! "${gDockerRepoAccount}" ];then
    error "未配置Docker镜像仓库登录账号(DOCKER_REPO_ACCOUNT)"
  fi
  info "--->设置gDockerRepoAccount=\${DOCKER_REPO_ACCOUNT}"

  export gDockerRepoPassword="${DOCKER_REPO_PASSWORD}"
  if [ ! "${gDockerRepoPassword}" ];then
    error "未配置Docker镜像仓库登录密码(DOCKER_REPO_PASSWORD)"
  fi
  info "--->设置gDockerRepoPassword=\${DOCKER_REPO_PASSWORD}"

  export gChartRepoName="${CHART_REPO_NAME}"
  if [ ! "${gChartRepoName}" ];then
    error "未配置Chart镜像仓库名称(CHART_REPO_NAME)"
  fi
  info "--->设置gChartRepoName=\${CHART_REPO_NAME}"

  export gChartRepoAccount="${CHART_REPO_ACCOUNT}"
  if [ ! "${gChartRepoAccount}" ];then
    error "未配置Chart镜像仓库登录账号(CHART_REPO_ACCOUNT)"
  fi
  info "--->设置gChartRepoAccount=\${CHART_REPO_ACCOUNT}"

  export gChartRepoPassword="${CHART_REPO_PASSWORD}"
  if [ ! "${gChartRepoPassword}" ];then
    error "未配置Chart镜像仓库登录密码(CHART_REPO_PASSWORD)"
  fi
  info "--->设置gChartRepoPassword=\${CHART_REPO_PASSWORD}"

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

  l_arrayLen="${#l_lines[@]}"
  for (( l_i = 0; l_i < l_arrayLen; l_i++ )); do
    l_line="${l_lines[${l_i}]}"
    #如果是空行或注释行，则跳过该行
    if [[ ! "${l_line}"  || "${l_line}" =~ ^([ ]*|^([ ]*)#(.*))$ ]];then
      continue
    fi
    l_paramName="${l_line%%:*}"
    l_paramValue="${l_line#*:}"
    l_paramValue="${l_paramValue:1}"
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
        l_refItem="${l_refItems[${l_j}]}"
        l_refItem="${l_refItem#*{}"
        l_refItem="${l_refItem%\}*}"
        l_paramRef="${l_rowDataMap[${l_refItem}]}"
        l_paramValue="${l_paramValue//\$\{${l_refItem}\}/${l_paramRef}}"
      done
    fi
    l_rowDataMap["${l_paramName}"]="${l_paramValue}"
    #debug "---将${l_paramName}替换为${l_paramValue}"
    #替换文件中的占位符。
    sed -i "s/\\\${${l_paramName}}/${l_paramValue}/g" "${l_cicdYaml}"
  done

  # shellcheck disable=SC2002
  l_lines=$(cat "${l_cicdYaml}" | grep -oP "\\\$\{[a-zA-Z0-9_\-]+\}" | sort | uniq -c)
  if [ "${lines}" ];then
    error "ci-cd.yaml文件中存在未明确配置的参数:\n${lines}"
  fi

  #清除内存中缓存的文件内容。
  clearCachedFileContent "${l_cicdYaml}"

}

#从ci-cd.yaml文件初始化全局变量的值。
function _loadGlobalParamsFromCiCdYaml() {
  local l_cicdYaml=$1

  #yaml-help.sh文件中定义的函数默认返回值变量。
  export gDefaultRetVal

  #以下3个配置参数以命令行输入值为最高优先级的配置值。
  export gUseTemplate
  export gBuildType
  export gArchTypes
  export gOfflineArchTypes
  export gValidBuildStages

  #以下4个配置参数以ci-cid.yaml文件中的内容为最高优先级的配置值。
  export gDevNamespace
  export gDevGatewayHosts
  export gServiceName

  if [ ! "${gBuildType}" ];then
    #初始化gBuildType参数。
    readParam "${l_cicdYaml}" "globalParams.buildType"
    gBuildType="${gDefaultRetVal}"
  else
    updateParam "${l_cicdYaml}" "globalParams.buildType" "${gBuildType}"
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
  else
    updateParam "${l_cicdYaml}" "globalParams.archTypes" "${gArchTypes}"
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
  else
    updateParam "${l_cicdYaml}" "globalParams.offlineArchTypes" "${gOfflineArchTypes}"
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
  else
    updateParam "${l_cicdYaml}" "globalParams.useTemplate" "${gUseTemplate}"
  fi
  info "gUseTemplate参数高优先配置值为：${gUseTemplate}"

  if [ ! "${gValidBuildStages}" ];then
    readParam "${l_cicdYaml}" "globalParams.validBuildStages"
    if [ "${gDefaultRetVal}" != "null" ];then
      gValidBuildStages="${gDefaultRetVal}"
    else
      gValidBuildStages="all"
    fi
  else
    updateParam "${l_cicdYaml}" "globalParams.validBuildStages" "${gValidBuildStages}"
  fi
  info "gValidBuildStages参数高优先配置值为：${gValidBuildStages}"

  #初始化gDevNamespace参数。
  readParam "${l_cicdYaml}" "globalParams.devNamespace"
  if [ "${gDefaultRetVal}" != "null" ];then
    gDevNamespace="${gDefaultRetVal}"
  else
    gDevNamespace=""
  fi
  info "gDevNamespace:从配置文件中读取配置值(${gDevNamespace})"

  #初始化gDevGatewayHosts参数。
  readParam "${l_cicdYaml}" "globalParams.devRouteHosts"
  if [ "${gDefaultRetVal}" != "null" ];then
    gDevGatewayHosts="${gDefaultRetVal}"
  else
    gDevGatewayHosts=""
  fi
  info "gDevGatewayHosts:从配置文件中读取配置值(${gDevGatewayHosts})"

  #初始化gServiceName参数。
  readParam "${l_cicdYaml}" "globalParams.serviceName"
  if [ "${gDefaultRetVal}" == "null" ];then
    error "${l_cicdYaml}文件中globalParams.serviceName参数不能为空"
  fi
  gServiceName="${gDefaultRetVal}"
  info "gServiceName:从配置文件中读取配置值(${gServiceName})"
}

#加载语言级脚本扩展文件
loadExtendScriptFileForLanguage "wydevops"
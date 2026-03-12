#!/usr/bin/env bash

#全局变量名称定义数组
export gGlobalParamNames=(
#构建唯一标识
"gRunID=\"$(date +%Y%m%d%H%M%S)\""
#----------------常量定义---------------#
"gCiCdYamlFileName=\"ci-cd.yaml\"" \
"gCiCdTemplateFileName=\"ci-cd-template.yaml\"" \
"gCiCdConfigYamlFileName=\"ci-cd-config.yaml\"" \
"gCiCdYamlFile" \

#构建相关目录名称
"gHelmBuildDirName=\"wydevops\"" \
"gDockerBuildDirName=\"docker-build\"" \
"gChartBuildDirName=\"chart-build\"" \
"gHelmBuildOutDirName=\"build-out\"" \
"gTempFileDirName=\"temp\"" \
"gParamMappingDirName=\"param-mapping\""
"gProjectShellDirName=\"shell\"" \
"gProjectPluginDirName=\"plugins\"" \
"gProjectTemplateDirName=\"templates\"" \
"gProjectDockerTemplateDirName=\"docker\"" \

#项目历史更新文件名称
"gReleaseNoteFileName=\"release_notes.txt\"" \
#项目历史更新文件所在的目录，不同语言项目可能不同。
"gReleaseNotePath" \

#-------接口參數定义1: 以下为命令行和Jenkins构建可输入的全局变量--------------#
#工作模式
"gWorkMode=\"jenkins\"" \
#构建类型
"gBuildType" \
#当前要执行的构建阶段集合
"gBuildStages" \
#项目配置的需要执行的构建阶段集合
"gValidBuildStages" \
#项目的语言类型
"gLanguage" \

#构建项目的主模块路径。
"gBuildPath" \
#构建脚本所在的目录
"gBuildScriptRootDir" \
#构建脚本中pipeline-stages目录
"gPipelineScriptsDir" \
#是否强制使用模板
"gUseTemplate" \
#Docker镜像的构建类型数组
"gArchTypes" \
#导出的离线包构建类型数组
"gOfflineArchTypes" \
#当前版本是否支持回滚操作
"gRollback" \
#k8s集群SSH连接参数
"gTargetApiServer" \
#k8s部署时默认的命名空间
"gTargetNamespace" \
#K8s部署的网关Host参数
"gTargetGatewayHosts" \
#K8s部署的网关路由前缀参数
"gGatewayPath" \
#本地缓存DockerFile文件中From语句指定的镜像的目录。
"gImageCacheDir" \
"gProjectShellDir" \
"gProjectPluginDir" \
"gProjectChartTemplatesDir" \
"gProjectTemplateDir" \
"gProjectDockerTemplateDir" \
"gOfflineDockerFileDir" \

#项目工程名称
"gServiceName" \
"gBusinessVersion" \

#构建过程中使用到的目录路径全名
"gHelmBuildDir" \
"gHelmBuildOutDir" \
"gDockerBuildDir" \
"gChartBuildDir" \
"gParamMappingDir" \
"gTempFileDir=\"${HOME}/.wydevops_temp\"" \

#docker仓库相关参数
#Docker仓库类型：nexus、harbor、registry、aws-ecr
"gDockerRepoType" \
#仓库实例名称(nexus)或项目名称(harbor)或registry服务名称(registry)或aws-ecr仓库名称(aws-ecr)
"gDockerRepoInstanceName" \
#仓库地址，{ip}:{端口}
"gDockerRepoName" \
"gDockerRepoAccount" \
"gDockerRepoPassword" \
#Restful API接口使用的端口
"gDockerRepoWebPort" \
#对于nexus类型的仓库，上传镜像名称是否带仓库实例名称前缀。
"gDockerImageNameWithInstance" \
#对于registry类型的仓库，指定其registry服务名称
"gRegistryName" \
#对于registry类型的仓库，指定其配置文件全路径名称
"gRegistryConfigFile" \

#Chart仓库相关参数
"gChartRepoType" \
"gChartRepoInstanceName" \
"gChartRepoName" \
"gChartRepoAccount" \
"gChartRepoPassword" \
"gChartRepoWebPort" \

#发布平台相关参数
"gUpdateNotifyUrl" \
"gUpdateNote" \

#------接口參數定义2: 以下为Jenkins流程特有的输入性全局变量--------------------#
"gGitProjectName" \
"gGitBranch" \
"gGitHash" \
"gShouldPublish" \

#---------------------------全局变量定义----------------#
"gGlobalParamCacheFileName=\"_global_params.yaml\"" \

#---------------------控制类参数----------------------#
#是否清除本地全局参数缓存文件
"gClearCachedParams=\"false\"" \
#Docker镜像完成推送后是否删除
"gDeleteImageAfterBuilding=\"false\"" \
#部署阶段是否强制覆盖目标仓库中同名同版本的Docker镜像
"gForceCoverage=\"false\"" \
#是否是多模块工程？方便不同语言项目设计自己的编译方式：
#例如，对于Java项目，如果是多模块项目则build时会从gBuildPath目录回退一级目录后再执行build。
"gMultipleModelProject=\"false\"" \

#---------------------与语言相关的参数----------------------#
#java项目使用的JDK版本
"gRuntimeVersion"

)

#----------------------------定义错误码和错误信息--------------------------#
export gErrorDetail
#扩展脚本执行结果
export gShellExecuteResult

function usage() {
  export gMessagePropertiesMap

  local l_title="${gMessagePropertiesMap['global.params.sh.usage.title']}"
  local l_switches="${gMessagePropertiesMap['global.params.sh.usage.switches']}"
  local l_clearCachedParam="${gMessagePropertiesMap['global.params.sh.usage.clearCachedParams']}"
  local l_debugParam="${gMessagePropertiesMap['global.params.sh.usage.debug']}"
  local l_enableNotifyParam="${gMessagePropertiesMap['global.params.sh.usage.enableNotify']}"
  local l_forceCoverageParam="${gMessagePropertiesMap['global.params.sh.usage.forceCoverage']}"
  local l_helpParam="${gMessagePropertiesMap['global.params.sh.usage.help']}"
  local l_multipleModelParam="${gMessagePropertiesMap['global.params.sh.usage.multipleModel']}"
  local l_templateParam="${gMessagePropertiesMap['global.params.sh.usage.template']}"
  local l_removeImageParam="${gMessagePropertiesMap['global.params.sh.usage.version']}"

  local l_optionsParams="${gMessagePropertiesMap['global.params.sh.usage.options']}"
  local l_archTypesParam="${gMessagePropertiesMap['global.params.sh.usage.archTypes']}"
  local l_buildTypeParam="${gMessagePropertiesMap['global.params.sh.usage.buildType']}"
  local l_chartRepoParam="${gMessagePropertiesMap['global.params.sh.usage.chartRepo']}"
  local l_dockerRepoParam="${gMessagePropertiesMap['global.params.sh.usage.dockerRepo']}"
  local l_imageCacheDirParam="${gMessagePropertiesMap['global.params.sh.usage.imageCacheDir']}"

  local l_languageParam="${gMessagePropertiesMap['global.params.sh.usage.language']}"
  local l_localConfigFileParam="${gMessagePropertiesMap['global.params.sh.usage.localConfigFile']}"
  local l_workModeParam="${gMessagePropertiesMap['global.params.sh.usage.workMode']}"
  local l_notifyParam="${gMessagePropertiesMap['global.params.sh.usage.notify']}"
  local l_outArchTypesParam="${gMessagePropertiesMap['global.params.sh.usage.outArchTypes']}"
  local l_buildPathParam="${gMessagePropertiesMap['global.params.sh.usage.buildPath']}"
  local l_buildStagesParam="${gMessagePropertiesMap['global.params.sh.usage.buildStages']}"
  local l_templateStringParam="${gMessagePropertiesMap['global.params.sh.usage.template.string']}"
  local l_workDirParam="${gMessagePropertiesMap['global.params.sh.usage.workDir']}"

  echo "
    ${l_title}:
    [${l_switches}]
    -c, --clearCachedParams  ${l_clearCachedParams}
    -d, --debug              ${l_debugParam}
    -e, --enableNotify       ${l_enableNotifyParam}
    -f, --forceCoverage      ${l_forceCoverageParam}
    -h, --help               ${l_helpParam}
    -m, --multipleModel      ${l_multipleModelParam}
    -r, --removeImage        ${l_removeImageParam}
    -t, --template           ${l_templateParam}
    -v, --version            ${l_versionParam}

    [${l_optionsParams}]
    -A, --archTypes       string    ${l_archTypesParam}
    -B, --buildType       string    ${l_buildTypeParam}
    -C, --chartRepo       string    ${l_chartRepoParam}
    -D, --dockerRepo      string    ${l_dockerRepoParam}
    -I, --imageCacheDir   string    ${l_imageCacheDirParam}
    -L, --language        string    ${l_languageParam}
        --localConfigFile string    ${l_localConfigFileParam}
    -M, --workMode        string    ${l_workModeParam}
    -N, --notify          string    ${l_notifyParam}
    -O, --outArchTypes    string    ${l_outArchTypesParam}
    -P, --buildPath       string    ${l_buildPathParam}
    -S, --buildStages     string    ${l_buildStagesParam}
    -T, --template        string    ${l_templateStringParam}
    -W, --workDir         string    ${l_workDirParam}
  "
  exit 0
}

function version() {
  echo "1.0.0"
}

#定义
function defineGlobalParams(){
  local l_param
  # shellcheck disable=SC2068
  for l_param in ${gGlobalParamNames[@]};do
    eval "export ${l_param}"
  done
}

#功能扩展点标准调用方法
function invokeExtendPointFunc() {
  export gDefaultRetVal
  export gShellExecuteResult

  local l_funcName=$1
  local l_extentPointName=$2

  local l_funcName1
  local l_param=("${@}")

  #删除前两个参数
  # shellcheck disable=SC2184
  unset l_param[0]
  # shellcheck disable=SC2184
  unset l_param[1]
  # shellcheck disable=SC2206
  l_param=(${l_param[*]})

  #调用公共功能扩展
  extendLog "\n--->> ${l_extentPointName}(${l_funcName}) <<---"

  gDefaultRetVal="null"
  gShellExecuteResult="false"

  if type -t "${l_funcName}_ex" > /dev/null; then
    info "global.params.sh.invoke.common.extend.point" "${l_funcName}"
    gShellExecuteResult="true"
    # shellcheck disable=SC2068
    "${l_funcName}_ex" "${l_param[@]}"
  else
    info "global.params.sh.no.common.extend.point" "${l_funcName}"
  fi

  #调用语言级功能扩展
  l_funcName1="_${l_funcName}_ex"
  if type -t "${l_funcName1}" > /dev/null; then
    info "global.params.sh.invoke.language.extend.point" "${gLanguage}" "${l_funcName1}"
    gShellExecuteResult="true"
    # shellcheck disable=SC2068
    "${l_funcName1}" ${l_param[@]}
  else
    info "global.params.sh.no.language.extend.point" "${gLanguage}" "${l_funcName1}"
  fi

  #如果存在项目级扩展，则调用之
  # shellcheck disable=SC2068
  executeShellScript "${gBuildPath}" "${l_funcName}.sh" ${l_param[@]}

  extendLog "<<--- ${l_extentPointName}(${l_funcName}) --->>\n"

}

function executeShellScript() {
  export gShellExecuteResult
  export gProjectShellDir

  local l_buildPath=$1
  local l_scriptFile=$2
  local l_localScriptFile

  local l_param=("${@}")

  #删除前两个参数
  # shellcheck disable=SC2184
  unset l_param[0]
  # shellcheck disable=SC2184
  unset l_param[1]
  # shellcheck disable=SC2206
  l_param=(${l_param[*]})

  gShellExecuteResult="false"
  #如果l_scriptFile脚本存在，则调用之
  l_localScriptFile="${gProjectShellDir}/${l_scriptFile}"
  if [ -f "${l_localScriptFile}" ];then
    gShellExecuteResult="true"
    # shellcheck disable=SC1090
    source "${l_localScriptFile}" "${l_param[@]}"
    info "global.params.sh.invoke.project.extend.point.success" "${l_scriptFile}"
  else
    info "global.params.sh.no.project.extend.point.file" "${l_scriptFile}"
  fi
}

function parseDockerRepoInfo() {
  local l_repoInfo=$1
  local l_array
  local l_size

  export gDockerRepoType
  export gDockerRepoInstanceName
  export gDockerRepoName
  export gDockerRepoAccount
  export gDockerRepoPassword
  export gDockerRepoWebPort
  export gDockerImageNameWithInstance
  #对于registry类型的仓库，指定其registry服务名称
  export gRegistryName
  #对于registry类型的仓库，指定其配置文件全路径名称
  export gRegistryConfigFile

  # shellcheck disable=SC2206
  l_array=(${l_repoInfo//,/ })
  l_size=${#l_array[@]}
  [[ "${l_size}" -lt 6 ]] && error "global.params.sh.docker.repo.config.not.enough" "${l_size}"

  gDockerRepoType="${l_array[0]}"
  gDockerRepoInstanceName="${l_array[1]}"
  gDockerRepoName="${l_array[2]}"
  gDockerRepoAccount="${l_array[3]}"
  gDockerRepoPassword="${l_array[4]}"
  gDockerRepoWebPort="${l_array[5]}"

  gDockerImageNameWithInstance="true"
  [[ "${gDockerRepoType}" == "nexus" && "${l_size}" -gt 6 ]] && gDockerImageNameWithInstance="${l_array[6]}"

  gRegistryName=""
  [[ "${gDockerRepoType}" == "registry" && "${l_size}" -gt 7 ]] && gRegistryName="${l_array[7]}"
  gRegistryConfigFile=""
  [[ "${gDockerRepoType}" == "registry" && "${l_size}" -gt 8 ]] && gRegistryConfigFile="${l_array[8]}"
}

function parseChartRepoInfo() {
  local l_repoInfo=$1

  local l_array
  local l_size

  export gChartRepoType
  export gChartRepoInstanceName
  export gChartRepoName
  export gChartRepoAccount
  export gChartRepoPassword
  export gChartRepoWebPort

  # shellcheck disable=SC2206
  l_array=(${l_repoInfo//,/ })
  l_size=${#l_array[@]}
  [[ "${l_size}" -lt 6 ]] && error "global.params.sh.chart.repo.config.not.enough" "${l_size}"

  gChartRepoType="${l_array[0]}"
  gChartRepoInstanceName="${l_array[1]}"
  gChartRepoName="${l_array[2]}"
  gChartRepoAccount="${l_array[3]}"
  gChartRepoPassword="${l_array[4]}"
  gChartRepoWebPort="${l_array[5]}"

}

#从文件中加载全局参数
function loadGlobalParamsFromCacheFile() {
  export gDefaultRetVal
  export gBuildPath
  export gGlobalParamNames
  export gGlobalParamCacheFileName

  local l_content
  local l_lineCount
  local l_i
  local l_line
  local l_paramName
  local l_paramValue

  info "global.params.sh.loading.global.params.from.cache" "-n"

  #读取文件中全部的有效行。
  l_content=$(awk "NR==1,NR==-1" "${gBuildPath}/${gGlobalParamCacheFileName}" \
    | grep -oE "^[a-zA-Z_]?[a-zA-Z0-9_\-].*$")

  l_lineCount=$(grep -cE "^[a-zA-Z_]" <<< "${l_content}")
  for ((l_i=1; l_i <= l_lineCount; l_i++));do
    l_line=$(echo "${l_content}" | sed -n "${l_i}p")
    l_paramName="${l_line%%:*}"
    l_paramValue="${l_line#*:}"
    l_paramValue="${l_paramValue:1}"
    if [[ "${l_paramValue}" =~ ^([ ]*)\|([+-\s]*)$ ]];then
      readParam "${gBuildPath}/${gGlobalParamCacheFileName}" "${l_paramName}"
      l_paramValue="${gDefaultRetVal}"
    fi

    eval "${l_paramName}=\"${l_paramValue}\""
  done

  info "global.params.sh.loading.global.params.from.cache.success" "*"
}

#将全局参数写入文件中
function cacheGlobalParamsToFile() {
  export gBuildPath
  export gGlobalParamNames
  export gGlobalParamCacheFileName

  local l_paramName
  local l_paramValue
  local l_rowCount

  #清空或创建缓存文件
  echo "" > "${gBuildPath}/${gGlobalParamCacheFileName}"
  # shellcheck disable=SC2068
  for l_paramName in ${gGlobalParamNames[@]};do
    l_paramName="${l_paramName%%=*}"
    eval "l_paramValue=\"\${${l_paramName}}\""
    l_rowCount=$(grep -cE "^([ ]*).*$" <<< "${l_paramValue}")
    if [ "${l_rowCount}" -le 1 ];then
      echo "${l_paramName}: ${l_paramValue}" >> "${gBuildPath}/${gGlobalParamCacheFileName}"
    else
      l_paramValue="|\n${l_paramValue}"
      insertParam "${gBuildPath}/${gGlobalParamCacheFileName}" "${l_paramName}" "${l_paramValue}"
    fi
  done
}

function loadExtendScriptFileForLanguage() {
  export gPipelineScriptsDir
  export gLanguage

  local l_currentStage=$1

  #是否存在语言级功能扩展,如果存在则加载之
  if [ -f "${gPipelineScriptsDir}/${gLanguage}/${l_currentStage}-extend-point.sh" ];then
    info "global.params.sh.loading.language.extend.file" "${gLanguage}" "${l_currentStage}"
    # shellcheck disable=SC1090
    source "${gPipelineScriptsDir}/${gLanguage}/${l_currentStage}-extend-point.sh"
  fi
}

#首次解析输入参数，关注初始化过程需要的参数：
#工作模式、语言类型、构建类型、是否是多模块项目、模块主目录、脚本工作目录
function parseOptions1() {
  export gDebugMode
  export gBuildType
  export gLanguage
  export gWorkMode
  export gArchTypes
  export gOfflineArchTypes
  export gBuildScriptRootDir
  export gForceCoverage
  export gMultipleModelProject
  export gClearCachedParams

  local l_param
  local getOpt_cmd

  gDebugMode="false"
  gClearCachedParams="false"
  gForceCoverage="false"
  gMultipleModelProject="false"

  #解析命令行参数
  getOpt_cmd=$(getopt -o cdefhmrtvA:B:C:D:I:L:M:N:O:P:S:T:W: -l clearCachedParams,debug,enableNotify,forceCoverage,help,multipleModel,removeImage,template,version,archTypes:,buildType:,chartRepo:,dockerRepo:,imageCacheDir:,language:,localConfigFile:,workMode:,notify:,outArchTypes:,buildPath:,buildStages:,enableTemplate:,workDir: -n "${0}" -- "${@}")

  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    error "global.params.sh.get.script.params.exception" "$?"
  fi
  eval set -- "${getOpt_cmd}"

  #解析选项
  while [ -n "${1}" ]
  do
    case "${1}" in
      -c|--clearCachedParams)
        gClearCachedParams="true"
        shift ;;
      -d|--debug)
        gDebugMode="true"
        shift ;;
      -e|--enableNotify)
        shift ;;
      -f|--forceCoverage)
        gForceCoverage="true"
        shift ;;
      -h|--help)
        usage
        exit ;;
      -m|--multipleModel)
        gMultipleModelProject="true"
        shift ;;
      -r|--removeImage)
        gDeleteImageAfterBuilding="true"
        shift ;;
      -t|--template)
        shift ;;
      -v|--version)
        version
        exit ;;
      -A|--archTypes)
        l_param="${2}"
        if [[ "${l_param}" &&  "${l_param}" != "undefine" ]];then
          # shellcheck disable=SC2206
          gArchTypes="${l_param}"
          [[ ! "${gOfflineArchTypes}" ]] && gOfflineArchTypes="${l_param}"
          debug "global.params.sh.arch.types.from.cmd" "${gArchTypes}"
        fi
        shift 2
        ;;
      -B|--buildType)
        l_param="${2}"
        if [[ "${l_param}" &&  "${l_param}" != "undefine" ]];then
          gBuildType="${l_param}"
          debug "global.params.sh.build.type.from.cmd" "${gBuildType}"
        fi
        shift 2
        ;;
      -C|--chartRepo)
        l_param="${2}"
        if [ "${l_param}" ];then
          parseChartRepoInfo "${l_param}"
        fi
        shift 2
        ;;
      -D|--dockerRepo)
        l_param="${2}"
        if [ "${l_param}" ];then
          parseDockerRepoInfo "${l_param}"
        fi
        shift 2
        ;;
      -I|--imageCacheDir)
        shift 2
        ;;
      -L|--language)
        l_param="${2}"
        if [ "${l_param}" ];then
          gLanguage="${l_param}"
        fi
        shift 2
        ;;
      --localConfigFile)
        l_param="${2}"
        if [ "${l_param}" ];then
          gCiCdConfigYamlFileName="${l_param}"
          warn "global.params.sh.local.config.file.from.cmd" "${gCiCdConfigYamlFileName}"
        fi
        shift 2
        ;;
      -M|--workMode)
        l_param="${2}"
        if [ "${l_param}" ];then
          gWorkMode="${l_param}"
        fi
        shift 2
        ;;
      -N|--notify)
        shift 2
        ;;
      -O|--outArchTypes)
        l_param="${2}"
         if [[ "${l_param}" && "${l_param}" != "undefine" ]];then
          # shellcheck disable=SC2206
          gOfflineArchTypes="${l_param}"
          debug "global.params.sh.offline.package.build.type.from.cmd" "${gOfflineArchTypes}"
        fi
        shift 2
        ;;
      -P|--buildPath)
        l_param="${2}"
        if [ "${l_param}" ];then
          gBuildPath="${l_param}"
        fi
        shift 2
        ;;
      -S|--buildStages)
        shift 2
        ;;
      -T|--enableTemplate)
        shift 2
        ;;
      -W|--workDir)
        l_param="${2}"
        if [ "${l_param}" ];then
          gBuildScriptRootDir="${l_param}"
        fi
        shift 2
        ;;
      --)
        #遇到--，直接跳过
        shift
        break ;;
      *)
        error "global.params.sh.invalid.option" "${1}"
        ;;
    esac
  done
}

#二次解析输入参数，关注后续执行阶段需要的参数
function parseOptions2() {
  export gEnableNotify
  export gBuildStages
  export gUpdateNotifyUrl
  export gUseTemplate
  export gImageCacheDir
  export gDeleteImageAfterBuilding

  local l_param
  local getOpt_cmd

  gEnableNotify="false"
  gDeleteImageAfterBuilding="false"
  gUseTemplate="false"

  #解析命令行参数
  getOpt_cmd=$(getopt -o cdefhmrtvA:B:C:D:I:L:M:N:O:P:S:T:W: -l clearCachedParams,debug,enableNotify,forceCoverage,help,multipleModel,removeImage,template,version,archTypes:,buildType:,chartRepo:,dockerRepo:,imageCacheDir:,language:,localConfigFile:,workMode:,notify:,outArchTypes:,buildPath:,buildStages:,enableTemplate:,workDir: -n "${0}" -- "${@}")

  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    exit 1
  fi
  eval set -- "${getOpt_cmd}"

  #解析选项
  while [ -n "${1}" ]
  do
    case "${1}" in
      -c|--clearCachedParams)
        shift ;;
      -d|--debug)
        shift ;;
      -e|--enableNotify)
        gEnableNotify="true"
        shift ;;
      -f|--forceCoverage)
        gForceCoverage="true"
        shift ;;
      -h|--help)
        shift ;;
      -m|--multipleModel)
        shift ;;
      -r|--removeImage)
        shift ;;
      -t|--template)
        gUseTemplate="true"
        shift ;;
      -v|--version)
        shift ;;
      -A|--archTypes)
        shift 2
        ;;
      -B|--buildType)
        shift 2
        ;;
      -C|--chartRepo)
        shift 2
        ;;
      -D|--dockerRepo)
        shift 2
        ;;
      -I|--imageCacheDir)
        l_param="${2}"
        if [ "${l_param}" ];then
          gImageCacheDir="${l_param}"
        fi
        shift 2
        ;;
      -L|--language)
        shift 2
        ;;
      --localConfigFile)
        shift 2
        ;;
      -M|--workMode)
        shift 2
        ;;
      -N|--notify)
        l_param="${2}"
        if [ "${l_param}" ];then
          gUpdateNotifyUrl="${l_param}"
        fi
        shift 2
        ;;
      -O|--outArchTypes)
        shift 2
        ;;
      -P|--buildPath)
        shift 2
        ;;
      -S|--buildStages)
        l_param="${2}"
        if [ "${l_param}" ];then
          gBuildStages="${l_param}"
        fi
        shift 2
        ;;
      -T|--enableTemplate)
        l_param="${2}"
        if [ "${l_param}" ];then
          gUseTemplate="${l_param}"
        fi
        shift 2
        ;;
      -W|--workDir)
        shift 2
        ;;
      --)
        #遇到--，直接跳过
        shift
        break ;;
      *)
        error "${1} 不是一个有效选项"
        ;;
    esac
  done

}

function getParamValueInJsonConfigFile() {
  export gDefaultRetVal

  local l_configFile=$1
  local l_startRowRegex=$2
  local l_paramName=$3
  local l_defaultValue=$4
  local l_insertOnNotExist=$5

  local l_rowNumber
  local l_rowContent
  local l_content
  local l_paramValue

  #使用默认值初始化l_paramValue
  l_paramValue="${l_defaultValue}"
  # shellcheck disable=SC2002
  l_content=$(grep -noE "${l_startRowRegex}" "${l_configFile}")
  if [ "${l_content}" ];then
    l_rowNumber=${l_content%%:*}
    l_content=$(awk "NR==${l_rowNumber},NR==-1" "${l_configFile}" | grep -m 1 -noE "^[ ]*${l_paramName}:(.*)$")
    if [ "${l_content}" ];then
      #提取行号。
      (( l_rowNumber=l_rowNumber - 1 + ${l_content%%:*} ))
      #提取行内容
      l_rowContent=${l_content#*:}
      #获取行中第一个冒号后的内容。
      l_content="${l_rowContent##*:}"
      #去掉获取内容的前后空格
      l_content="${l_content#"${l_content%%[![:space:]]*}"}"
      l_content="${l_content%"${l_content##*[![:space:]]}"}"
      #获取逗号左边的内容。
      l_content="${l_content%,*}"
      #删除单引号
      l_content="${l_content//\'/}"
      #删除双引号
      l_content="${l_content//\"/}"
      if [ "${l_content}" ];then
        l_paramValue="${l_content}"
      #如果参数值为空，则判断是否需要强行用默认值替换。
      else
        if [ "${l_insertOnNotExist}" == "true" ];then
          warn "检测到项目配置文件中${l_paramName}参数的值为空，强制更新为默认值：${l_defaultValue}"
          #替换l_rowNumber行的内容。
          sed -i "${l_rowNumber}c\\${l_rowContent%%:*}: '${l_defaultValue}'," "${l_configFile}"
        fi
        l_paramValue="${l_defaultValue}"
      fi
    #如果参数值为空，则判断是否需要强行插入默认值。
    else
      if [ "${l_insertOnNotExist}" == "true" ];then
        warn "检测到项目配置文件中不存在${l_paramName}参数，强制插入该参数并设置默认值为：${l_defaultValue}"
        #在l_rowNumber行的下一行插入参数。
        sed -i "${l_rowNumber}a\\    ${l_paramName}: '${l_defaultValue}'," "${l_configFile}"
      fi
      l_paramValue="${l_defaultValue}"
    fi
  fi

  gDefaultRetVal="${l_paramValue}"
}

#定义全局常量和变量
defineGlobalParams
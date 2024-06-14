#!/usr/bin/env bash

#全局变量名称定义数组
export gGlobalParamNames=(
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
#本地缓存DockerFile文件中From语句指定的镜像的目录。
"gImageCacheDir" \
"gProjectShellDir" \
"gProjectPluginDir" \
"gProjectChartTemplatesDir" \
"gProjectTemplateDir" \
"gProjectDockerTemplateDir" \

#项目工程名称
"gServiceName" \

#构建过程中使用到的目录路径全名
"gHelmBuildDir" \
"gHelmBuildOutDir" \
"gDockerBuildDir" \
"gChartBuildDir" \
"gParamMappingDir" \
"gTempFileDir=\"/c/temp\"" \

#docker仓库相关参数
#Docker仓库类型：nexus或harbor
"gDockerRepoType" \
#仓库实例名称(nexus)或项目名称(harbor)
"gDockerRepoInstanceName" \
#仓库地址，{ip}:{端口}
"gDockerRepoName" \
"gDockerRepoAccount" \
"gDockerRepoPassword" \
#Restful API接口使用的端口
"gDockerRepoWebPort" \
#对于nexus类型的仓库，上传镜像名称是否带仓库实例名称前缀。
"gDockerImageNameWithInstance" \

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
#是否是多模块工程？方便不同语言项目设计自己的编译方式：
#例如，对于Java项目，如果是多模块项目则build时会从gBuildPath目录回退一级目录后再执行build。
"gMultipleModelProject=\"false\"" \

#---------------------与业务相关的参数----------------------#

)

#----------------------------定义错误码和错误信息--------------------------#
export gErrorDetail
#扩展脚本执行结果
export gShellExecuteResult

function usage() {
  # shellcheck disable=SC1073
  echo "
    参数说明:
    [开关量]
    -c, --clearCachedParams  清除本地全局参数缓存文件。
    -d, --debug              启用DEBUG模式输出测试信息。
    -e, --enableNotify       使能向外部接口发送CICD过程通知（需要配置-N参数）。
    -h, --help               显示帮助信息。
    -m, --multipleModel      指明要构建的目标项目是多模块项目。
    -r, --removeImage        构建结束后删除使用过的Docker镜像。
    -t, --template           忽略项目根目录下的Dockerfile系列文件，强制使用匹配的docker模板文件；等同 -T ture。
    -v, --version            显示本脚本的版本。

    [可选项]
    -A, --archTypes     string    要构建的Docker镜像的架构类型，默认值=undefine,
                                  可选值有：\"linux/amd64,linux/arm64\",\"linux/amd64\",\"linux/arm64\",\"undefine\"
    -B, --buildType     string    构建类型:
                                  single：单镜像模式，构建应用镜像
                                  double：双镜像模式，构建应用基础镜像和应用业务镜像
                                  base：仅构建应用基础镜像
                                  business：仅构建应用业务镜像
                                  thirdParty: 打包第三方镜像：拉取第三方镜像，缓存到本地镜像缓存目录中，
                                              然后推送到私库中，最后导出到gDockerBuildOutDir目录中。
                                  customize: 自定义模式：指定docker构建目录，脚本框架自动完成docker镜像构建和推送。
    -C, --chartRepo     string    Chart镜像仓库信息, 格式：{仓库类型(nexus或harbor)},{仓库实例名称(nexus)或项目名称(harbor)},{仓库访问地址({IP}:{端口})},{登录账号},{登录密码},{Web管理端口(RestfulAPI接口使用的端口)}
    -D, --dockerRepo    string    Docker镜像仓库信息, 格式：{仓库类型(nexus或harbor)},{仓库实例名称(nexus)或项目名称(harbor)},{仓库访问地址({IP}:{端口})},{登录账号},{登录密码},{Web管理端口(RestfulAPI接口使用的端口)},{镜像名称是否带仓库实例名前缀(仅对nexus类型仓库有效)}
    -I, --imageCacheDir String    当workMode=local时，用于缓存Dockerfile文件中From行指定的Image镜像的本地目录。
    -L, --language      string    项目语言类型; 例如：java、go、c++、python、vue、nodejs等，依据具体实现而定。
    -M, --workMode      string    工作模式：jenkins、local
    -N, --notify        string    外部通知接口的地址
    -O, --outArchTypes  string    要导出的离线安装包的架构类型，默认值=\"linux/amd64,linux/arm64\"
    -P, --buildPath     string    构建目录，一般为目标工程的根目录或主模块目录（例如：Java多模块项目）
    -S, --buildStages   string    执行的构建阶段，有效值包括：build、docker、chart、package、deploy、all，
                                  有效值为前四个阶段的有序组合,阶段间用英文逗号隔开；或直接设置为all；为空时等同于all。
                                  例如：build,docker,chart——表示依次执行指定的构建阶段。
    -T, --template      string    是否忽略项目根目录下的Dockerfile系列文件,与开关量-t作用相同。有效取值：false或true
    -W, --workDir       string    仅当workMode=local时，用于指定本脚本所在的目录；
                                  当workMode=jenkins时，脚本所在的目录由全局变量BUILD_SCRIPT_ROOT指定
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

  gShellExecuteResult="false"

  if type -t "${l_funcName}_ex" > /dev/null; then
    info "调用公共功能扩展点:${l_funcName}_ex..."
    gShellExecuteResult="true"
    # shellcheck disable=SC2068
    "${l_funcName}_ex" "${l_param[@]}"
  else
    info "未检测到公共功能扩展点:${l_funcName}_ex..."
  fi

  #调用语言级功能扩展
  l_funcName1="_${l_funcName}_ex"
  if type -t "${l_funcName1}" > /dev/null; then
    info "调用${gLanguage}语言级功能扩展点:${l_funcName1}..."
    gShellExecuteResult="true"
    # shellcheck disable=SC2068
    "${l_funcName1}" ${l_param[@]}
  else
    info "未检测到${gLanguage}语言级功能扩展点:${l_funcName1}..."
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
    info "调用项目级功能扩展${l_scriptFile}...成功"
  else
    info "未发现项目级功能扩展文件：${l_scriptFile}"
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

  # shellcheck disable=SC2206
  l_array=(${l_repoInfo//,/ })
  l_size=${#l_array[@]}
  [[ "${l_size}" -lt 6 ]] && error "docker仓库配置参数不足：需要六个参数，只配置了${l_size}个参数。"

  gDockerRepoType="${l_array[0]}"
  gDockerRepoInstanceName="${l_array[1]}"
  gDockerRepoName="${l_array[2]}"
  gDockerRepoAccount="${l_array[3]}"
  gDockerRepoPassword="${l_array[4]}"
  gDockerRepoWebPort="${l_array[5]}"

  gDockerImageNameWithInstance="true"
  [[ "${gDockerRepoType}" == "nexus" && "${l_size}" -gt 6 ]] && gDockerImageNameWithInstance="${l_array[6]}"
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
  [[ "${l_size}" -lt 6 ]] && error "chart仓库配置参数不足：需要六个参数，只配置了${l_size}个参数。"

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

  info "从文件中加载缓存的全局参数的值..." "-n"

  #读取文件中全部的有效行。
  l_content=$(awk "NR==1,NR==-1" "${gBuildPath}/${gGlobalParamCacheFileName}" \
    | grep -oP "^[a-zA-Z_]?[a-zA-Z0-9_\-].*$")

  l_lineCount=$(echo -e "${l_content}" | grep -oP "^[a-zA-Z_]" | wc -l)
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

  info "成功" "*"
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
    l_rowCount=$(echo -e "${l_paramValue}" | grep -oP "^([ ]*).*$" | wc -l)
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
    info "加载语言级功能扩展文件：${gLanguage}/${l_currentStage}-extend-point.sh"
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
  export gMultipleModelProject
  export gClearCachedParams

  local l_param
  local getOpt_cmd

  gDebugMode="false"
  gClearCachedParams="false"
  gMultipleModelProject="false"

  #解析命令行参数
  getOpt_cmd=$(getopt -o cdehmrtvA:B:C:D:I:L:M:N:O:P:S:T:W: -l clearCachedParams,debug,enableNotify,help,multipleModel,removeImage,template,version,archTypes:,buildType:,chartRepo:,dockerRepo:,imageCacheDir:,language:,workMode:,notify:,outArchTypes:,buildPath:,buildStages:,enableTemplate:,workDir: -n "${0}" -- "${@}")

  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    error "获取脚本传入参数异常：$?"
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
          gArchTypes=${l_param}
          debug "从命令行读取的目标架构类型(gArchTypes)参数值为：${gArchTypes}"
        fi
        shift 2
        ;;
      -B|--buildType)
        l_param="${2}"
        if [[ "${l_param}" &&  "${l_param}" != "undefine" ]];then
          gBuildType="${l_param}"
          debug "从命令行读取的构建类型(gBuildType)参数值为: ${gBuildType}"
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
          gOfflineArchTypes=${l_param}
          debug "从命令行读取的离线安装包构建类型(gOfflineArchTypes)参数值为: ${gOfflineArchTypes}"
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
        error "${1} 不是一个有效选项"
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
  getOpt_cmd=$(getopt -o cdehmrtvA:B:C:D:I:L:M:N:O:P:S:T:W: -l clearCachedParams,debug,enableNotify,help,multipleModel,removeImage,template,version,archTypes:,buildType:,chartRepo:,dockerRepo:,imageCacheDir:,language:,workMode:,notify:,outArchTypes:,buildPath:,buildStages:,enableTemplate:,workDir: -n "${0}" -- "${@}")

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

#定义全局常量和变量
defineGlobalParams
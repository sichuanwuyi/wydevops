#!/usr/bin/env bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PYTHONIOENCODING=UTF-8

#1.进入获取脚本所在的目录。
# shellcheck disable=SC2164
_selfRootDir=$(cd "$(dirname "$0")"; pwd)

#2.导入yaml函数库文件。
source "${_selfRootDir}/helper/yaml-helper.sh"
source "${_selfRootDir}/helper/docker-helper.sh"
source "${_selfRootDir}/helper/helm-helper.sh"
source "${_selfRootDir}/helper/map-loader.sh"
#3.引入全局变量及其默认值定义文件。
source "${_selfRootDir}/global-params.sh"

info "检测helm是否已安装..." "-n"
if command -v helm &> /dev/null; then
  info "已安装" "*"
elif [[ ! "${PATH}" =~ ^(.*)(:${HOME}/helm)(:|$) ]];then
  info "未安装" "*"
  warn "稍后wydevops会将helm安装到${HOME}/helm目录中，请将${HOME}/helm路径添加到系统环境变量PATH中"
  export PATH=${PATH}:${HOME}/helm
  info "重新加载当前脚本文件"
  #shellcheck disable=SC1090
  source "$0"
else
  info "暂未安装，稍后会自动安装" "*"
fi

# 临时文件注册表, error方法中要负责清除这些文件。
declare -A gTempFileRegTables
export gTempFileRegTables

export gTempFileDir
if [ ! -d "${gTempFileDir}" ];then
  mkdir -p "${gTempFileDir}"
fi

export gWorkMode
export gBuildPath
export gClearCachedParams
export gGlobalParamCacheFileName
export gArchTypes
export gPipelineScriptsDir
export gLanguage
export gCiCdYamlFileName
export gHelmBuildOutDir

parseOptions1 "${@}"

partLog "第一部分 初始化全局参数"

info "首次解析命令选项和传入参数"
#读取Jenkins环境变量BUILD_SCRIPT_ROOT。
[[ ! "${gBuildScriptRootDir}" ]] && gBuildScriptRootDir="${BUILD_SCRIPT_ROOT}"
info "gBuildScriptRootDir参数初始化：${gBuildScriptRootDir}"

source "${_selfRootDir}/plugins/plugin-manager.sh"

#流水线脚本所在的目录名称
gPipelineScriptsDir="${gBuildScriptRootDir}/pipeline-stages"
info "gPipelineScriptsDir参数初始化：${gPipelineScriptsDir}"

source "${gPipelineScriptsDir}/common/wydevops-extend-point.sh"
source "${gPipelineScriptsDir}/common/notify-extend-point.sh"
source "${gPipelineScriptsDir}/chain/dockerDeployParamReader.sh"
source "${gPipelineScriptsDir}/chain/extend-chain-manager.sh"

#全局参数初始化前扩展点：检查必须设置的全局参数。
invokeExtendPointFunc "onBeforeInitGlobalParams" "全局参数初始化前扩展点"

#删除_global_params.yaml文件
if [[ "${gClearCachedParams}" == "true" || "${gWorkMode}" == "jenkins"  ]];then
  rm -f "${gBuildPath}/${gGlobalParamCacheFileName}" ||true
  rm -f "${gBuildPath}/${gCiCdYamlFileName}" ||true
fi

if [[ -f "${gBuildPath}/${gGlobalParamCacheFileName}" && -f "${gBuildPath}/${gCiCdYamlFileName}" ]];then
  warn "从缓存文件中加载全局参数..."
  #从文件中加载缓存的全局参数的值
  loadGlobalParamsFromCacheFile
  #检查并创建缺失的全局目录
  _checkGlobalDirectory
elif [[ "${gLanguage}" != "shell" ]];then
  warn "完整执行全局参数初始化过程..."
  invokeExtendPointFunc "initGlobalParams" "全局参数初始化功能扩展点"
  invokeExtendPointFunc "onAfterInitGlobalParams" "全局参数初始化后扩展点"
  info "将初始化好的全局变量的值写入${gGlobalParamCacheFileName}缓存文件中"
  cacheGlobalParamsToFile
fi

info "删除${gHelmBuildOutDir}/${gArchTypes//\//-}/pushed-images.yaml文件"
rm -f "${gHelmBuildOutDir}/${gArchTypes//\//-}/pushed-images.yaml"

info "二次解析命令选项和传入参数"
parseOptions2 "${@}"

invokeExtendPointFunc "onValidateGlobalParams" "全局参数有效性检查扩展点"

info "执行CI/CD标准流程..."
source "${_selfRootDir}/cicd-entry.sh"

exit 0
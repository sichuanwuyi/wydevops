#!/usr/bin/env bash

#1.进入获取脚本所在的目录。
# shellcheck disable=SC2164
_selfRootDir=$(cd "$(dirname "$0")"; pwd)

#2.导入yaml函数库文件。
source "${_selfRootDir}/yaml-helper.sh"
source "${_selfRootDir}/docker-helper.sh"
source "${_selfRootDir}/helm-installer.sh"
source "${_selfRootDir}/map-loader.sh"
#3.引入全局变量及其默认值定义文件。
source "${_selfRootDir}/global-params.sh"

# 临时文件注册表, error方法中要负责清除这些文件。
declare -A gTempFileRegTables
export gTempFileRegTables

export gTempFileDir
if [ ! -d "${gTempFileDir}" ];then
  mkdir -p "${gTempFileDir}"
fi

export gChartRepoType
# shellcheck disable=SC1090
source "${_selfRootDir}/${gChartRepoType}-helm-helper.sh"

export gWorkMode
export gBuildPath
export gClearCachedParams
export gGlobalParamCacheFileName
export gArchTypes

partLog "第一部分 初始化全局参数"

info "首次解析命令选项和传入参数"
parseOptions1 "${@}"

#读取Jenkins环境变量BUILD_SCRIPT_ROOT。
[[ ! "${gBuildScriptRootDir}" ]] && gBuildScriptRootDir="${BUILD_SCRIPT_ROOT}"
info "gBuildScriptRootDir参数初始化：${gBuildScriptRootDir}"

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
if [[ "${gClearCachedParams}" == "true" ]];then
  rm -f "${gBuildPath}/${gGlobalParamCacheFileName}" ||true
fi

if [ -f "${gBuildPath}/${gGlobalParamCacheFileName}" ];then
  info "从文件中加载缓存的全局参数的值..."
  loadGlobalParamsFromCacheFile
else
  warn "完整执行全局参数初始化过程..."
  invokeExtendPointFunc "initGlobalParams" "全局参数初始化功能扩展点"
  invokeExtendPointFunc "onAfterInitGlobalParams" "全局参数初始化后扩展点"
  info "将初始化好的全局变量的值写入${gGlobalParamCacheFileName}缓存文件中"
  cacheGlobalParamsToFile
fi

info "二次解析命令选项和传入参数"
parseOptions2 "${@}"

info "执行CI/CD标准流程..."
source "${_selfRootDir}/cicd-entry.sh"
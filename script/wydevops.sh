#!/usr/bin/env bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PYTHONIOENCODING=UTF-8

if [ -z "${WYDEVOPS_LOG_LANGUAGE}" ];then
  #define language in log as en
  export WYDEVOPS_LOG_LANGUAGE="en"
fi

if [ -z "${WYDEVOPS_WORK_MODE}" ];then
  #define work mode as local
  export WYDEVOPS_WORK_MODE="local"
fi

# initialize global work mode variable
export gWorkMode="${WYDEVOPS_WORK_MODE}"

#1.进入获取脚本所在的目录。
#载入yaml-helper.sh文件时会载入log-helper.sh, _selfRootDir在log-helper.sh文件中被引用了。
# shellcheck disable=SC2164
_selfRootDir=$(cd "$(dirname "$0")"; pwd)

#2.导入yaml函数库文件。
if ! type -t "readParam" > /dev/null; then
  source "${_selfRootDir}/helper/yaml-helper.sh"
fi
source "${_selfRootDir}/helper/docker-helper.sh"
source "${_selfRootDir}/helper/helm-helper.sh"
source "${_selfRootDir}/helper/map-loader.sh"
source "${_selfRootDir}/helper/path-helper.sh"
#3.引入全局变量及其默认值定义文件。
source "${_selfRootDir}/global-params.sh"

export gDebugMode
export gBuildPath
export gPipelineScriptsDir
export gLanguage

# shellcheck disable=SC2145
parseOptions0 "${@}"
info "wydevops.sh.first.parse.options"

info "wydevops.sh.gDebugMode.value" "${gDebugMode}"
info "wydevops.sh.gLanguage.value" "${gLanguage}"
info "wydevops.sh.gBuildPath.value" "${gBuildPath}"

#读取Jenkins环境变量BUILD_SCRIPT_ROOT。
[[ ! "${gBuildScriptRootDir}" ]] && gBuildScriptRootDir="${BUILD_SCRIPT_ROOT}"
info "wydevops.sh.gBuildScriptRootDir.value" "${gBuildScriptRootDir}"

gPipelineScriptsDir="${gBuildScriptRootDir}/pipeline-stages"
info "wydevops.sh.gPipelineScriptsDir.value" "${gPipelineScriptsDir}"

source "${gPipelineScriptsDir}/common/secret-extend-point.sh"

info "wydevops.sh.detecting.helm" "" "-n"
if command -v helm &> /dev/null; then
  info "wydevops.sh.helm.installed" "" "*"
elif [[ ! ":${PATH}:" =~ :${HOME}/helm: ]]; then
  info "wydevops.sh.helm.not.installed" "" "*"
  warn "wydevops.sh.helm.install.later" "${HOME}"
  export PATH=${PATH}:${HOME}/helm
  info "wydevops.sh.reloading.script"
  #shellcheck disable=SC1090
  exec "$0" "$@"
else
  info "wydevops.sh.helm.auto.install.later" "" "*"
fi

# 临时文件注册表, error方法中要负责清除这些文件。
declare -A gTempFileRegTables
export gTempFileRegTables

export gTempFileDir
if [[ "${gTempFileDir}" && ! -d "${gTempFileDir}" ]];then
  mkdir -p "${gTempFileDir}"
fi

export gWorkMode
export gClearCachedParams
export gMultipleModelProject
export gForceCoverage
export gDeleteImageAfterBuilding
export gGlobalParamCacheFileName
export gArchTypes
export gCiCdYamlFileName
export gHelmBuildOutDir

info "wydevops.sh.second.parse.options"
parseOptions1 "${@}"
echo "---222---gDeleteImageAfterBuilding=${gDeleteImageAfterBuilding}---------"

partLog "wydevops.sh.part1.init.global.params"

source "${gBuildScriptRootDir}/plugins/plugin-manager.sh"
source "${gBuildScriptRootDir}/helper/ssh-helper.sh"

#加载需要的shell脚本文件
source "${gPipelineScriptsDir}/common/wydevops-extend-point.sh"
source "${gPipelineScriptsDir}/common/notify-extend-point.sh"
source "${gPipelineScriptsDir}/chain/dockerDeployParamReader.sh"
source "${gPipelineScriptsDir}/chain/extend-chain-manager.sh"

#全局参数初始化前扩展点：检查必须设置的全局参数。
invokeExtendPointFunc "onBeforeInitGlobalParams" "wydevops.sh.before.init.global.params.extend.point"

#删除_global_params.yaml文件
if [[ "${gClearCachedParams}" == "true" || "${gWorkMode}" == "jenkins"  ]];then
  rm -f "${gBuildPath}/${gGlobalParamCacheFileName}" ||true
  rm -f "${gBuildPath}/${gCiCdYamlFileName}" ||true
fi

if [[ -f "${gBuildPath}/${gGlobalParamCacheFileName}" && -f "${gBuildPath}/${gCiCdYamlFileName}" ]];then
  warn "wydevops.sh.loading.global.params.from.cache"
  #从文件中加载缓存的全局参数的值
  loadGlobalParamsFromCacheFile
  #检查并创建缺失的全局目录
  _checkGlobalDirectory
elif [[ "${gLanguage}" != "shell" ]];then
  warn "wydevops.sh.full.init.global.params"
  invokeExtendPointFunc "initGlobalParams" "wydevops.sh.init.global.params.extend.point"
  invokeExtendPointFunc "onAfterInitGlobalParams" "wydevops.sh.after.init.global.params.extend.point"
  info "wydevops.sh.caching.global.params" "${gGlobalParamCacheFileName}"
  cacheGlobalParamsToFile
fi

invokeExtendPointFunc "clearDeprecatedFiles" "wydevops.sh.clear.deprecated.files.extend.point"

info "wydevops.sh.third.parse.options"
parseOptions2 "${@}"

invokeExtendPointFunc "onValidateGlobalParams" "wydevops.sh.validate.global.params.extend.point"

info "wydevops.sh.executing.cicd.standard.flow"
#执行cicd标准流程
source "${_selfRootDir}/cicd-entry.sh"

# =================================================================
# Final Cleanup Step
# =================================================================
# After the main script execution, check if image cleanup is enabled.
pruneDanglingImage

exit 0
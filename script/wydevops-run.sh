#!/usr/bin/env bash

#本脚本允许传入两个参数：
# 第一个参数为wydevops源码目录,
# 第二个参数为需要打包的项目目录，
# 第三个参数为项目中的wydevops本地配置文件名称
# 后续参数就是wydevops.sh的命令行参数

if [ -z "${WYDEVOPS_LOG_LANGUAGE}" ];then
  #define language in log as en
  export WYDEVOPS_LOG_LANGUAGE="en"
fi

if [ -z "${WYDEVOPS_WORK_MODE}" ];then
  #define work mode as local
  export WYDEVOPS_WORK_MODE="local"
fi

if [ -z "${ENABLE_CLEAR_CACHED_PARAMS}" ];then
  export ENABLE_CLEAR_CACHED_PARAMS=true
fi

if [ -z "${ENABLE_NOTIFY}" ];then
  export ENABLE_NOTIFY=true
fi

if [ -z "${ENABLE_FORCE_COVERAGE}" ];then
  export ENABLE_FORCE_COVERAGE=true
fi

if [ -z "${ENABLE_REMOVE_IMAGE}" ];then
  export ENABLE_REMOVE_IMAGE=true
fi

if [ -z "${SHOW_HELP}" ];then
  export SHOW_HELP=false
fi

if [ -z "${SHOW_VERSION}" ];then
  export SHOW_VERSION=false
fi

if [ -z "${ENABLE_DEBUG}" ];then
  export ENABLE_DEBUG=false
fi

# The home directory for all wydevops related files and scripts.
# In a cross-platform Bash environment (like Git Bash), always use forward slashes for internal logic.
_WYDEVOPS_HOME="${1}"
if [ ! "${_WYDEVOPS_HOME}" ];then
  _WYDEVOPS_HOME="${WYDEVOPS_HOME:=${HOME}/.wydevops}"
fi
# Normalize the path to handle various inputs (e.g., from Windows env vars)
# 1. Replace all backslashes with forward slashes.
_WYDEVOPS_HOME="${_WYDEVOPS_HOME//\\//}"
# 2. Remove the drive letter colon (e.g., C:) to create a POSIX-style path (/c/...).
_WYDEVOPS_HOME="${_WYDEVOPS_HOME//:/}"
# 3. Ensure the path is absolute in the context of MSYS/Git Bash.
if [[ ! "${_WYDEVOPS_HOME}" =~ ^\/ ]];then
  _WYDEVOPS_HOME="/${_WYDEVOPS_HOME}"
fi

# The shared local directory where the scripts will be cloned.
_WYDEVOPS_SOURCE_DIR="${_WYDEVOPS_HOME}/wydevops"
_SCRIPTS_ROOT_DIR="${_WYDEVOPS_SOURCE_DIR}/script"

export _selfRootDir="${_SCRIPTS_ROOT_DIR}"

# shellcheck disable=SC1090
source "${_SCRIPTS_ROOT_DIR}/helper/log-helper.sh"
# shellcheck disable=SC1090
source "${_SCRIPTS_ROOT_DIR}/helper/yaml-helper.sh"

# Get the home directory for the project.
_TARGET_PROJECT_HOME="${2}"
if [ ! "${_TARGET_PROJECT_HOME}" ];then
  # shellcheck disable=SC2153
  _TARGET_PROJECT_HOME="${TARGET_PROJECT_HOME}"
fi

if [ ! "${_TARGET_PROJECT_HOME}" ];then
  _TARGET_PROJECT_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -L)"
  if [ "${_TARGET_PROJECT_HOME}" == "${_SCRIPTS_ROOT_DIR}" ];then
    error "wydevops.run.sh.target.project.home.not.set"
  fi
fi

if [ ! -f "${_TARGET_PROJECT_HOME}/wydevops-run.sh" ];then
  info "wydevops.run.sh.copying.wydevops.run.sh.to.project.home" "${_TARGET_PROJECT_HOME}"
  cp -f "${_SCRIPTS_ROOT_DIR}/wydevops-run.sh" "${_TARGET_PROJECT_HOME}/wydevops-run.sh"
  exec "${_TARGET_PROJECT_HOME}/wydevops-run.sh" "${@}"
  exit 0
fi

# Delete the first three parameters.
_param=("${@}")
_param_count=${#_param[@]}
_remaining_params=()
if [ "${_param_count}" -gt 3 ];then
  _remaining_params=("${_param[@]:3}")
fi

_cmdFlags=""
[[ "${ENABLE_CLEAR_CACHED_PARAMS}" == "true" ]] && _cmdFlags="${_cmdFlags} -c"
[[ "${ENABLE_NOTIFY}" == "true" ]] && _cmdFlags="${_cmdFlags} -n"
[[ "${ENABLE_FORCE_COVERAGE}" == "true" ]] && _cmdFlags="${_cmdFlags} -f"
[[ "${ENABLE_REMOVE_IMAGE}" == "true" ]] && _cmdFlags="${_cmdFlags} -r"
[[ "${SHOW_HELP}" == "true" ]] && _cmdFlags="${_cmdFlags} -h"
[[ "${SHOW_VERSION}" == "true" ]] && _cmdFlags="${_cmdFlags} -v"
[[ "${ENABLE_DEBUG}" == "true" ]] && _cmdFlags="${_cmdFlags} -d"
_cmdFlags="${_cmdFlags:1}"
_cmdFlagParams=("${_cmdFlags}")

#The following bash lines will be automatically updated into the project's wydevops-run.sh file.
#Subsequent lines will be intelligently merged into the file's content according to the following rules:
#1. New parameter lines will be merged into the project's wydevops-run.sh file.
#2. If parameter values in the project's wydevops-run.sh file have been modified, the modified values will be preserved.
# shellcheck disable=SC2068
# shellcheck disable=SC2145
bash "${_SCRIPTS_ROOT_DIR}/wydevops.sh" ${_cmdFlagParams[@]} --localConfigFile "${3:-ci-cd-config.yaml}" -C "${CHART_REPO_CONFIG}" -D "${DOCKER_REPO_CONFIG}" -M "${WYDEVOPS_WORK_MODE}" -I "${IMAGE_LOCAL_CACHE_DIR}" -L java -P "${_TARGET_PROJECT_HOME}" -T true -W "${_SCRIPTS_ROOT_DIR}" ${_remaining_params[@]}
#-e -f -m -c \
#-A linux/amd64 \
#-O linux/amd64 \
#-B single \
#-I /d/cachedImage \
#-L java \
#-T true \
#-S build,docker,chart,package,deploy
#-C "harbor,chartmuseum,192.168.1.214:80,admin,Harbor12345,80" \
#-D "harbor,wydevops,192.168.1.214:80,admin,Harbor12345,80"
#-C "nexus,chartmuseum,192.168.1.214:8081,admin,Wpl118124,8081" \
#-D "nexus,wydevops,192.168.1.214:8002,admin,Wpl118124,8081"
#-D "registry,wydevops,192.168.1.218:30783,admin,admin123,30784,true,docker-registry /etc/docker/registry/config.yml"

#!/usr/bin/env bash

# --- Helper for colored output ---
Color_Off='\033[0m'
BBlue='\033[1;34m'

if [ -z "${WYDEVOPS_LOG_LANGUAGE}" ];then
  #define language in log as en
  export WYDEVOPS_LOG_LANGUAGE="en"
fi

if [ -z "${WYDEVOPS_WORK_MODE}" ];then
  #define work mode as local
  export WYDEVOPS_WORK_MODE="local"
fi


# The home directory for all wydevops related files and scripts.
# In a cross-platform Bash environment (like Git Bash), always use forward slashes for internal logic.
_WYDEVOPS_HOME="${WYDEVOPS_HOME:=${HOME}/.wydevops}"
# Normalize the path to handle various inputs (e.g., from Windows env vars)
# 1. Replace all backslashes with forward slashes.
_WYDEVOPS_HOME="${_WYDEVOPS_HOME//\\//}"
# 2. Remove the drive letter colon (e.g., C:) to create a POSIX-style path (/c/...).
_WYDEVOPS_HOME="${_WYDEVOPS_HOME//:/}"
# 3. Ensure the path is absolute in the context of MSYS/Git Bash.
if [[ ! "${_WYDEVOPS_HOME}" =~ ^\/ ]];then
  _WYDEVOPS_HOME="/${_WYDEVOPS_HOME}"
fi
#echo -e "${BBlue}_WYDEVOPS_HOME=${_WYDEVOPS_HOME}${Color_Off}"

# The shared local directory where the scripts will be cloned.
_SCRIPTS_PROJECT_DIR="${_WYDEVOPS_HOME}/wydevops"
#echo -e "${BBlue}_SCRIPTS_PROJECT_DIR=${_SCRIPTS_PROJECT_DIR}${Color_Off}"

_SCRIPTS_ROOT_DIR="${_SCRIPTS_PROJECT_DIR}/script"
#echo -e "${BBlue}_SCRIPTS_ROOT_DIR=${_SCRIPTS_ROOT_DIR}${Color_Off}"

export _selfRootDir="${_SCRIPTS_ROOT_DIR}"

# shellcheck disable=SC1090
source "${_SCRIPTS_ROOT_DIR}/helper/log-helper.sh"
# shellcheck disable=SC1090
source "${_SCRIPTS_ROOT_DIR}/helper/yaml-helper.sh"

export g_update_occurred="false"
# shellcheck disable=SC1090
source "${_SCRIPTS_ROOT_DIR}/wydevops-update.sh"

# --- Self-update logic (Final Intelligent Merge) ---
# This logic runs if the `wydevops-update.sh` script detected a git update.
if [[ "${g_update_occurred}" == "true" ]]; then
  combineCurrentFile "${_SCRIPTS_ROOT_DIR}/wydevops-run.sh" "${BASH_SOURCE[0]}" "$@"
fi
# --- End of self-update logic ---

# 获取当前脚本所在目录的绝对路径（解析符号链接）。实际就是目标项目的根目录。
_SELF_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -L)"
#echo -e "${BBlue}_SELF_SCRIPT_DIR=${_SELF_SCRIPT_DIR}${Color_Off}"

#允许传入两个参数：第一个参数为项目目录，第二个参数为本地配置文件名称

bash "${_SCRIPTS_ROOT_DIR}/wydevops.sh" \
-e -f -m \
--localConfigFile "${2:-ci-cd-config.yaml}" \
-A linux/amd64 \
-O linux/amd64 \
-B single \
-I /d/cachedImage \
-L java \
-S build,docker,chart,package,deploy \
-M "${WYDEVOPS_WORK_MODE}" \
-T true \
-P "${_SELF_SCRIPT_DIR}" \
-W "${_SCRIPTS_ROOT_DIR}"
#-C "harbor,chartmuseum,192.168.1.214:80,admin,Harbor12345,80" \
#-D "harbor,registry.docker.home,192.168.1.214:80,admin,Harbor12345,80"
#-C "nexus,chartmuseum,192.168.1.214:8081,admin,Wpl118124,8081" \
#-D "nexus,registry.docker.home,192.168.1.214:8002,admin,Wpl118124,8081"
#-D "registry,wydevops,192.168.1.218:30783,admin,admin123,30784,true,docker-registry /etc/docker/registry/config.yml"

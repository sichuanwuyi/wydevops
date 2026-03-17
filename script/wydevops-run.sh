#!/usr/bin/env bash

# --- Helper for colored output ---
Color_Off='\033[0m'
BBlue='\033[1;34m'

if [ -z "$LOG_LANUAGE" ];then
  #define language in log as zh-CN
  export LOG_LANGUAGE="zh"
fi

# The home directory for all wydevops related files and scripts.
_WYDEVOPS_HOME="${WYDEVOPS_HOME:=$HOME/.wydevops}"
echo -e "${BBlue}_WYDEVOPS_HOME=${_WYDEVOPS_HOME}${Color_Off}"
# The shared local directory where the scripts will be cloned.
_SCRIPTS_PROJECT_DIR="${_WYDEVOPS_HOME}/wydevops"
echo -e "${BBlue}_SCRIPTS_PROJECT_DIR=${_SCRIPTS_PROJECT_DIR}${Color_Off}"
_SCRIPTS_ROOT_DIR="${_SCRIPTS_PROJECT_DIR}/script"
echo -e "${BBlue}_SCRIPTS_ROOT_DIR=${_SCRIPTS_ROOT_DIR}${Color_Off}"

_selfRootDir="${_SCRIPTS_ROOT_DIR}"
source "${_SCRIPTS_ROOT_DIR}/helper/log-helper.sh"
source "${_SCRIPTS_ROOT_DIR}/helper/yaml-helper.sh"
source "${_SCRIPTS_ROOT_DIR}/wydevops-update.sh"

# --- Self-update logic (Intelligent Merge) ---
# This logic only runs if the `wydevops-update.sh` script detected a git update.
if [[ "${g_update_occurred}" == "true" ]]; then
    info "Git update detected. Checking for wydevops-run.sh script updates..."

    l_latest_run_script="${_SCRIPTS_ROOT_DIR}/wydevops-run.sh"
    l_current_run_script=$(readlink -f "${BASH_SOURCE[0]}")

    # Dynamically find the boundary line (the last line starting with "bash ") in both scripts.
    l_latest_boundary_line=$(grep -n "^bash " "${l_latest_run_script}" | tail -1 | cut -d: -f1)
    l_current_boundary_line=$(grep -n "^bash " "${l_current_run_script}" | tail -1 | cut -d: -f1)

    # Proceed only if the boundary is found in the latest script.
    if [[ -n "${l_latest_boundary_line}" ]]; then
        info "Merging local parameter values into the latest script template..."

        l_merged_script="${l_current_run_script}.merged.tmp"

        # 1. Write the header from the latest script (the template) to the new merged script.
        # This includes the `bash ...` line itself.
        sed -n "1,${l_latest_boundary_line}p" "${l_latest_run_script}" > "${l_merged_script}"

        # 2. Extract the parameter blocks from both scripts for processing.
        # The parameter block is everything AFTER the boundary line.
        l_latest_params=$(sed "1,${l_latest_boundary_line}d" "${l_latest_run_script}")
        l_local_params=$(sed "1,${l_current_boundary_line}d" "${l_current_run_script}")

        # 3. Iterate through each line of the LATEST script's parameter block.
        echo "${l_latest_params}" | while IFS= read -r l_template_line; do
            # Skip empty lines.
            if [[ -z "${l_template_line}" ]]; then
                continue
            fi

            # Get the parameter key (the first word, e.g., "-P", "#-C", "--localConfigFile").
            l_param_key=$(echo "${l_template_line}" | awk '{print $1}')

            # Base key is the key without the leading comment, used for searching.
            l_base_key=$(echo "${l_param_key}" | sed 's/^#//')

            # Search for a line in the LOCAL params that starts with this key (commented or not).
            l_local_line=$(echo "${l_local_params}" | grep -m 1 -E "^[[:space:]]*(#?${l_base_key})[[:space:]]")

            if [[ -n "${l_local_line}" ]]; then
                # FOUND: The user has this parameter locally. Use the local line to preserve their value.
                echo "${l_local_line}" >> "${l_merged_script}"
            else
                # NOT FOUND: This is a new parameter from the template. Use the template line.
                echo "${l_template_line}" >> "${l_merged_script}"
            fi
        done

        # 4. Atomically replace the current script with the newly merged one.
        mv "${l_merged_script}" "${l_current_run_script}"
        chmod +x "${l_current_run_script}"

        info "wydevops-run.sh has been intelligently updated. Restarting script..."
        exec "${l_current_run_script}" "$@"
    fi
fi
# --- End of self-update logic ---

source "${_SCRIPTS_ROOT_DIR}/helper/path-helper.sh"

# 获取当前脚本所在目录的绝对路径（解析符号链接）。实际就是目标项目的根目录。
_SELF_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
echo -e "${BBlue}_SELF_SCRIPT_DIR=${_SELF_SCRIPT_DIR}${Color_Off}"

#允许传入两个参数：第一个参数为项目目录，第二个参数为本地配置文件名称

#定义当前项目主模块目录路径:
_MODULE_DIR=$(win2linux "${1:-$_SELF_SCRIPT_DIR}")
_PROJECT_MAIN_MODULE_DIR=$(realpath -m -- "${_MODULE_DIR}")

bash "${_SCRIPTS_ROOT_DIR}/wydevops.sh" -e -f -m -c \
--localConfigFile "${2:-ci-cd-config.yaml}" \
-A linux/amd64 \
-O linux/amd64 \
-B single \
-I /d/cachedImage \
-L java \
-S build,docker,chart,package,deploy \
-M local \
-T true \
-Z ddd \
-P "${_PROJECT_MAIN_MODULE_DIR}" \
-W "${_SCRIPTS_ROOT_DIR}"
#-C "harbor,chartmuseum,192.168.1.214:80,admin,Harbor12345,80" \
#-0 ddddddddddddddd
#-D "harbor,registry.docker.home,192.168.1.214:80,admin,Harbor12345,80"
#-C "nexus,chartmuseum,192.168.1.214:8081,admin,Wpl118124,8081" \
#-D "nexus,registry.docker.home,192.168.1.214:8002,admin,Wpl118124,8081"
#-D "registry,wydevops,192.168.1.218:30783,admin,admin123,30784,true,docker-registry /etc/docker/registry/config.yml"
#钱钱钱钱钱钱钱钱钱钱钱钱钱
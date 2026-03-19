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
_WYDEVOPS_HOME="${WYDEVOPS_HOME:=$HOME/.wydevops}"
echo -e "${BBlue}_WYDEVOPS_HOME=${_WYDEVOPS_HOME}${Color_Off}"
# The shared local directory where the scripts will be cloned.
_SCRIPTS_PROJECT_DIR="${_WYDEVOPS_HOME}/wydevops"
echo -e "${BBlue}_SCRIPTS_PROJECT_DIR=${_SCRIPTS_PROJECT_DIR}${Color_Off}"
_SCRIPTS_ROOT_DIR="${_SCRIPTS_PROJECT_DIR}/script"
echo -e "${BBlue}_SCRIPTS_ROOT_DIR=${_SCRIPTS_ROOT_DIR}${Color_Off}"

_selfRootDir="${_SCRIPTS_ROOT_DIR}"
export g_update_occurred=false

source "${_SCRIPTS_ROOT_DIR}/helper/log-helper.sh"
source "${_SCRIPTS_ROOT_DIR}/helper/yaml-helper.sh"
source "${_SCRIPTS_ROOT_DIR}/wydevops-update.sh"

# --- Self-update logic (Final Intelligent Merge) ---
# This logic runs if the `wydevops-update.sh` script detected a git update.
if [[ "${g_update_occurred}" == "true" ]]; then
    info "Git update detected. Merging local configurations into the latest wydevops-run.sh..."

    l_latest_run_script="${_SCRIPTS_ROOT_DIR}/wydevops-run.sh"
    l_current_run_script=$(readlink -f "${BASH_SOURCE[0]}")

    # Find the boundary line (last line starting with "bash ") in the template script.
    l_latest_boundary_line=$(grep -n "^bash " "${l_latest_run_script}" | tail -1 | cut -d: -f1)

    # Proceed only if the boundary is found in the latest script (the template).
    if [[ -n "${l_latest_boundary_line}" ]]; then
        l_merged_script="${l_current_run_script}.merged.tmp"

        # 1. Write the header from the template (up to and including the bash line).
        sed -n "1,${l_latest_boundary_line}p" "${l_latest_run_script}" > "${l_merged_script}"

        # 2. Prepare parameter blocks for merging.
        l_template_params=$(sed "1,${l_latest_boundary_line}d" "${l_latest_run_script}")
        l_current_boundary_line=$(grep -n "^bash " "${l_current_run_script}" | tail -1 | cut -d: -f1)
        l_local_params=$(sed "1,${l_current_boundary_line}d" "${l_current_run_script}")

        # 3. Iterate through the TEMPLATE's parameter block to build the new parameter section.
        echo "${l_template_params}" | while IFS= read -r l_template_line; do
            # Handle empty lines in the template by preserving them.
            if ! [[ "${l_template_line}" =~ [^[:space:]] ]]; then
                echo "" >> "${l_merged_script}"
                continue
            fi

            # If the template line is a comment, keep it as is.
            if [[ "${l_template_line}" =~ ^[[:space:]]*# ]]; then
                echo "${l_template_line}" >> "${l_merged_script}"
                continue
            fi

            # It's a parameter line. Get the key (e.g., -P, --localConfigFile).
            l_param_key=$(echo "${l_template_line}" | awk '{print $1}')

            # Search for a NON-COMMENTED line in the LOCAL params that starts with this key.
            l_local_line=$(echo "${l_local_params}" | grep -m 1 -E "^[[:space:]]*${l_param_key}[[:space:]]")

            if [[ -n "${l_local_line}" ]]; then
                # FOUND: Use the local line to preserve the user's custom value.
                echo "${l_local_line}" >> "${l_merged_script}"
            else
                # NOT FOUND: This is a new or unchanged parameter. Use the template's line.
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
-P "${_PROJECT_MAIN_MODULE_DIR}" \
-W "${_SCRIPTS_ROOT_DIR}"
#-C "harbor,chartmuseum,192.168.1.214:80,admin,Harbor12345,80" \
#-D "harbor,registry.docker.home,192.168.1.214:80,admin,Harbor12345,80"
#-C "nexus,chartmuseum,192.168.1.214:8081,admin,Wpl118124,8081" \
#-D "nexus,registry.docker.home,192.168.1.214:8002,admin,Wpl118124,8081"
#-D "registry,wydevops,192.168.1.218:30783,admin,admin123,30784,true,docker-registry /etc/docker/registry/config.yml"

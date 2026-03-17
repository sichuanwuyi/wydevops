#!/usr/bin/env bash

# --- Helper for colored output ---
Color_Off='\033[0m'
BBlue='\033[1;34m'

if [ -z "$LOG_LANUAGE" ];then
  #define language in log as zh-CN
  export LOG_LANGUAGE="en"
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

# --- Self-update logic (Conditional, Dynamic & Robust) ---
# This logic only runs if the `wydevops-update.sh` script detected a git update.
if [[ "${g_update_occurred}" == "true" ]]; then
    # After updating, check if the core logic of this script has changed.
    l_latest_run_script="${_SCRIPTS_ROOT_DIR}/wydevops-run.sh"
    # It's possible that BASH_SOURCE[0] is a relative path, so we get the absolute path.
    l_current_run_script=$(readlink -f "${BASH_SOURCE[0]}")

    # Dynamically determine the boundary line for both scripts.
    # The boundary is the line where the final `bash` command execution starts.
    l_latest_boundary_line=$(grep -n "^bash " "${l_latest_run_script}" | tail -1 | cut -d: -f1)
    l_current_boundary_line=$(grep -n "^bash " "${l_current_run_script}" | tail -1 | cut -d: -f1)

    # If a boundary line is found in both scripts, proceed with the comparison.
    if [[ -n "${l_latest_boundary_line}" && -n "${l_current_boundary_line}" ]]; then
        # The header is everything BEFORE the boundary line.
        l_latest_header_end_line=$((l_latest_boundary_line - 1))
        l_current_header_end_line=$((l_current_boundary_line - 1))

        # Compare the headers using Process Substitution.
        if ! cmp -s <(sed -n "1,${l_latest_header_end_line}p" "${l_latest_run_script}") <(sed -n "1,${l_current_header_end_line}p" "${l_current_run_script}"); then
            info "The core logic of wydevops-run.sh has been updated. Merging changes and restarting..."

            l_temp_new_script="${l_current_run_script}.tmp"

            # 1. Write the new header from the updated script to the temp file.
            sed -n "1,${l_latest_header_end_line}p" "${l_latest_run_script}" > "${l_temp_new_script}"

            # 2. Append the user-modified part (from the boundary line onwards) from the current script.
            sed "1,${l_current_header_end_line}d" "${l_current_run_script}" >> "${l_temp_new_script}"

            # 3. Atomically replace the current script with the merged one.
            mv "${l_temp_new_script}" "${l_current_run_script}"

            chmod +x "${l_current_run_script}"

            # Re-execute the script with all original arguments.
            exec "${l_current_run_script}" "$@"
        fi
    fi
fi
# --- End of self-update logic ---

source "${_SCRIPTS_ROOT_DIR}/helper/path-helper.sh"

# 获取当前脚本所在目录的绝对路径（解析符号链接）。实际就是目标项目的根目录。
_SELF_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
warn "_SELF_SCRIPT_DIR=${_SELF_SCRIPT_DIR}"

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
-P "${_PROJECT_MAIN_MODULE_DIR}" \
-W "${_SCRIPTS_ROOT_DIR}"
#-C "harbor,chartmuseum,192.168.1.214:80,admin,Harbor12345,80" \
#-D "harbor,registry.docker.home,192.168.1.214:80,admin,Harbor12345,80"
#-C "nexus,chartmuseum,192.168.1.214:8081,admin,Wpl118124,8081" \
#-D "nexus,registry.docker.home,192.168.1.214:8002,admin,Wpl118124,8081"
#-D "registry,wydevops,192.168.1.218:30783,admin,admin123,30784,true,docker-registry /etc/docker/registry/config.yml"
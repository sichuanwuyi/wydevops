#!/usr/bin/env bash

# --- wydevops-bootstrap.sh ---
# This script acts as a smart bootstrapper. It ensures the correct version
# of the wydevops scripts for the specific client is available locally
# before executing the main pipeline.

# --- Helper for colored output ---
Color_Off='\033[0m'
BGreen='\033[1;32m'
BRed='\033[1;31m'
BBlue='\033[1;34m'

# --- Configuration ---
# The home directory for all wydevops related files and scripts.
_WYDEVOPS_HOME="${WYDEVOPS_HOME:=$HOME/.wydevops}"
echo -e "${BBlue}_WYDEVOPS_HOME=${_WYDEVOPS_HOME}${Color_Off}"
# The shared local directory where the scripts will be cloned.
_SCRIPTS_PROJECT_DIR="${_WYDEVOPS_HOME}/project"
echo -e "${BBlue}_SCRIPTS_PROJECT_DIR=${_SCRIPTS_PROJECT_DIR}${Color_Off}"
_SCRIPTS_ROOT_DIR="${_SCRIPTS_PROJECT_DIR}/script"
echo -e "${BBlue}_SCRIPTS_ROOT_DIR=${_SCRIPTS_ROOT_DIR}${Color_Off}"

# The local configuration file that specifies the git repo and branch.
_CLIENT_CONFIG_FILE="${_WYDEVOPS_HOME}/client-config.json"
echo -e "${BBlue}_CLIENT_CONFIG_FILE=${_CLIENT_CONFIG_FILE}${Color_Off}"

# --- Check for client configuration ---
if [ ! -f "$_CLIENT_CONFIG_FILE" ]; then
    echo -e "${BRed}Error: Client configuration not found at '$_CLIENT_CONFIG_FILE'.${Color_Off}"
    echo "Please create it with your repository URL and branch name. Example:"
    echo '{'
    echo '  "repoUrl": "https://github.com/your-username/wydevops.git",'
    echo '  "branch": "client-a-feature-branch"'
    echo '}'
    exit 1
fi

# --- Read configuration using jq (a lightweight JSON processor) ---
# Ensure jq is installed: sudo apt-get install jq / brew install jq
if ! command -v jq &> /dev/null; then
    echo -e "${BRed}Error: 'jq' is not installed. Please install it to parse the client configuration.${Color_Off}"
    exit 1
fi

REPO_URL=$(jq -r '.repoUrl' "$_CLIENT_CONFIG_FILE")
BRANCH=$(jq -r '.branch' "$_CLIENT_CONFIG_FILE")

echo -e "${BBlue}Bootstrapper: Preparing to run wydevops...${Color_Off}"
echo "  - Repository: $REPO_URL"
echo "  - Branch:     $BRANCH"

# --- Sync the scripts from Git repository ---
if [ -d "$_SCRIPTS_PROJECT_DIR/.git" ]; then
    # If directory exists and is a git repo, pull the latest changes.
    echo "Syncing existing scripts..."
    cd "$_SCRIPTS_PROJECT_DIR"
    git checkout "$BRANCH" --quiet
    git pull origin "$BRANCH"
    cd - > /dev/null
else
    # If directory doesn't exist, clone the specific branch.
    echo "Cloning scripts for the first time..."
    git clone --branch "$BRANCH" "$REPO_URL" "$_SCRIPTS_PROJECT_DIR"
fi

echo -e "${BGreen}Scripts are up to date.${Color_Off}"
echo "--------------------------------------------------"

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
-P "${_PROJECT_MAIN_MODULE_DIR}" \
-W "${_SCRIPTS_ROOT_DIR}"
#-C "harbor,chartmuseum,192.168.1.214:80,admin,Harbor12345,80" \
#-D "harbor,registry.docker.home,192.168.1.214:80,admin,Harbor12345,80"
#-C "nexus,chartmuseum,192.168.1.214:8081,admin,Wpl118124,8081" \
#-D "nexus,registry.docker.home,192.168.1.214:8002,admin,Wpl118124,8081"
#-D "registry,wydevops,192.168.1.218:30783,admin,admin123,30784,true,docker-registry /etc/docker/registry/config.yml"
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

_SPLIT_CHAR="\\"
if [[ "${HOME}" =~ ^/ ]];then
  _SPLIT_CHAR="/"
fi

# --- Configuration ---
# The home directory for all wydevops related files and scripts.
if [ ! "${_WYDEVOPS_HOME}" ];then
  _WYDEVOPS_HOME="${WYDEVOPS_HOME:=${HOME}${_SPLIT_CHAR}.wydevops}"
  echo -e "${BBlue}_WYDEVOPS_HOME=${_WYDEVOPS_HOME}${Color_Off}"
fi

if [ ! "${_SCRIPTS_PROJECT_DIR}" ];then
  # The shared local directory where the scripts will be cloned.
  _SCRIPTS_PROJECT_DIR="${_WYDEVOPS_HOME}${_SPLIT_CHAR}wydevops"
  echo -e "${BBlue}_SCRIPTS_PROJECT_DIR=${_SCRIPTS_PROJECT_DIR}${Color_Off}"
fi

if [ ! "${_SCRIPTS_ROOT_DIR}" ];then
  _SCRIPTS_ROOT_DIR="${_SCRIPTS_PROJECT_DIR}${_SPLIT_CHAR}script"
  echo -e "${BBlue}_SCRIPTS_ROOT_DIR=${_SCRIPTS_ROOT_DIR}${Color_Off}"
fi

# The local configuration file that specifies the git repo and branch.
_CLIENT_CONFIG_FILE="${_WYDEVOPS_HOME}${_SPLIT_CHAR}client-config.yaml"
echo -e "${BBlue}_CLIENT_CONFIG_FILE=${_CLIENT_CONFIG_FILE}${Color_Off}"

# --- Check for client configuration ---
if [ ! -f "$_CLIENT_CONFIG_FILE" ]; then
    echo -e "${BRed}Error: Client configuration not found at '$_CLIENT_CONFIG_FILE'.${Color_Off}"
    echo "Please create it with your repository URL and branch name. Example:"
    echo 'git:'
    echo '  repoUrl: https://gitee.com/tmt_china/wydevops.git'
    echo '  branch: master'
    exit 1
fi

export gDefaultRetVal

readParam "$_CLIENT_CONFIG_FILE" "git.repoUrl"
REPO_URL="${gDefaultRetVal}"

readParam "$_CLIENT_CONFIG_FILE" "git.branch"
BRANCH="${gDefaultRetVal}"

echo -e "${BBlue}Bootstrapper: Preparing to run wydevops...${Color_Off}"
echo "  - Repository: $REPO_URL"
echo "  - Branch:     $BRANCH"

# Initialize a flag to track if an update occurred.
export g_update_occurred=false

# --- Sync the scripts from Git repository ---
if [ -d "${_SCRIPTS_PROJECT_DIR}${_SPLIT_CHAR}.git" ]; then
    # If directory exists and is a git repo, pull the latest changes.
    info "Syncing existing scripts..."
    cd "${_SCRIPTS_PROJECT_DIR}" || exit

    # Get the commit hash before pulling.
    l_before_hash=$(git rev-parse HEAD)

    git checkout "$BRANCH" --quiet
    # Execute git pull and check its exit code for robustness.
    if git pull origin "$BRANCH"; then
        # Pull was successful, now check if the content actually changed.
        l_after_hash=$(git rev-parse HEAD)
        if [[ "${l_before_hash}" != "${l_after_hash}" ]]; then
            info "Git repository was updated."
            g_update_occurred=true
        fi
    else
        # git pull failed (e.g., network error).
        warn "Failed to pull from git repository. Continuing with the local version."
        g_update_occurred=false
    fi

    # shellcheck disable=SC2164
    # shellcheck disable=SC2103
    cd - > /dev/null
fi

echo -e "${BGreen}Scripts are up to date.${Color_Off}"
echo "--------------------------------------------------"

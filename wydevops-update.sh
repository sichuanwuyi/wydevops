#!/usr/bin/env bash
# =================================================================
# wydevops-update.sh
#
# This script ensures that the wydevops code is up-to-date.
# It runs automatically at the start of the container.
#
# Logic:
# 1. Read git config from client-config.yaml.
# 2. Fallback to ENV variables if config is missing.
# 3. If the target directory is empty, clone the repo.
# 4. If the directory exists, check if the remote URL has changed.
#    - If URL changed, remove the old repo and re-clone from the new URL.
#    - If URL is the same, fetch and reset to the latest version.
# =================================================================

# --- Helper for colored output ---
_Color_Off='\033[0m'
_BGreen='\033[1;32m'
_BRed='\033[1;31m'
_BBlue='\033[1;34m'

# --- Configuration ---
# The home directory for all wydevops related files and scripts.
if [ ! "${_WYDEVOPS_HOME}" ];then
  _WYDEVOPS_HOME="${WYDEVOPS_HOME:=${HOME}/.wydevops}"
  _WYDEVOPS_HOME="${_WYDEVOPS_HOME//\\//}"
  _WYDEVOPS_HOME="${_WYDEVOPS_HOME//:/}"
  if [[ ! "${_WYDEVOPS_HOME}" =~ ^\/ ]];then
    _WYDEVOPS_HOME="/${_WYDEVOPS_HOME}"
  fi
fi

if [ ! "${_SCRIPTS_PROJECT_DIR}" ];then
  # The shared local directory where the scripts will be cloned.
  _SCRIPTS_PROJECT_DIR="${_WYDEVOPS_HOME}/wydevops"
fi

if [ ! "${_SCRIPTS_ROOT_DIR}" ];then
  _SCRIPTS_ROOT_DIR="${_SCRIPTS_PROJECT_DIR}/script"
fi

# --- Fallback values from environment variables (set in Dockerfile) ---
_FALLBACK_GIT_REPO_URL="${GIT_REPO_URL:-https://gitee.com/tmt_china/wydevops.git}"
_FALLBACK_GIT_BRANCH="${GIT_BRANCH:-master}"

# The local configuration file that specifies the git repo and branch.
_CLIENT_CONFIG_FILE="${_WYDEVOPS_HOME}/client-config.yaml"
# --- Check for client configuration ---
if [ -f "$_CLIENT_CONFIG_FILE" ]; then
  export gDefaultRetVal
  readParam "$_CLIENT_CONFIG_FILE" "git.repoUrl"
  GIT_REPO_URL="${gDefaultRetVal}"
  readParam "$_CLIENT_CONFIG_FILE" "git.branch"
  GIT_BRANCH="${gDefaultRetVal}"
  readParam "$_CLIENT_CONFIG_FILE" "git.username"
  _GIT_USERNAME="${gDefaultRetVal}"
  readParam "$_CLIENT_CONFIG_FILE" "git.password"
  _GIT_PASSWORD="${gDefaultRetVal}"
else
  # shellcheck disable=SC2034
  GIT_REPO_URL=""
  GIT_BRANCH=""
fi

# --- Determine final Git settings ---
# If config values are empty or "null", use fallbacks.
_FINAL_REPO_URL=${GIT_REPO_URL:-${FALLBACK_GIT_REPO_URL}}
_FINAL_BRANCH=${GIT_BRANCH:-${FALLBACK_GIT_BRANCH}}

# --- Construct authenticated URL if credentials are provided ---
if [[ -n "$_GIT_USERNAME" && -n "$_GIT_PASSWORD" ]]; then
    # URL-encode username and password if needed (basic implementation)
    # For simplicity, we assume they don't contain special characters that need encoding.
    # A more robust solution might use 'jq -sRr @uri'.
    # shellcheck disable=SC2001
    _AUTH_REPO_URL=$(echo "$_FINAL_REPO_URL" | sed "s|://|://$_GIT_USERNAME:$_GIT_PASSWORD@|")
else
    _AUTH_REPO_URL="$_FINAL_REPO_URL"
fi

echo -e "${_BGreen}[INFO]: Target Git Repository: ${_FINAL_REPO_URL}${_Color_Off}"
echo -e "${_BGreen}[INFO]: Target Git Branch: ${_FINAL_BRANCH}${_Color_Off}"
echo -e "${_BGreen}[INFO]: Target Directory: ${_WYDEVOPS_HOME}${_Color_Off}"

# --- Main Logic ---
# Check if the target directory exists and is a git repository
if [ -d "$_WYDEVOPS_HOME/.git" ]; then
    echo "INFO: Git repository exists in $_WYDEVOPS_HOME."

    # Get the current remote URL
    _CURRENT_REMOTE_URL=$(git -C "$_WYDEVOPS_HOME" remote get-url origin)
    echo "INFO: Current remote URL: $_CURRENT_REMOTE_URL"

    # Compare current remote URL with the configured final URL
    if [ "$_CURRENT_REMOTE_URL" != "$_FINAL_REPO_URL" ]; then
        echo "WARN: Git remote URL has changed!"
        echo "INFO: Old URL: $_CURRENT_REMOTE_URL"
        echo "INFO: New URL: $_FINAL_REPO_URL"
        echo "INFO: Removing old repository and re-cloning..."

        # Remove the old directory completely to ensure a clean state
        rm -rf "${_WYDEVOPS_HOME:?}"/* "${_WYDEVOPS_HOME:?}"/.??*

        # Re-clone the repository
        git clone --depth 1 -b "$_FINAL_BRANCH" "$_AUTH_REPO_URL" "$_WYDEVOPS_HOME"

    else
        echo "INFO: Remote URL is correct. Fetching latest changes..."
        # Use the authenticated URL for fetching updates
        git -C "$_WYDEVOPS_HOME" remote set-url origin "$_AUTH_REPO_URL"

        # Fetch from origin and reset hard to the target branch
        # This discards any local changes and ensures the code is identical to the remote branch
        git -C "$_WYDEVOPS_HOME" fetch origin
        git -C "$_WYDEVOPS_HOME" reset --hard "origin/$_FINAL_BRANCH"
        echo "INFO: Successfully updated to the latest version of branch '$_FINAL_BRANCH'."
    fi

else
    echo "INFO: No git repository found in $_WYDEVOPS_HOME. Cloning for the first time..."
    # Ensure the directory exists but is empty
    mkdir -p "$_WYDEVOPS_HOME"

    # Clone the repository
    git clone --depth 1 -b "$_FINAL_BRANCH" "$_AUTH_REPO_URL" "$_WYDEVOPS_HOME"
fi

echo "INFO: wydevops code is up-to-date."

source "${_WYDEVOPS_HOME}/wydevops/script/wydevops-run.sh" "${@}"

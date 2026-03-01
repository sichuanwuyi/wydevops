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
if [ ! "${_WYDEVOPS_HOME}" ];then
  _WYDEVOPS_HOME="${WYDEVOPS_HOME:=$HOME/.wydevops}"
  echo -e "${BBlue}_WYDEVOPS_HOME=${_WYDEVOPS_HOME}${Color_Off}"
fi

if [ ! "${_SCRIPTS_PROJECT_DIR}" ];then
# The shared local directory where the scripts will be cloned.
_SCRIPTS_PROJECT_DIR="${_WYDEVOPS_HOME}/project"
echo -e "${BBlue}_SCRIPTS_PROJECT_DIR=${_SCRIPTS_PROJECT_DIR}${Color_Off}"
fi

if [ ! "${_SCRIPTS_ROOT_DIR}" ];then
_SCRIPTS_ROOT_DIR="${_SCRIPTS_PROJECT_DIR}/script"
echo -e "${BBlue}_SCRIPTS_ROOT_DIR=${_SCRIPTS_ROOT_DIR}${Color_Off}"
fi

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
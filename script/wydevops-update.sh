#!/usr/bin/env bash

function combineCurrentFile() {
  info "wydevops.update.sh.updating.wydevops-run.sh" "" "-n"
  l_latest_run_script="$1"
  l_current_run_script=$(readlink -f "$2")

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

      info "wydevops.update.sh.sync.scripts.success" "" "*"

      # 4. Atomically replace the current script with the newly merged one.
      mv "${l_merged_script}" "${l_current_run_script}"
      chmod +x "${l_current_run_script}"

      info "wydevops.update.sh.restart.wydevops-run.sh"

      l_params=("${@}")
      l_param_count=${#l_params[@]}
      l_remaining_params=()
      if [ "${l_param_count}" -gt 2 ];then
        l_remaining_params=("${l_params[@]:2}")
      fi
      exec "${l_current_run_script}" "${l_remaining_params[@]}"
      exit 0
  fi

  info "wydevops.update.sh.sync.scripts.fail" "" "*"
}

# --- wydevops-bootstrap.sh ---
# This script acts as a smart bootstrapper. It ensures the correct version
# of the wydevops scripts for the specific client is available locally
# before executing the main pipeline.

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

# The local configuration file that specifies the git repo and branch.
_CLIENT_CONFIG_FILE="${_WYDEVOPS_HOME}/client-config.yaml"

# --- Check for client configuration ---
if [ -f "$_CLIENT_CONFIG_FILE" ]; then
  export gDefaultRetVal
  readParam "$_CLIENT_CONFIG_FILE" "git.repoUrl"
  REPO_URL="${gDefaultRetVal}"
  readParam "$_CLIENT_CONFIG_FILE" "git.branch"
  BRANCH="${gDefaultRetVal}"
else
  # shellcheck disable=SC2034
  REPO_URL="https://gitee.com/tmt_china/wydevops.git"
  BRANCH="master"
fi

# Initialize a flag to track if an update occurred.
export g_update_occurred="false"

# --- Sync the scripts from Git repository ---
if [ -d "${_SCRIPTS_PROJECT_DIR}/.git" ]; then
  # If directory exists and is a git repo, pull the latest changes.
  info "wydevops.update.sh.sync.scripts.from.git.repository" "" "-n"
  cd "${_SCRIPTS_PROJECT_DIR}" || exit 111

  ls -a

  # Get the commit hash before pulling.
  l_before_hash=$(git rev-parse HEAD 2>&1)

  l_result=$(git checkout "$BRANCH" --quiet 2>&1)
  # Execute git pull and check its exit code for robustness.
  # shellcheck disable=SC2034
  l_result=$(git pull origin "$BRANCH" --quiet 2>&1)
  if [ "$?" -eq 0 ]; then
    info "wydevops.update.sh.sync.scripts.success" "" "*"
    # Pull was successful, now check if the content actually changed.
    l_after_hash=$(git rev-parse HEAD 2>&1)
    if [[ "${l_before_hash}" != "${l_after_hash}" ]]; then
      info "wydevops.update.sh.scripts.already.changed"
      g_update_occurred="true"
    else
      info "wydevops.update.sh.scripts.is.latest"
    fi
  else
    # git pull failed (e.g., network error).
    warn "wydevops.update.sh.sync.scripts.failed" "" "*"
  fi

  # shellcheck disable=SC2164
  # shellcheck disable=SC2103
  cd - > /dev/null
else
  warn "wydevops.update.sh.can.not.sync.scripts"
fi
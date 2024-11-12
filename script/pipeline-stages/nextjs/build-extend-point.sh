#!/usr/bin/env bash

function _onBeforeProjectBuilding_ex() {
  export gBuildPath
  export gMultipleModelProject

  info "进入项目主模块目录：${gBuildPath}"
  cd "${gBuildPath}" || true

  info "强行设置gMultipleModelProject变量为false"
  gMultipleModelProject="false"

  rm -rf .next || true
}

#执行java项目的编译
function _buildProject_ex() {
  info "构建整个项目..."
  _buildSubModule
}

#******************私有方法********************#

function _buildSubModule() {
  export gServiceName
  export gCurrentStageResult

  local l_errorLog
  local l_info

  info "检查pnpm的版本..."
  pnpm -v
  if [ "$?" -ne 0 ];then
    info "开始安装pnpm..."
    npm install -g pnpm
    pnpm -v
    if [ "$?" -ne 0 ];then
      error "安装pnpm失败"
    fi
  fi

  info "开始构建项目(pnpm run build)..."
  pnpm run build 2>&1 | tee "./build.tmp"
  # shellcheck disable=SC2002
  l_errorLog=$(cat "./build.tmp" | grep "Build failed")
  rm -f "./build.tmp" || true

  if [ "${l_errorLog}" ];then
    error "项目${gServiceName}编译失败"
  fi

  l_info="项目${gServiceName}编译成功：pnpm_run_build"
  gCurrentStageResult="INFO|${l_info}"
}

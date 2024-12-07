#!/usr/bin/env bash

function _onBeforeProjectBuilding_ex() {
  export gDefaultRetVal
  export gBuildPath
  export gMultipleModelProject

  info "进入项目主模块目录：${gBuildPath}"
  cd "${gBuildPath}" || true

  info "强行设置gMultipleModelProject变量为false"
  gMultipleModelProject="false"
}

#执行项目的编译
function _buildProject_ex() {
  info "跳过项目编译过程(在docker build过程中编译项目)..."
#  export gDefaultRetVal
#
#  local l_distDir
#  local l_startRowRegex="^(.*):[ ]*NextConfig[ ]*=[ ]*\{[ ]*$"
#
#  #获取nextjs项目next.config.ts文件中distDir参数的值。
#  getParamValueInJsonConfigFile "${gBuildPath}/next.config.ts" "${l_startRowRegex}" "distDir" ".next" "false"
#  l_distDir="${gDefaultRetVal}"
#
#  info "删除已经存在的${l_distDir}目录"
#  # shellcheck disable=SC2115
#  rm -rf "${gBuildPath}/${l_distDir}" || true
#  info "删除已经存在的node_modules目录"
#  rm -rf "${gBuildPath}/node_modules" || true
#
#  info "开始执行项目构建..."
#  _buildSubModule
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

  info "安装项目依赖库(pnpm i --frozen-lockfile)..."
  pnpm i --frozen-lockfile

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

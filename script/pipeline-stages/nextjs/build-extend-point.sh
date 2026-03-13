#!/usr/bin/env bash

function _onBeforeProjectBuilding_ex() {
  export gDefaultRetVal
  export gBuildPath
  export gMultipleModelProject

  info "nextjs.build.extend.point.entering.project.main.module.dir" "${gBuildPath}"
  cd "${gBuildPath}" || true

  info "nextjs.build.extend.point.setting.gmultiplemodelproject.to.false"
  gMultipleModelProject="false"
}

#执行项目的编译
function _buildProject_ex() {
  info "nextjs.build.extend.point.skipping.project.compilation"
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
  export gDefaultRetVal

  local l_info

  info "nextjs.build.extend.point.checking.pnpm.version"
  pnpm -v
  if [ "$?" -ne 0 ];then
    warn "nextjs.build.extend.point.failed" "" "*"
    info "nextjs.build.extend.point.installing.pnpm" "" "-n"
    npm install -g pnpm
    pnpm -v
    if [ "$?" -ne 0 ];then
      error "nextjs.build.extend.point.failed" "" "*"
    else
      info "nextjs.build.extend.point.success" "" "*"
    fi
  else
    info "nextjs.build.extend.point.success" "" "*"
  fi

  info "nextjs.build.extend.point.installing.dependencies"
  pnpm i --frozen-lockfile

  info "开nextjs.build.extend.point.building.project"
  if ! pnpm run build 2>&1;then
    error "nextjs.build.extend.point.project.compilation.failed" "${gServiceName}"
  fi

  convertI18NText "nextjs.build.extend.point.project.compilation.succeeded" "${gServiceName}"
  l_info=" ${gDefaultRetVal}"
  gCurrentStageResult="INFO|${l_info}"
}

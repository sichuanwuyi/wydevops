#!/usr/bin/env bash

function _onBeforeProjectBuilding_ex() {
  export gBuildPath
  export gMultipleModelProject

  info "vue.build.extend.point.entering.project.main.module.dir" "${gBuildPath}"
  cd "${gBuildPath}" || true

  info "vue.build.extend.point.setting.gmultiplemodelproject.to.false"
  gMultipleModelProject="false"
}

#执行项目的编译
function _buildProject_ex() {
  info "vue.build.extend.point.compiling.project"
  _buildSubModule
}

#******************私有方法********************#

function _buildSubModule() {
  export gServiceName
  export gCurrentStageResult
  export gLogI18NRetVal

  info "vue.build.extend.point.checking.pnpm.version" "" "-n"
  pnpm -v
  if [ "$?" -ne 0 ];then
    warn "vue.build.extend.point.failed" "" "*"
    info "vue.build.extend.point.installing.pnpm" "" "-n"
    npm install -g pnpm
    pnpm -v
    if [ "$?" -ne 0 ];then
      error "vue.build.extend.point.failed" "" "*"
    else
      info "vue.build.extend.point.success" "" "*"
    fi
  else
    info "vue.build.extend.point.success" "" "*"
  fi

  info "vue.build.extend.point.building.project"
  if ! pnpm run build 2>&1 ;then
    error "vue.build.extend.point.project.compilation.failed"
  fi

  convertI18NText "vue.build.extend.point.project.compilation.succeeded" "${gServiceName}"
  gCurrentStageResult="INFO|${gLogI18NRetVal}"
}








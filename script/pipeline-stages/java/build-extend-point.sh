#!/usr/bin/env bash

function _onBeforeProjectBuilding_ex() {
  export gBuildPath
  export gMultipleModelProject

  info "java.build.extend.point.entering.project.main.module.dir"
  cd "${gBuildPath}" || true

  if [ "${gMultipleModelProject}" == "true" ];then
    info "java.build.extend.point.multi.module.project.fallback"
    cd ..
  fi

  # --- Check and set JAVA_HOME if not defined ---
  if [ -z "$JAVA_HOME" ] || [ ! -d "$JAVA_HOME" ]; then
    # A more generic search could be added here if needed
    #error "Could not find a valid JDK installation. \n" \
    #      "Please ensure JAVA_HOME is set correctly for the script's execution environment."
    error "java.build.extend.point.jdk.not.found"
  fi
  warn "java.build.extend.point.using.java.home" "${JAVA_HOME}"
}

#执行java项目的编译
function _buildProject_ex() {
  export gMultipleModelProject

  local l_subModuleDirs
  local l_subModuleDir
  local l_pomXml
  local l_errorLog
  local l_info

#  不需要执行子模块的编译，因为父模块编译时会自动编译子模块。
#  if [ "${gMultipleModelProject}" == "true" ];then
#    #查找当前目录下的所有子目录.
#    # shellcheck disable=SC2185
#    l_subModuleDirs=$(find -maxdepth 1 -type d | grep -oP "^(\.\/).*$")
#    # shellcheck disable=SC2068
#    for l_subModuleDir in ${l_subModuleDirs[@]};do
#      l_pomXml="${l_subModuleDir}/pom.xml"
#      if [ -f "${l_pomXml}" ];then
#        info "进入${l_subModuleDir}子目录"
#        # shellcheck disable=SC2164
#        cd "${l_subModuleDir}"
#        info "执行${l_subModuleDir#*/}子模块的构建..."
#        _buildSubModule "install"
#        info "退出${l_subModuleDir}子目录"
#        # shellcheck disable=SC2103
#        cd ..
#      fi
#    done
#  fi
  info "java.build.extend.point.building.entire.project"
  _buildSubModule "package"
}

#******************私有方法********************#

function _buildSubModule() {
  export gServiceName
  export gCurrentStageResult
  export gLogI18NRetVal

  local l_cmd=$1
  local l_info

  if ! mvn clean ${l_cmd} -Dmaven.test.skip=true ;then
    error "java.build.extend.point.project.compilation.failed" "${gServiceName}"
  fi

  convertI18NText "java.build.extend.point.project.compilation.succeeded" "${gServiceName}#mvn clean ${l_cmd} -Dmaven.test.skip=true"
  l_info="${gLogI18NRetVal}"
  info "${l_info}"
  gCurrentStageResult="INFO|${l_info}"
}

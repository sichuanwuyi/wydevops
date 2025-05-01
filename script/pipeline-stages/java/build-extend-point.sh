#!/usr/bin/env bash

function _onBeforeProjectBuilding_ex() {
  export gBuildPath
  export gMultipleModelProject


  info "进入项目主模块目录"
  cd "${gBuildPath}" || true

  if [ "${gMultipleModelProject}" == "true" ];then
    info "项目是多模块目录，回退到主模块目录的上级目录中，再执行后续编译"
    cd ..
  fi

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

  info "构建整个项目..."
  _buildSubModule "package"
}

#******************私有方法********************#

function _buildSubModule() {
  export gServiceName
  export gCurrentStageResult

  local l_cmd=$1

  local l_errorLog
  local l_info

   mvn clean ${l_cmd} -DskipTests=true 2>&1 | tee "./build.tmp"
   # shellcheck disable=SC2002
   l_errorLog=$(cat "./build.tmp" | grep "BUILD SUCCESS")
   rm -f "./build.tmp" || true

   if [ ! "${l_errorLog}" ];then
     error "项目${gServiceName}编译失败"
   fi

   l_info="项目${gServiceName}编译成功：mvn clean ${l_cmd} -DskipTests=true"
   info "${l_info}"
   gCurrentStageResult="INFO|${l_info}"
}

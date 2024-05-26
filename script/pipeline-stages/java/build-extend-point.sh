#!/usr/bin/env bash

function _onBeforeProjectBuilding_ex() {
  export gDefaultRetVal
  export gBuildPath
  export gMultipleModelProject

  local l_resourcesDir
  local l_yamlList
  local l_ymalFile

  info "进入项目主模块目录"
  cd "${gBuildPath}" || true

  if [ "${gMultipleModelProject}" == "true" ];then
    info "项目是多模块目录，回退到主模块目录的上级目录中，再执行后续编译"
    cd ..
  fi

  l_resourcesDir="${gBuildPath}/src/main/resources"
  info "查询并修改application*.yaml文件中的spring.profiles.active=prod"
  l_yamlList=$(find "${l_resourcesDir}" -type f -name "application*.yml")
  if [ "${l_yamlList}" ];then
    # shellcheck disable=SC2068
    for l_ymalFile in ${l_yamlList[@]}
    do
      updateParam "${l_ymalFile}" "spring.profiles.active" "prod"
      if [[ ! "${gDefaultRetVal}" =~ ^(\-1) ]];then
        info "--->修改${l_ymalFile##*/}文件中的spring.profiles.active=prod---成功"
      fi
    done
  else
    error "未检测到任何application*.yaml文件"
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

  if [ "${gMultipleModelProject}" == "true" ];then
    #查找当前目录下的所有子目录.
    # shellcheck disable=SC2185
    l_subModuleDirs=$(find -maxdepth 1 -type d | grep -oP "^(\.\/).*$")
    # shellcheck disable=SC2068
    for l_subModuleDir in ${l_subModuleDirs[@]};do
      l_pomXml="${l_subModuleDir}/pom.xml"
      if [ -f "${l_pomXml}" ];then
        info "进入${l_subModuleDir}子目录"
        # shellcheck disable=SC2164
        cd "${l_subModuleDir}"
        info "执行${l_subModuleDir#*/}子模块的构建..."
        _buildSubModule
        info "退出${l_subModuleDir}子目录"
        # shellcheck disable=SC2103
        cd ..
      fi
    done
  fi

  info "构建整个项目..."
  _buildSubModule
}

#******************私有方法********************#

function _buildSubModule() {
  export gServiceName
  export gCurrentStageResult

  local l_errorLog
  local l_info

   mvn clean package -DskipTests=true 2>&1 | tee "./build.tmp"
   # shellcheck disable=SC2002
   l_errorLog=$(cat "./build.tmp" | grep -ioP "^(.*)(ERROR|timed out).*$")
   rm -f "./build.tmp" || true

   if [ "${l_errorLog}" ];then
     error "项目${gServiceName}编译失败： ${l_errorLog}"
   fi

   l_info="项目${gServiceName}编译成功：mvn clean package -DskipTests=true"
   gCurrentStageResult="INFO|${l_info}"
}

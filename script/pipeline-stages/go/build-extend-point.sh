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

function _buildProject_ex() {
  export gDefaultRetVal
  export gBuildPath
  export gServiceName

  local l_cicdYamlFile=$1

  local l_archTypes
  local l_osType
  local l_archType
  local l_errorLog

  readParam "${l_cicdYamlFile}" "globalParams.enableOfflineBuild"
  if [[ "${gDefaultRetVal}" == "null" || "${gDefaultRetVal}" == "false" ]];then
    info "跳过项目编译过程(在docker build过程中编译项目)..."
    return
  fi

  readParam "${l_cicdYamlFile}" "globalParams.archTypes"
  # shellcheck disable=SC2206
  l_archTypes=(${gDefaultRetVal//,/ })
  # shellcheck disable=SC2068
  for l_archType in ${l_archTypes[@]};do
    l_osType="${l_archType%%/*}"
    l_archType="${l_archType##*/}"
    info "开始执行项目编译过程..."
    l_errorLog=$(CGO_ENABLED=0 GOOS="${l_osType}" GOARCH="${l_archType}" go build -o "${gServiceName}-${l_osType}-${l_archType}.out" "${gBuildPath}")
    if [ "${l_errorLog}" ];then
      error "编译${l_osType}/${l_archType}类型的应用失败: ${l_errorLog}"
    fi
    info "成功编译${l_osType}/${l_archType}类型的应用"
  done

}






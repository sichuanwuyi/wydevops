#!/usr/bin/env bash

function _onBeforeProjectBuilding_ex() {
  export gDefaultRetVal
  export gBuildPath
  export gMultipleModelProject

  info "go.build.extend.point.entering.project.main.module.dir" "${gBuildPath}"
  cd "${gBuildPath}" || true

  info "go.build.extend.point.setting.gmultiplemodelproject.to.false" "gMultipleModelProject#false"
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
    info "go.build.extend.point.skipping.project.compilation"
    return
  fi

  readParam "${l_cicdYamlFile}" "globalParams.archTypes"
  # shellcheck disable=SC2206
  l_archTypes=(${gDefaultRetVal//,/ })
  # shellcheck disable=SC2068
  for l_archType in ${l_archTypes[@]};do
    l_osType="${l_archType%%/*}"
    l_archType="${l_archType##*/}"
    info "go.build.extend.point.starting.project.compilation"
    l_errorLog=$(CGO_ENABLED=0 GOOS="${l_osType}" GOARCH="${l_archType}" go build -o "${gServiceName}-${l_osType}-${l_archType}.out" "${gBuildPath}")
    if [ "${l_errorLog}" ];then
      error "go.build.extend.point.compilation.failed" "${l_osType}/${l_archType}#${l_errorLog}"
    fi
    info "go.build.extend.point.compilation.succeeded" "${l_osType}/${l_archType}"
  done

}






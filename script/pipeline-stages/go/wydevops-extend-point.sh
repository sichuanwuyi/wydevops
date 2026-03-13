#!/usr/bin/env bash

#------------------------语言级扩展方法------------------------#

function _onValidateGlobalParams_ex() {
  info "go.wydevops.extend.point.validating.global.params" "${gLanguage}"

  export gBuildType
  export gLanguage

  if [ "${gBuildType}" != "single" ];then
    error "go.wydevops.extend.point.build.type.not.supported" "${gLanguage}#${gBuildType}"
  fi

}

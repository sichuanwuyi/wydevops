#!/usr/bin/env bash

#------------------------语言级扩展方法------------------------#

function _onValidateGlobalParams_ex() {
  info "针对${gLanguage}语言项目，检查全局参数的有效性..."

  export gBuildType
  export gLanguage

  if [ "${gBuildType}" != "single" ];then
    error "${gLanguage}语言项目不支持buildType=${gBuildType}的构建类型，仅支持single构建类型"
  fi

}

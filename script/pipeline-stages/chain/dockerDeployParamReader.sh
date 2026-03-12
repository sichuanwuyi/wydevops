#!/usr/bin/env bash

#docker方式部署服务需要的脚本文件或配置文件的标准读取器
function readDockerDeployParam() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gBuildScriptRootDir
  export gLanguage
  export gBuildPath

  local l_index=$1
  local l_configParamName=$2
  local l_targetScriptFileDefaultName=$3

  local l_shellFile

  if [ "${l_configParamName}" ];then
    #读取项目配置的docker-run.sh文件。
    readParam "${gCiCdYamlFile}" "deploy[${l_index}].docker.${l_configParamName}"
    l_shellFile="${gDefaultRetVal}"
    if [[ ! "${l_shellFile}" ]];then
      warn "docker.deploy.param.reader.config.invalid.not.set" "${gCiCdYamlFile##*/}#${l_index}#${l_configParamName}"
      l_shellFile=""
    else
      [[ "${l_shellFile}" =~ ^(\./) ]] && l_shellFile="${gBuildPath}/${l_shellFile:2}"
      if [[ ! -f "${l_shellFile}" ]];then
        warn "docker.deploy.param.reader.config.invalid.not.exist" "${gCiCdYamlFile##*/}#${l_index}#${l_configParamName}"
        l_shellFile=""
      fi
    fi

    if [ ! "${l_shellFile}" ];then
      info "docker.deploy.param.reader.checking.docker.run.sh" "${gBuildPath}"
      l_shellFile="${gBuildPath}/${l_targetScriptFileDefaultName}"
      if [[ ! -f "${l_shellFile}" ]];then
        warn "docker.deploy.param.reader.config.invalid.not.set" "${gCiCdYamlFile##*/}#${l_index}#${l_configParamName}"
        l_shellFile=""
      else
        info "docker.deploy.param.reader.docker.run.sh.found" "${gBuildPath}"
      fi
    fi
  fi

  if [ ! "${l_shellFile}" ];then
    #如果不存在，则读取语言级\${l_targetScriptFileDefaultName}生成脚本。
    l_shellFile="${gBuildScriptRootDir}/templates/deploy/${gLanguage}/${l_targetScriptFileDefaultName}"
    if [[ ! "${l_shellFile}" || ! -f "${l_shellFile}" ]];then
      warn "docker.deploy.param.reader.language.level.config.invalid" "${gLanguage}#${l_targetScriptFileDefaultName}"
      #如果仍不存在，则读取公共docker-run.sh生成脚本。
      l_shellFile="${gBuildScriptRootDir}/templates/deploy/${l_targetScriptFileDefaultName}"
      if [[ ! "${l_shellFile}" || ! -f "${l_shellFile}" ]];then
        error "docker.deploy.param.reader.common.file.missing" "${gBuildScriptRootDir}#${l_targetScriptFileDefaultName}"
      else
        info "docker.deploy.param.reader.common.file.found" "${l_targetScriptFileDefaultName}"
      fi
    else
      info "docker.deploy.param.reader.language.level.file.found" "${gLanguage}#${l_targetScriptFileDefaultName}"
    fi
  else
    info "docker.deploy.param.reader.project.level.file.found" "${l_targetScriptFileDefaultName}"
  fi

  gDefaultRetVal="${l_shellFile}"
}
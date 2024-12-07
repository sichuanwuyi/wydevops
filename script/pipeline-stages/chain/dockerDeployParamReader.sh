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
      warn "${gCiCdYamlFile##*/}文件中deploy[${l_index}].docker.${l_configParamName}参数配置无效：未设置"
      l_shellFile=""
    else
      [[ "${l_shellFile}" =~ ^(\./) ]] && l_shellFile="${gBuildPath}/${l_shellFile:2}"
      if [[ ! -f "${l_shellFile}" ]];then
        warn "${gCiCdYamlFile##*/}文件中deploy[${l_index}].docker.${l_configParamName}参数配置无效：指定的文件不存在"
        l_shellFile=""
      fi
    fi

    if [ ! "${l_shellFile}" ];then
      info "继续检查${gBuildPath}目录下是否存在docker-run.sh文件 ..."
      l_shellFile="${gBuildPath}/${l_targetScriptFileDefaultName}"
      if [[ ! -f "${l_shellFile}" ]];then
        warn "${gCiCdYamlFile##*/}文件中deploy[${l_index}].docker.${l_configParamName}参数配置无效：未设置"
        l_shellFile=""
      else
        info "${gBuildPath}目录下检测到docker-run.sh文件"
      fi
    fi
  fi

  if [ ! "${l_shellFile}" ];then
    #如果不存在，则读取语言级\${l_targetScriptFileDefaultName}生成脚本。
    l_shellFile="${gBuildScriptRootDir}/templates/deploy/${gLanguage}/${l_targetScriptFileDefaultName}"
    if [[ ! "${l_shellFile}" || ! -f "${l_shellFile}" ]];then
      warn "${gLanguage}语言级${l_targetScriptFileDefaultName}文件配置无效：未设置"
      #如果仍不存在，则读取公共docker-run.sh生成脚本。
      l_shellFile="${gBuildScriptRootDir}/templates/deploy/${l_targetScriptFileDefaultName}"
      if [[ ! "${l_shellFile}" || ! -f "${l_shellFile}" ]];then
        error "${gBuildScriptRootDir}/shell目录下缺少公共的${l_targetScriptFileDefaultName}文件"
      else
        info "检测到公共的${l_targetScriptFileDefaultName}文件"
      fi
    else
      info "检测到${gLanguage}语言级${l_targetScriptFileDefaultName}文件"
    fi
  else
    info "检测到项目级${l_targetScriptFileDefaultName}文件"
  fi

  gDefaultRetVal="${l_shellFile}"
}
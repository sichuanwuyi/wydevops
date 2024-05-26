#!/usr/bin/env bash

function generateDockerRunShellFile() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gBuildType
  export gBuildPath
  export gTempFileDir

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_images=$4
  local l_remoteDir=$5

  local l_array
  local l_port
  local l_exposePorts
  local l_mainImage

  local l_configMapFiles
  declare -A l_paramDefaultValueMap
  local l_i
  local l_paramName
  local l_paramValue

  local l_configFile
  local l_paramList
  local l_lines
  local l_lineCount
  local l_paramItem
  local l_hasUndefineParam
  local l_workDirInContainer

  #获取需要暴露的端口号。
  readParam "${gCiCdYamlFile}" "docker.exposePorts"
  # shellcheck disable=SC2206
  l_array=(${gDefaultRetVal//,/ })
  # shellcheck disable=SC2068
  for l_port in ${l_array[@]};do
    l_exposePorts="${l_exposePorts} -p ${l_port}:${l_port}"
  done

  #读取第一个镜像。
  l_mainImage=${l_images%%,*}

  l_hasUndefineParam="false"
  # shellcheck disable=SC2068
  for l_configFile in ${l_configMapFiles[@]};do
    info "检测并处理${l_configFile##*/}文件中的变量 ..."
    if [[ "${l_configFile}" =~ ^(\.) ]];then
      l_configFile="${gBuildPath}/${l_configFile#*/}"
    fi

    #拷贝配置文件到临时目录中。
    cp -f "${l_configFile}" "${gTempFileDir}/${l_configFile##*/}"

    #切换到临时文件目录中的配置文件。
    l_configFile="${gTempFileDir}/${l_configFile##*/}"

    #检测配置文件中是否存在动态配置的参数，如果存在则需要替换赋值。
    # shellcheck disable=SC2002
    l_paramList=$(cat "${l_configFile}" | grep -oP "\{\{[ ]+\.Values(\.[a-zA-Z0-9_\-]+)+[ ]+\}\}" | sort | uniq -c)
    if [ "${l_paramList}" ];then

      #先加载参数默认值配置Map
      # shellcheck disable=SC2128
      if [ ! "${l_paramDefaultValueMap}" ];then
          info "加载application*.yaml系列文件中动态配置参数的默认值Map..."
          readParam "${gCiCdYamlFile}" "globalParams.configMapFiles"
          if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
            l_configMapFiles="${gDefaultRetVal//,/ }"
            #构造参数默认值Map
            ((l_i = 0))
            while true; do
              readParam "${gCiCdYamlFile}" "deploy[${l_index}].docker.params[${l_i}]"
              if [[ "${gDefaultRetVal}" == "null" ]];then
                break
              fi
              l_paramName=$(echo "${gDefaultRetVal}" | grep "^name:.*$")
              l_paramName="${l_paramName//name: /}"
              l_paramValue=$(echo "${gDefaultRetVal}" | grep "^value:.*$")
              l_paramValue="${l_paramValue//value: /}"
              # shellcheck disable=SC2034
              l_paramDefaultValueMap["${l_paramName}"]="${l_paramValue}"
              info "加载参数默认值：${l_paramName}=>${l_paramValue}"
              ((l_i = l_i + 1))
            done
          fi
      fi

      stringToArray "${l_paramList}" "l_lines"
      l_lineCount="${#l_lines[@]}"
      for ((l_i=0; l_i < l_lineCount; l_i++ ));do
        l_paramItem="${l_lines[${l_i}]}"
        l_paramName=".${l_paramItem#*.}"
        l_paramName="${l_paramName%%\}*}"
        l_paramName="${l_paramName// /}"
        l_paramValue="${l_paramDefaultValueMap[${l_paramName}]}"
        if [ ! "${l_paramValue}" ];then
          #如果参数的值未定义，则告警输出。
          l_hasUndefineParam="true"
          warn "${l_configFile##*/}配置文件中存在未定义的变量：${l_paramName}"
        else
          #替换配置文件中的变量。
          l_paramItem="{${l_paramItem#*\{}"
          l_paramItem="${l_paramItem%\}*}}"
          info "将临时目录中的${l_configFile##*/}文件中的变量${l_paramItem}替换为${l_paramValue}"
          sed -i "s/${l_paramItem}/${l_paramValue}/g" "${l_configFile}"
        fi

      done
    fi
  done

  if [ "${l_hasUndefineParam}" == "true" ];then
    error "项目配置文件中存在上述未定义的变量，请明确定义这些变量后再再次尝试。"
  fi

  #获取配置文件挂载路径。
  readParam "${gCiCdYamlFile}" "docker.workDir"
  l_workDirInContainer="${gDefaultRetVal}"

  #在gBuildPath路径中输出docker-run.sh文件。
  echo "#!/usr/bin/env bash
docker run -d ${l_exposePorts:1} -v ${l_remoteDir}/config:${l_workDirInContainer}/config --name ${l_chartName} ${l_mainImage}
" > "${gBuildPath}/docker-run.sh"
}

generateDockerRunShellFile "${@}"
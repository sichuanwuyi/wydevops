#!/usr/bin/env bash

function initialGlobalParamsForDeployStage_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gBuildPath
  export gCiCdConfigYamlFileName
  export gParamDeployedValueMap

  local l_saveBackStatus
  local l_cicdConfigFile
  local l_deployIndex
  local l_targetIndex

  local l_loopIndex
  local l_layerLevel
  local l_configMapFiles
  local l_configFile
  local l_paramList
  local l_lineCount
  local l_i

  local l_paramName
  local l_paramValue
  local l_itemValue
  local l_paramIndex
  local l_array
  local l_businessParamNames
  local l_businessParamIndex

  #扫描gCiCdYamlFile文件中chart[?].deployment[?].configMaps参数，在指定的文件中查找”{{ .Values.* }}“格式的参数定义。
  #如果有则提取这些参数及其默认值，回写到项目中的ci-cd-config.yaml文件中。
  #如果ci-cd-config.yaml文件不存在，则创建之。并在其中添加deploy相关配置(包括参数列表)。

  info "检测部署服务需要配置的业务参数..."

  disableSaveBackImmediately
  l_saveBackStatus="${gDefaultRetVal}"

  l_cicdConfigFile="${gBuildPath}/${gCiCdConfigYamlFileName}"
  if [ ! -f "${l_cicdConfigFile}" ];then
    info "创建${l_cicdConfigFile##*/}项目配置文件"
    touch "${l_cicdConfigFile}"
  fi

  _createDeployItem "${gCiCdYamlFile}" "0" "${l_cicdConfigFile}"
  # shellcheck disable=SC2206
  l_array=(${gDefaultRetVal})
  l_deployIndex="${l_array[0]}"
  l_targetIndex="${l_array[1]}"

  l_loopIndex=(0 0 0)
  ((l_layerLevel = 3))
  while true;do
    readParam "${gCiCdYamlFile}" "chart[${l_loopIndex[0]}].deployments[${l_loopIndex[1]}].configMaps[${l_loopIndex[2]}].files"
    if [[ "${gDefaultRetVal}" == "null" ]];then
      if [ "${l_layerLevel}" -eq 3 ];then
        ((l_loopIndex[1] = l_loopIndex[1] + 1))
        ((l_loopIndex[2] = 0))
      elif [ "${l_layerLevel}" -eq 2 ];then
        ((l_loopIndex[0] = l_loopIndex[0] + 1))
        ((l_loopIndex[1] = 0))
        ((l_loopIndex[2] = 0))
      else
        break
      fi
      ((l_layerLevel = l_layerLevel - 1))
      continue
    fi

    # shellcheck disable=SC2206
    l_configMapFiles=(${gDefaultRetVal//,/ })

    if [ "${l_layerLevel}" -eq 1 ];then
      _createDeployItem "${gCiCdYamlFile}" "${l_loopIndex[0]}" "${l_cicdConfigFile}"
      # shellcheck disable=SC2206
      l_array=(${gDefaultRetVal})
      l_deployIndex="${l_array[0]}"
      l_targetIndex="${l_array[1]}"
    fi

    #恢复层级数。
    ((l_layerLevel = 3))

    info "读取${l_cicdConfigFile##*/}文件中deploy[${l_targetIndex}].params列表中所有的name的值。"
    _readValueOfListItemNames "${l_cicdConfigFile}" "deploy[${l_targetIndex}].params"
    l_businessParamNames="${gDefaultRetVal}"
    if [[ "${l_businessParamNames}" && "${l_businessParamNames}" != "null" ]];then
      l_businessParamNames="${l_businessParamNames},"
      l_businessParamIndex="${l_targetIndex}"
    fi

    # shellcheck disable=SC2068
    for l_configFile in ${l_configMapFiles[@]};do
      info "正在检测${l_configFile##*/}文件中的变量..."
      [[ "${l_configFile}" =~ ^(\.) ]] && l_configFile="${gBuildPath}/${l_configFile#*/}"

      # shellcheck disable=SC2002
      l_paramList=$(cat "${l_configFile}" | grep -oP "\{\{[ ]+\.Values(\.[a-zA-Z0-9_\-]+)+[ ]*(\|[ ]*default.*)*[ ]+\}\}" | sort | uniq -c)
      if [ "${l_paramList}" ];then

        stringToArray "${l_paramList}" "l_lines"
        l_lineCount="${#l_lines[@]}"
        for ((l_i=0; l_i < l_lineCount; l_i++ ));do
          l_paramName=$(echo -e "${l_lines[${l_i}]}" | grep -oP ".Values(\.[a-zA-Z0-9_\-]+)+( |\|)")
          [[ "${l_paramName}" =~ ^(.*)\|$ ]] && l_paramName="${l_paramName%|*}"
          l_paramName=$(echo -e "${l_paramName}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

          l_paramValue=""
          if [[ "${l_lines[${l_i}]}" =~ ^(.*)(\|[ ]*default)(.*) ]];then
            l_paramValue="${l_lines[${l_i}]#*|}"
            l_paramValue="${l_paramValue%%\}*}"
            l_paramValue="${l_paramValue// default/}"
            l_paramValue=$(echo -e "${l_paramValue}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [[ "${l_paramValue}" =~ ^(\") ]];then
              #去掉头尾引号
              l_paramValue="${l_paramValue/\"/}"
              l_paramValue="${l_paramValue%\"*}"
            fi
          fi

          #缓存参数及其值。
          gParamDeployedValueMap["${l_paramName}"]="${l_paramValue}"

          #不存在name=l_paramName的项，则插入之。
          getListIndexByPropertyName "${l_cicdConfigFile}" "deploy[${l_targetIndex}].params" "name" "${l_paramName}" "true" "${gCiCdYamlFile}"
          if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
            # shellcheck disable=SC2206
            l_array=(${gDefaultRetVal})
            l_paramIndex="${l_array[1]}"
            info "--->向${l_cicdConfigFile##*/}文件添加新参数：deploy[${l_targetIndex}].params[${l_paramIndex}]"
            l_itemValue="name: ${l_paramName}\nvalue: ${l_paramValue}"
            insertParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].params[${l_paramIndex}]" "${l_itemValue}"
          else
            info "--->检测到业务参数:${l_paramName}=" "-n"
            # shellcheck disable=SC2206
            l_array=(${gDefaultRetVal})
            l_paramIndex="${l_array[0]}"
            readParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].params[${l_paramIndex}].value"
            l_paramValue="${gDefaultRetVal}"
            gParamDeployedValueMap["${l_paramName}"]="${l_paramValue}"
            if [ "${l_paramValue}" ];then
              info "${l_paramValue}" "*"
            else
              warn " (没有配置值)" "*"
            fi
          fi

          if [ "${l_businessParamNames}" ];then
            #从现有参数列表中删除l_paramName。
            l_businessParamNames="${l_businessParamNames//${l_paramName}/}"
          fi
        done

      fi
    done

    if [ "${l_businessParamNames//,/}" ];then
      warn "清除${l_cicdConfigFile##*/}文件deploy[${l_businessParamIndex}].params列表中未用到的参数项..."
      # shellcheck disable=SC2206
      l_array=(${l_businessParamNames//,/ })
      # shellcheck disable=SC2068
      for l_paramName in ${l_array[@]};do
        warn "清除未用到的参数项:${l_paramName}"
        getListIndexByPropertyName "${l_cicdConfigFile}" "deploy[${l_businessParamIndex}].params" \
          "name" "${l_paramName}" "false" "${gCiCdYamlFile}"
        deleteParam "${l_cicdConfigFile}" "deploy[${l_businessParamIndex}].params[${gDefaultRetVal}]"
      done
    fi
    ((l_loopIndex[2] = l_loopIndex[2] + 1))
  done

  #恢复gSaveBackImmediately的原始值。
  enableSaveBackImmediately "${l_saveBackStatus}"
}

function onBeforeDeployingServicePackage_ex() {
  export gCiCdYamlFile

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  #根据deployType的不同进行不同的环境检查和准备。
  local l_deployType=$4
  local l_images=$5
  local l_remoteDir=$6
  local l_localBaseDir=$7

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].deployType"
  l_deployType="${gDefaultRetVal}"

  if [ "${l_deployType}" == "docker" ];then
    #检查项目配置文件中需要配置的参数，并为其赋初始值。
    invokeExtendPointFunc "onCheckAndInitialParamInConfigFile" "docker部署前先检查并初始化项目配置文件中的参数" \
      "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_localBaseDir}"
    #采用docker方式部署服务安装包前扩展
    invokeExtendPointFunc "onBeforeDeployingServicePackageByDockerMode" "采用docker方式部署服务安装包前扩展" "${l_index}" "${l_chartName}" \
      "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
  elif [ "${l_deployType}" == "k8s" ];then
    invokeExtendPointFunc "onBeforeDeployingServicePackageByK8sMode" "采用K8s方式部署服务安装包前扩展" "${l_index}" "${l_chartName}" \
      "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
  fi

}

function deployServicePackage_ex() {
  export gCurrentStageResult

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_deployType=$4
  local l_images=$5
  local l_remoteDir=$6
  local l_localBaseDir=$7
  local l_shellOrYamlFile=$8
  local l_remoteInstallProxyShell=$9

  if [ "${l_deployType}" == "docker" ];then
    #调用标准发布流程
    _deployServiceByDocker "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_shellOrYamlFile}" \
      "${l_remoteInstallProxyShell}" "${l_localBaseDir}" "${l_remoteDir}"
  else
    #调用标准发布流程
    _deployServiceInK8S "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_localBaseDir}"
  fi
  gCurrentStageResult="INFO|${l_packageName}安装包部署成功"
}

function onBeforeDeployingServicePackageByDockerMode_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gDockerRepoName
  export gDockerRepoAccount
  export gDockerRepoPassword
  export gBuildPath
  export gBuildType

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_images=$4
  local l_remoteDir=$5

  local l_shellOrYamlFile
  local l_remoteInstallProxyShell

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].docker.mode"
  if [ "${gDefaultRetVal}" == "docker" ];then
    #获取docker-run.sh文件，该脚本文件的功能是执行docker run命令拉起服务。
    invokeExtendChain "onGenerateDockerRunShellFile" "${gBuildPath}" "${gBuildType}" "${l_index}" "${l_chartName}" \
      "${l_chartVersion}" "${l_images}" "${l_remoteDir}" "${gDockerRepoName}" "${gDockerRepoAccount}" "${gDockerRepoPassword}"
    l_shellOrYamlFile="${gDefaultRetVal}"
  else
    #获取docker-compose.yaml文件，该文件是docker-compose命令的配置文件。
    invokeExtendChain "onGenerateDockerComposeYamlFile" "${gBuildPath}" "${gBuildType}" "${l_index}" "${l_chartName}" \
      "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
    l_shellOrYamlFile="${gDefaultRetVal}"
  fi

  #选择远程安装代理脚本
  invokeExtendChain "onSelectRemoteInstallProxyShell" "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
  l_remoteInstallProxyShell="${gDefaultRetVal}"

  gDefaultRetVal="${l_shellOrYamlFile} ${l_remoteInstallProxyShell}"

}

function onBeforeDeployingServicePackageByK8sMode_ex() {
  export gCiCdYamlFile

  local l_index=$1
  local l_packageName=$2

  #检查本地是否安装有helm工具。
  l_errorLog=$(helm version | grep -oP "not found" )
  if [ "${l_errorLog}" ];then
    #检查当前操作系统类型
    invokeExtendChain "onGetSystemArchInfo"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "false" ]] && error "读取本地系统架构信息失败" || info "读取到当前系统架构为:${gDefaultRetVal}"
    #将生成的Chart镜像推送到gChartRepoName仓库中。
    invokeExtendPointFunc "installHelm" "在本地系统中安装helm工具" "${gDefaultRetVal%%/*}" "${gDefaultRetVal#*/}"
  fi

}

function onCheckAndInitialParamInConfigFile_ex(){
  export gDefaultRetVal
  export gCiCdYamlFile
  export gBuildPath
  export gParamDeployedValueMap

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_localBaseDir=$4

  local l_chartIndex
  local l_loopIndex
  local l_layerLevel

  local l_configMapFiles
  local l_configFile
  local l_m

  local l_paramName
  local l_paramValue

  local l_configFile
  local l_paramList
  local l_lines
  local l_lineCount
  local l_paramItem
  local l_hasUndefineParam

  local l_paramNameList
  local l_result

  l_hasUndefineParam="false"

  l_localBaseDir="${l_localBaseDir}/${l_chartName}-${l_chartVersion}/config"
  mkdir -p "${l_localBaseDir}"

  getListIndexByPropertyName "${gCiCdYamlFile}" "chart" "name" "${l_chartName}"
  [[  "${gDefaultRetVal}" =~ ^(\-1) ]] && error "${gCiCdYamlFile##*/}文件中未找到name=${l_chartName}的chart列表项"
  l_chartIndex="${gDefaultRetVal}"

  # shellcheck disable=SC2124
  l_paramNameList="${!gParamDeployedValueMap[@]}"

  l_loopIndex=(0 0)
  ((l_layerLevel = 2))
  while true;do
    readParam "${gCiCdYamlFile}" "chart[${l_chartIndex}].deployments[${l_loopIndex[0]}].configMaps[${l_loopIndex[1]}].files"
    if [[ "${gDefaultRetVal}" == "null" ]];then
      if [ "${l_layerLevel}" -eq 2 ];then
        ((l_loopIndex[0] = l_loopIndex[0] + 1))
        ((l_loopIndex[1] = 0))
      else
        break
      fi
      ((l_layerLevel = l_layerLevel - 1))
      continue
    fi
    #恢复层级数。
    ((l_layerLevel = 2))

    # shellcheck disable=SC2206
    l_configMapFiles=(${gDefaultRetVal//,/ })
    # shellcheck disable=SC2068
    for l_configFile in ${l_configMapFiles[@]};do
      info "检测并处理${l_configFile##*/}文件中的变量 ..."
      if [[ "${l_configFile}" =~ ^(\.) ]];then
        l_configFile="${gBuildPath}/${l_configFile#*/}"
      fi

      #拷贝配置文件到临时目录中。
      cp -f "${l_configFile}" "${l_localBaseDir}/${l_configFile##*/}"

      #切换到临时文件目录中的配置文件。
      l_configFile="${l_localBaseDir}/${l_configFile##*/}"

      #检测配置文件中是否存在动态配置的参数，如果存在则需要替换赋值。
      # shellcheck disable=SC2002
      l_paramList=$(cat "${l_configFile}" | grep -oP "\{\{[ ]+\.Values(\.[a-zA-Z0-9_\-]+)+[ ]*(\|[ ]*default.*)*[ ]+\}\}" | sort | uniq -c)
      if [ "${l_paramList}" ];then

        stringToArray "${l_paramList}" "l_lines"
        l_lineCount="${#l_lines[@]}"
        for ((l_m=0; l_m < l_lineCount; l_m++ ));do
          l_paramItem="${l_lines[${l_m}]}"
          l_paramName=".${l_paramItem#*.}"
          l_paramName="${l_paramName%%\}*}"
          #去掉缺少值设置。
          l_paramName="${l_paramName%%|*}"
          #去掉头部和尾部的空格。
          l_paramName=$(echo -e "${l_paramName}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

          l_result=$(echo -e "${l_paramNameList}" | grep -oP "${l_paramName}( |$)" )
          if [ ! "${l_result}" ];then
            #如果参数的值未定义，则告警输出。
            l_hasUndefineParam="true"
            warn "${l_configFile##*/}配置文件中存在未定义的变量：${l_paramName}"
          fi

          l_paramValue="${gParamDeployedValueMap[${l_paramName}]}"
          #替换配置文件中的变量。
          l_paramItem="{${l_paramItem#*\{}"
          l_paramItem="${l_paramItem%\}*}}"
          info "将临时目录中的${l_configFile##*/}文件中的变量${l_paramItem}替换为${l_paramValue}"
          sed -i "s/${l_paramItem}/${l_paramValue}/g" "${l_configFile}"

        done
      fi
    done

    ((l_loopIndex[1] = l_loopIndex[1] + 1))
  done

  if [ "${l_hasUndefineParam}" == "true" ];then
    error "项目配置文件中存在上述未定义的变量，请明确定义这些变量后再次尝试。"
  fi
}

function onCheckAndInitialParamInConfigFile1_ex(){
  export gDefaultRetVal
  export gCiCdYamlFile
  export gBuildPath

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_localBaseDir=$4

  local l_array
  local l_i
  local l_j

  local l_configMapFiles
  declare -A l_paramDefaultValueMap
  local l_k
  local l_m
  local l_paramName
  local l_paramValue

  local l_configFile
  local l_paramList
  local l_lines
  local l_lineCount
  local l_paramItem
  local l_hasUndefineParam

  l_hasUndefineParam="false"

  l_localBaseDir="${l_localBaseDir}/${l_chartName}-${l_chartVersion}/config"
  mkdir -p "${l_localBaseDir}"

  getListIndexByPropertyName "${gCiCdYamlFile}" "chart" "name" "${l_chartName}"
  [[  "${gDefaultRetVal}" =~ ^(\-1) ]] && error "${gCiCdYamlFile##*/}文件中未找到name=${l_chartName}的chart列表项"
  # shellcheck disable=SC2206
  l_array=(${gDefaultRetVal})

  ((l_i = 0))
  while true;do
    readParam "${gCiCdYamlFile}" "chart[${l_array[0]}].deployments[${l_i}]"
    [[ "${gDefaultRetVal}" == "null" ]] && break

    ((l_j = 0))
    while true;do
      readParam "${gCiCdYamlFile}" "chart[${l_array[0]}].deployments[${l_i}].configMaps[${l_j}].files"
      [[ "${gDefaultRetVal}" == "null" ]] && break
      # shellcheck disable=SC2206
      l_configMapFiles=(${gDefaultRetVal//,/ })
      # shellcheck disable=SC2068
      for l_configFile in ${l_configMapFiles[@]};do
        info "检测并处理${l_configFile##*/}文件中的变量 ..."
        if [[ "${l_configFile}" =~ ^(\.) ]];then
          l_configFile="${gBuildPath}/${l_configFile#*/}"
        fi

        #拷贝配置文件到临时目录中。
        cp -f "${l_configFile}" "${l_localBaseDir}/${l_configFile##*/}"

        #切换到临时文件目录中的配置文件。
        l_configFile="${l_localBaseDir}/${l_configFile##*/}"

        #检测配置文件中是否存在动态配置的参数，如果存在则需要替换赋值。
        # shellcheck disable=SC2002
        l_paramList=$(cat "${l_configFile}" | grep -oP "\{\{[ ]+\.Values(\.[a-zA-Z0-9_\-]+)+[ ]*(\|[ ]*default.*)*[ ]+\}\}" | sort | uniq -c)
        if [ "${l_paramList}" ];then

          #如果l_paramDefaultValueMap变量未初始化，则先加载参数默认值配置Map
          # shellcheck disable=SC2128
          if [ ! "${l_paramDefaultValueMap}" ];then
            #构造参数默认值Map
            ((l_k = 0))
            while true; do
              readParam "${gCiCdYamlFile}" "deploy[${l_index}].params[${l_k}]"
              [[ "${gDefaultRetVal}" == "null" ]] && break
              l_paramName=$(echo "${gDefaultRetVal}" | grep "^name:.*$")
              l_paramName="${l_paramName//name: /}"
              #去掉头部和尾部的空格。
              l_paramName=$(echo -e "${l_paramName}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
              #补全参数格式，以便后续的匹配。
              if [[ ! "${l_paramName}" =~ ^(\.Values\.) ]];then
                #如果参数不是params.deployment开头的则要使用params.deployment0.补全
                [[ ! "${l_paramName}" =~ ^(params\.deployment)[0-9]+ ]] && l_paramName="params.deployment0.${l_paramName}"
                l_paramName=".Values.${l_paramName}"
              fi

              l_paramValue=$(echo "${gDefaultRetVal}" | grep "^value:.*$")
              l_paramValue="${l_paramValue//value: /}"
              #去掉头部和尾部的空格。
              l_paramValue=$(echo -e "${l_paramValue}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

              # shellcheck disable=SC2034
              l_paramDefaultValueMap["${l_paramName}"]="${l_paramValue}"
              info "加载参数默认值：${l_paramName}=>${l_paramValue}"
              ((l_k = l_k + 1))
            done
          fi

          stringToArray "${l_paramList}" "l_lines"
          l_lineCount="${#l_lines[@]}"
          for ((l_m=0; l_m < l_lineCount; l_m++ ));do
            l_paramItem="${l_lines[${l_m}]}"
            l_paramName=".${l_paramItem#*.}"
            l_paramName="${l_paramName%%\}*}"
            #去掉头部和尾部的空格。
            l_paramName=$(echo -e "${l_paramName}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
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

      ((l_j = l_j + 1))
    done

    ((l_i = l_i + 1))
  done

  if [ "${l_hasUndefineParam}" == "true" ];then
    error "项目配置文件中存在上述未定义的变量，请明确定义这些变量后再次尝试。"
  fi

}

#**********************私有方法-开始***************************#

function _deployServiceByDocker(){
  export gDefaultRetVal
  export gCiCdYamlFile
  export gHelmBuildOutDir
  export gDockerRepoName
  export gDockerRepoAccount
  export gDockerRepoPassword
  export gTempFileDir

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_shellOrYamlFile=$4
  local l_remoteInstallProxyShell=$5
  local l_localBaseDir=$6
  local l_remoteDir=$7

  local l_activeProfile
  local l_enableProxy
  local l_mode

  local l_i
  local l_nodeItems
  local l_nodeItem
  local l_array
  local l_ip
  local l_port
  local l_account

  local l_content
  local l_archType
  declare -A l_archTypeMap

  local l_proxyNode
  local l_localDir
  local l_offlinePackage

  local l_configMapFiles
  local l_configFile
  local l_nodeIps

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].activeProfile"
  l_activeProfile="${gDefaultRetVal}"

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].docker.${l_activeProfile}.enableProxy"
  l_enableProxy="${gDefaultRetVal}"

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].docker.mode"
  l_mode="${gDefaultRetVal}"

  #循环连接所有的服务节点，按架构类型进行分组。
  ((l_i = 0))
  while true; do
    readParam "${gCiCdYamlFile}" "deploy[${l_index}].docker.${l_activeProfile}.nodeIPs[${l_i}]"
    [[ "${gDefaultRetVal}" == "null" ]] && break
    [[ ! "${gDefaultRetVal}" ]] && error "${gCiCdYamlFile##*/}文件中deploy[${l_index}].docker.${l_activeProfile}.nodeIPs参数是空的"

    l_nodeItem="${gDefaultRetVal}"
    # shellcheck disable=SC2206
    l_array=(${l_nodeItem//|/ })
    l_ip="${l_array[0]}"
    l_port="${l_array[1]}"
    l_account="${l_array[2]}"

    info "检查服务器${l_ip}的硬件架构 ..."
    l_content=$(ssh -p "${l_port}" "${l_account}@${l_ip}" "uname -sm" )
    invokeExtendChain "onGetSystemArchInfo" "${l_content}"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "false" ]] && error "读取本地系统架构信息失败" || info "读取到当前系统架构为:${gDefaultRetVal}"
    l_archType="${gDefaultRetVal}"

    l_nodeItem="${l_archTypeMap[${l_archType}]},${l_nodeItem}"
    l_archTypeMap["${l_archType}"]="${l_nodeItem}"

    ((l_i = l_i + 1))
  done

  # shellcheck disable=SC2068
  for l_archType in ${!l_archTypeMap[@]};do
    #取同架构的第一个节点作为部署代理节点，将文件都上传到该节点上。
    #该节点应能免密SSH连接到其他节点上。该节点上应安装有ansible工具，可同时向多个服务器部署应用。
    l_proxyNode="${l_archTypeMap[${l_archType}]:1}"
    # shellcheck disable=SC2206
    l_nodeItems=(${l_proxyNode//,/ })
    for l_nodeItem in ${l_nodeItems[@]};do
      # shellcheck disable=SC2206
      l_array=(${l_nodeItem//|/ })
      l_ip="${l_array[0]}"
      l_port="${l_array[1]}"
      l_account="${l_array[2]}"

      # shellcheck disable=SC2088
      l_localDir="${l_localBaseDir}/${l_chartName}-${l_chartVersion}"
      if [ ! -d "${l_localDir}" ];then
        mkdir -p "${l_localDir}/config"
      fi

      l_offlinePackage="${l_chartName}-${l_chartVersion}-${l_archType//\//-}.tar.gz"
      if [ ! -f "${gHelmBuildOutDir}/${l_offlinePackage}" ];then
        if [ "${gDockerRepoName}" ];then
          warn "未在${gHelmBuildOutDir}目录中找到离线安装包文件：${l_offlinePackage}, 后续将尝试从${gDockerRepoName}仓库中拉取镜像"
        else
          error "未在${gHelmBuildOutDir}目录中找到离线安装包文件：${l_offlinePackage}, 请先执行docker构造过程，或者通过配置参数指定能拉取到目标镜像的docker仓库"
        fi
      else
        info "将离线安装包复制到本地deploy目录中"
        cp -f "${gHelmBuildOutDir}/${l_offlinePackage}" "${l_localDir}/${l_offlinePackage}"
      fi

      info "检测服务器${l_ip}是否已安装docker ..." "-n"
      l_content=$(ssh -p "${l_port}" "${l_account}@${l_ip}" "docker -v")
      l_content=$(echo -e "${l_content}" | grep -oP "command not found")
      [[ "${l_content}" ]] && error "服务器${l_ip}上未安装docker，请正确安装后再试。"
      info "已安装" "*"

      if [ "${l_mode}" == "docker-compose" ];then
        info "检测服务器${l_ip}是否已安装docker compose ..." "-n"
        l_content=$(ssh -p "${l_port}" "${l_account}@${l_ip}" "docker compose version")
        l_content=$(echo -e "${l_content}" | grep -oP "command not found")
        [[ "${l_content}" ]] && error "服务器${l_ip}上未安装docker compose，请正确安装后再试。"
        info "已安装" "*"
      fi

      info "将${l_shellOrYamlFile##*/}文件复制到本地${l_localDir##*/}目录中"
      scp "${l_shellOrYamlFile}" "${l_localDir}/${l_shellOrYamlFile##*/}"

      info "将${l_remoteInstallProxyShell##*/}文件复制到本地${l_localDir##*/}目录下"
      scp "${l_remoteInstallProxyShell}" "${l_localDir}/${l_remoteInstallProxyShell##*/}"

      info "在本地${l_localBaseDir##*/}目录下创建install.sh"
      l_nodeIps="${l_archTypeMap[${l_archType}]//,${l_proxyNode}/}"
      echo -e "#!/usr/bin/env bash\n source ${l_remoteDir}/${l_remoteInstallProxyShell##*/} \"${l_chartName}\" \"${l_chartVersion}\" \"${l_offlinePackage}\" \"${gDockerRepoName}\" \"${gDockerRepoAccount}\" \"${gDockerRepoPassword}\" \"${l_nodeIps}\"" > "${l_localDir}/install.sh"

      info "在服务器(${l_ip})上创建${l_remoteDir}目录"
      ssh -p "${l_port}" "${l_account}@${l_ip}" "rm -rf ${l_remoteDir} && mkdir -p ${l_remoteDir}"

      info "将本地${l_localBaseDir##*/}目录中的文件和子目录复制到服务器${l_ip}上的${l_remoteDir}目录中"
      scp -P "${l_port}" -r "${l_localDir}/" "${l_account}@${l_ip}:${l_remoteDir%/*}/"

      info "远程执行服务器${l_ip}上的脚本：${l_remoteDir}/install.sh"
      # shellcheck disable=SC2088
      ssh -p "${l_port}" "${l_account}@${l_ip}" "bash ${l_remoteDir}/install.sh"

      [[ "${l_enableProxy}" == "true" ]] && break

    done

  done
}

function _deployServiceInK8S() {
  export gDefaultRetVal
  export gShellExecuteResult
  export gCiCdYamlFile
  export gHelmBuildOutDir

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_localBaseDir=$4

  local l_activeProfile
  local l_apiServers
  local l_apiServer
  local l_apiServerIndex
  local l_maxIndex

  local l_namespaces
  local l_namespaceCount
  local l_namespace


  local l_errorLog
  local l_offlinePackage

  local l_array
  local l_ip
  local l_port
  local l_account
  local l_chartFile
  local l_settingFile

  local l_content
  local l_lines
  local l_lineCount
  local l_i
  local l_settingParams
  local l_customizedSetParams

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].activeProfile"
  l_activeProfile="${gDefaultRetVal}"

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].k8s.${l_activeProfile}.namespace"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == null ]] \
    && error "${gCiCdYamlFile##*/}文件中deploy[${l_index}].k8s.${l_activeProfile}.namespace参数缺失或未配置值"
  # shellcheck disable=SC2206
  l_namespaces=(${gDefaultRetVal})
  l_namespaceCount="${#l_namespaces[@]}"
  ((l_maxIndex = l_namespaceCount - 1))

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].k8s.${l_activeProfile}.apiServer"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == null ]] \
    && error "${gCiCdYamlFile##*/}文件中deploy[${l_index}].k8s.${l_activeProfile}.apiServer参数缺失或未配置值"
  # shellcheck disable=SC2206
  l_apiServers=(${gDefaultRetVal})
  ((l_apiServerIndex = 0))
  # shellcheck disable=SC2068
  for l_apiServer in ${l_apiServers[@]};do
    #确定命名空间
    l_namespace="${l_namespaces[${l_apiServerIndex}]}"
    [[ "${l_apiServerIndex}" -ge "${l_namespaceCount}" ]] && l_namespace="${l_namespaces[l_maxIndex]}"

    # shellcheck disable=SC2206
    l_array=(${l_apiServer//\|/ })
    l_ip="${l_array[0]}"
    l_port="${l_array[1]}"
    l_account="${l_array[2]}"

    info "查找Chart镜像文件和其对应的setting.conf文件..."
    findChartImage "${l_chartName}" "${l_chartVersion}"
    [[ ! "${gDefaultRetVal}" ]] && error "失败"
    # shellcheck disable=SC2206
    l_array=(${gDefaultRetVal})
    l_chartFile="${l_array[0]}"
    if [ "${#l_array[@]}" -gt 1 ];then
      l_settingFile="${l_array[1]}"
      #从文件中读取参数设置值对。
      # shellcheck disable=SC2002
      l_settingParams=$(cat "${l_settingFile}")
      l_settingParams="${l_settingParams%,*}"
    fi

    #如果dockerRepo参数配置有值，则需要更新image.registry参数的值。
    readParam "${gCiCdYamlFile}" "deploy[${l_index}].k8s.${l_activeProfile}.dockerRepo"
    if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
      # shellcheck disable=SC2206
      l_array=(${gDefaultRetVal//,/ })
      warn "更新集群内拉取docker镜像使用的仓库地址为: ${l_array[2]}"
      #多个同名参数的设置，以最后一个为准。因此可以直接追加参数的最新值。
      l_settingParams="${l_settingParams},image.registry=${l_array[2]}"
    fi

    #如果routeHosts参数配置有值，则需要更新gatewayRoute.host参数的值。
    readParam "${gCiCdYamlFile}" "deploy[${l_index}].k8s.${l_activeProfile}.routeHosts"
    if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
      # shellcheck disable=SC2206
      l_array=(${gDefaultRetVal//,/ })
      warn "更新网关配置中的绑定域名为: ${l_array[0]}"
      #多个同名参数的设置，以最后一个为准。因此可以直接追加参数的最新值。这里只取第一个。
      l_settingParams="${l_settingParams},gatewayRoute.host=${l_array[0]}"
    fi

    #自定义Helm命令行中set参数扩展
    invokeExtendPointFunc "onCustomizedSetParamsBeforeHelmInstall" "自定义Helm命令行中set参数扩展" \
      "${gCiCdYamlFile}" "${l_index}" "${l_activeProfile}"
    if [[ "${gShellExecuteResult}" == "true" && ${gDefaultRetVal} != "null" ]];then
      l_customizedSetParams="${gDefaultRetVal}"
    fi

    if [ "${l_customizedSetParams}" ];then
      l_settingParams="${l_settingParams},${l_customizedSetParams}"
      l_settingParams="${l_settingParams:1}"
    fi

    info "获取服务器上~/.kube/config文件的内容"
    ssh -p "${l_port}" "${l_account}@${l_ip}" "cat ~/.kube/config" > "${l_localBaseDir}/kube-config"

    info "先尝试卸载正在运行的${l_chartName}服务"
    l_content=$(helm uninstall "${l_chartName}" -n "${l_namespace}" --kubeconfig "${l_localBaseDir}/kube-config" 2>&1)
    l_errorLog=$(echo -e "${l_content}" | grep -ioP "^(.*)Error:(.*)$")
    if [ "${l_errorLog}" ];then
      warn "未找到正在运行的${l_chartName}服务:${l_errorLog}"
    else
      info "${l_chartName}服务卸载成功:\n${l_content}"
    fi

    if [ "${l_settingParams}" ];then
      info "再重新安装${l_chartName}服务:\nhelm install ${l_chartName} ${l_chartFile} --namespace ${l_namespace} --create-namespace --kubeconfig ${l_localBaseDir}/kube-config --set ${l_settingParams}"
      l_content=$(helm install "${l_chartName}" "${l_chartFile}" --namespace "${l_namespace}" --create-namespace --kubeconfig "${l_localBaseDir}/kube-config" --set "${l_settingParams}" 2>&1)
    else
      info "再重新安装${l_chartName}服务:\nhelm install ${l_chartName} ${l_chartFile} --namespace ${l_namespace} --create-namespace --kubeconfig ${l_localBaseDir}/kube-config"
      l_content=$(helm install "${l_chartName}" "${l_chartFile}" --namespace "${l_namespace}" --create-namespace --kubeconfig "${l_localBaseDir}/kube-config" 2>&1)
    fi

    l_errorLog=$(echo -e "${l_content}" | grep -ioP "^(.*)Error:(.*)$")
    if [ "${l_errorLog}" ];then
      error "${l_chartName}服务安装失败:\n${l_content}"
    else
      info "${l_chartName}服务安装成功:\n${l_content}"
    fi

    ((l_apiServerIndex = l_apiServerIndex + 1))
  done
}

function findChartImage() {
  export gDefaultRetVal
  export gHelmBuildOutDir
  export gChartRepoInstanceName
  export gChartRepoType

  local l_chartName=$1
  local l_chartVersion=$2

  local l_chartFile
  local l_settingFile
  local l_fileList
  local l_offlinePackage

  gDefaultRetVal=""

  l_chartFile="${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}/chart/${l_chartName}-${l_chartVersion}.tgz"
  info "优先从本地构建输出目录中查找chart镜像文件..." "-n"
  if [ ! -f "${l_chartFile}" ];then
    l_fileList=$(find "${gHelmBuildOutDir}" -maxdepth 1 -type f -name "${l_chartName}-${l_chartVersion}-*.tar.gz")
    if [ ! "${l_fileList}" ];then
      info "未找到" "*"
      if [ "${gChartRepoInstanceName}" ];then
        info "从Chart镜像仓库中拉取版本为${l_chartVersion}的${l_chartName}镜像..." "-n"
        pullChartImage "${gChartRepoType}" "${l_chartName}" "${l_chartVersion}" "${gChartRepoInstanceName}" \
          "${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}/chart"
        [[ ! -f "${l_chartFile}" ]] && error "拉取失败"
        info "拉取成功" "*"
      fi
    else
      l_offlinePackage="${l_fileList[0]}"
      mkdir -p "${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}"
      tar -zxf "${l_offlinePackage}" -C "${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}"
      # shellcheck disable=SC2181
      if [ "$?" -ne 0 ];then
        error "解压找到的服务离线安装包文件${l_offlinePackage##*/}失败"
      fi
    fi
  else
    info "查找成功" "*"
  fi

  if [ -f "${l_chartFile}" ];then
    l_settingFile="${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}/setting.conf"
    if [ ! -f "${l_settingFile}" ];then
      warn "未找到Chart镜像的setting.conf文件"
      gDefaultRetVal="${l_chartFile}"
      return
    fi
    gDefaultRetVal="${l_chartFile} ${l_settingFile}"
  fi

}

function _getDeployIndexByChartIndex(){
  export gDefaultRetVal

  local l_cicdYamlFile=$1
  local l_chartIndex=$2

  local l_chartName
  local l_packageIndex
  local l_packageName
  local l_deployIndex

  ((l_deployIndex = -1))
  readParam "${l_cicdYamlFile}" "chart[${l_chartIndex}].name"
  if [ "${gDefaultRetVal}" != "null" ];then
    l_chartName="${gDefaultRetVal}"
    getListIndexByPropertyName "${l_cicdYamlFile}" "package" "chartName" "${l_chartName}"
    l_packageIndex="${gDefaultRetVal}"
    if [ "${l_packageIndex}" -ge 0 ];then
      readParam "${l_cicdYamlFile}" "package[${l_packageIndex}].name"
      if [ "${gDefaultRetVal}" != "null" ];then
        l_packageName="${gDefaultRetVal}"
        getListIndexByPropertyName "${l_cicdYamlFile}" "deploy" "packageName" "${l_packageName}"
        l_deployIndex="${gDefaultRetVal}"
      fi
    fi
  fi
  gDefaultRetVal="${l_deployIndex}"
}

function _createDeployItem(){
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gLanguage
  export gCiCdTemplateFileName

  local l_cicdYamlFile=$1
  local l_chartIndex=$2
  local l_cicdConfigFile=$3

  local l_deployIndex
  local l_targetIndex
  local l_itemCount
  local l_templateFile

  _getDeployIndexByChartIndex "${l_cicdYamlFile}" "${l_chartIndex}"
  l_deployIndex="${gDefaultRetVal}"
  [[ "${l_deployIndex}" -eq -1 ]] && error "${l_cicdYamlFile}文件中缺少对应chart[${l_chartIndex}]的deploy列表项"

  readParam "${l_cicdYamlFile}" "deploy[${l_deployIndex}].name"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && error "${l_cicdYamlFile}文件中deploy[${l_deployIndex}].name异常：不存在或为空"

  #获取l_cicdConfigFile文件中对应的deploy项的序号
  getListIndexByPropertyName "${l_cicdConfigFile}" "deploy" "name" "${gDefaultRetVal}" "false" "${gCiCdYamlFile}"
  l_targetIndex="${gDefaultRetVal}"

  if [ "${l_targetIndex}" -eq -1 ];then
    info "向${l_cicdConfigFile##*/}文件中插入deploy[${l_deployIndex}]配置项"
    getListSize "${l_cicdConfigFile}" "deploy"
    l_targetIndex="${gDefaultRetVal}"
    readParam "${l_cicdYamlFile}" "deploy[${l_deployIndex}]"
    insertParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}]" "${gDefaultRetVal}"

    #从模板文件中读取deploy[${l_targetIndex}].name未替换成实际参数前的标识。
    #因为wydevops开始进行全局参数合并的时机是在实际参数值替换动作之前。
    l_templateFile="${gBuildScriptRootDir}/templates/config/${gLanguage}/_${gCiCdTemplateFileName}"
    [[ ! -f "${l_templateFile}" ]] && l_templateFile="${gBuildScriptRootDir}/templates/config/_${gCiCdTemplateFileName}"
    [[ ! -f "${l_templateFile}" ]] && error "wydevops脚本根目录中/templates/config/子目录下未找到_${gCiCdTemplateFileName}模板文件"
    readParam "${l_templateFile}" "deploy[${l_deployIndex}].name"
    info "更新deploy[${l_targetIndex}]配置项的name属性为：${gDefaultRetVal}"
    updateParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].name" "${gDefaultRetVal}"

    info "清除可忽略的其他参数..."
    deleteParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].packageName"
    deleteParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].deployTempDir"
    deleteParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].deleteTempDirAfterDeployed"
    deleteParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].docker.dockerRunShellGenerator"
    deleteParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].docker.dockerComposeYamlGenerator"
  fi

  gDefaultRetVal="${l_deployIndex} ${l_targetIndex}"
}

function _readValueOfListItemNames() {
  export gDefaultRetVal

  local l_cicdYamlFile=$1
  local l_listParamPath=$2

  local l_itemCount
  local l_i
  local l_paramName
  local l_paramNames

  gDefaultRetVal=""
  readParam "${l_cicdYamlFile}" "${l_listParamPath}"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" = "null" ]] && return

  l_itemCount=$(echo -e "${gDefaultRetVal}" | grep -oP "^(\-).*$" | wc -l)
  for ((l_i = 0; l_i < l_itemCount; l_i++));do
    readParam "${l_cicdYamlFile}" "${l_listParamPath}[${l_i}].name"
    l_paramName="${gDefaultRetVal}"
    l_paramNames="${l_paramNames},${l_paramName}"
  done
  gDefaultRetVal="${l_paramNames:1}"
}
#**********************私有方法-结束***************************#

#参数部署值Map
declare -A gParamDeployedValueMap
export gParamDeployedValueMap

#加载build阶段脚本库文件
loadExtendScriptFileForLanguage "deploy"

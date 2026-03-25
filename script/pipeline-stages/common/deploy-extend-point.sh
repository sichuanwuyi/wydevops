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
  local l_paramContentBlock

  #扫描gCiCdYamlFile文件中chart[?].deployment[?].configMaps参数，在指定的文件中查找”{{ .Values.* }}“格式的参数定义。
  #如果有则提取这些参数及其默认值，回写到项目中的ci-cd-config.yaml文件中。
  #如果ci-cd-config.yaml文件不存在，则创建之。并在其中添加deploy相关配置(包括参数列表)。

  info "common.deploy.extend.point.detecting.business.params"

  disableSaveBackImmediately
  l_saveBackStatus="${gDefaultRetVal}"

  l_cicdConfigFile="${gBuildPath}/${gCiCdConfigYamlFileName}"
  if [ ! -f "${l_cicdConfigFile}" ];then
    info "common.deploy.extend.point.creating.config.file" "${l_cicdConfigFile##*/}"
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

    #读取l_cicdConfigFile文件中的deploy[${l_targetIndex}].params内容块。
    readParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].params"
    l_paramContentBlock="${gDefaultRetVal}"

    info "common.deploy.extend.point.reading.param.names" "${l_cicdConfigFile##*/}#deploy[${l_targetIndex}].params#name"
    _readValueOfListItemNames "${l_paramContentBlock}"
    if [[ "${l_businessParamNames}" && "${l_businessParamNames}" != "null" ]];then
      l_businessParamNames="${l_businessParamNames},"
      l_businessParamIndex="${l_targetIndex}"
    fi

    # shellcheck disable=SC2068
    for l_configFile in ${l_configMapFiles[@]};do
      info "common.deploy.extend.point.detecting.vars.in.file" "${l_configFile##*/}"
      [[ "${l_configFile}" =~ ^(\./) ]] && l_configFile="${gBuildPath}/${l_configFile:2}"

      # shellcheck disable=SC2002
      l_paramList=$(grep -oE "\{\{[ ]+\.Values(\.[a-zA-Z0-9_\-]+)+[ ]*(\|[ ]*default .*)*[ ]+}}" "${l_configFile}" | sort | uniq -c)
      if [ "${l_paramList}" ];then
        ((l_paramIndex = -1))
        stringToArray "${l_paramList}" "l_lines"
        l_lineCount="${#l_lines[@]}"
        for ((l_i=0; l_i < l_lineCount; l_i++ ));do
          l_paramName=$(grep -oE ".Values(\.[a-zA-Z0-9_\-]+)+( |\|)" <<< "${l_lines[${l_i}]}")
          [[ "${l_paramName}" =~ ^(.*)\|$ ]] && l_paramName="${l_paramName%|*}"
          #去掉左右空格
          l_paramName="${l_paramName#"${l_paramName%%[![:space:]]*}"}"
          l_paramName="${l_paramName%"${l_paramName##*[![:space:]]}"}"

          l_paramValue=""
          if [[ "${l_lines[${l_i}]}" =~ ^(.*)(\|[ ]*default)(.*) ]];then
            l_paramValue="${l_lines[${l_i}]#*|}"
            l_paramValue="${l_paramValue%%\}*}"
            l_paramValue="${l_paramValue// default/}"

            #去掉头部和尾部的空格。
            l_paramValue="${l_paramValue#"${l_paramValue%%[![:space:]]*}"}"
            l_paramValue="${l_paramValue%"${l_paramValue##*[![:space:]]}"}"

            if [[ "${l_paramValue}" =~ ^(\") ]];then
              #去掉头尾引号
              l_paramValue="${l_paramValue/\"/}"
              l_paramValue="${l_paramValue%\"*}"
            fi
          fi

          #缓存参数及其值。
          gParamDeployedValueMap["${l_paramName}"]="${l_paramValue}"

          #不存在name=l_paramName的项，则插入之。
          getListIndexByPropertyNameQuickly "${l_cicdConfigFile}" "deploy[${l_targetIndex}].params" "name" \
            "${l_paramName}" "true" "${l_paramContentBlock}" "${l_paramIndex}" "${gCiCdYamlFile}"

          if [[ ! ("${gDefaultRetVal}" =~ ^(\-1)) ]];then
            # shellcheck disable=SC2206
            l_array=(${gDefaultRetVal})
            l_paramIndex="${l_array[1]}"
            info "common.deploy.extend.point.adding.new.param" "${l_cicdConfigFile##*/}#deploy[${l_targetIndex}].params[${l_paramIndex}]"
            l_itemValue="name: ${l_paramName}\nvalue: ${l_paramValue}"
            insertParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].params[${l_paramIndex}]" "${l_itemValue}"
          else
            info "common.deploy.extend.point.detected.business.param" "${l_paramName}" "-n"
            # shellcheck disable=SC2206
            l_array=(${gDefaultRetVal})
            l_paramIndex="${l_array[0]}"
            readParamInList "${l_paramContentBlock}" "${l_paramIndex}" "value"
            gParamDeployedValueMap["${l_paramName}"]="${l_paramValue}"
            if [ "${l_paramValue}" ];then
              info "${l_paramValue}" "" "*"
            else
              warn "common.deploy.extend.point.no.config.value" "" "*"
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
      warn "common.deploy.extend.point.clearing.unused.params" "${l_cicdConfigFile##*/}#deploy[${l_businessParamIndex}].params"
      # shellcheck disable=SC2206
      l_array=(${l_businessParamNames//,/ })
      # shellcheck disable=SC2068
      for l_paramName in ${l_array[@]};do
        warn "common.deploy.extend.point.clearing.unused.param" "${l_paramName}"
        getListIndexByPropertyNameQuickly "${l_cicdConfigFile}" "deploy[${l_businessParamIndex}].params" \
          "name" "${l_paramName}" "false" "${l_paramContentBlock}" "-1" "${gCiCdYamlFile}"
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
    invokeExtendPointFunc "onCheckAndInitialParamInConfigFile" "common.deploy.extend.point.check.and.init.params" "" \
      "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_localBaseDir}"
    #采用docker方式部署服务安装包前扩展
    invokeExtendPointFunc "onBeforeDeployingServicePackageByDockerMode" "common.deploy.extend.point.before.deploy.by.docker" "" "${l_index}" "${l_chartName}" \
      "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
  elif [ "${l_deployType}" == "k8s" ];then
    invokeExtendPointFunc "onBeforeDeployingServicePackageByK8sMode" "common.deploy.extend.point.before.deploy.by.k8s" "" "${l_index}" "${l_chartName}" \
      "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
  fi

}

function deployServicePackage_ex() {
  export gCurrentStageResult
  export gLogI18NRetVal

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_deployType=$4
  local l_installMode=$5
  local l_images=$6
  local l_remoteDir=$7
  local l_localBaseDir=$8
  local l_shellOrYamlFile=$9
  local l_remoteInstallProxyShell=${10}

  gCurrentStageResult=""
  if [ "${l_deployType}" == "docker" ];then
    #调用标准发布流程
    _deployServiceByDocker "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_shellOrYamlFile}" "${l_remoteInstallProxyShell}" "${l_localBaseDir}" "${l_remoteDir}" "${l_installMode}"
  else
    #调用标准发布流程
    _deployServiceInK8S "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_localBaseDir}" "${l_installMode}"
  fi
  if [ ! "${gCurrentStageResult}" ];then
    convertI18NText "common.deploy.extend.point.package.deployed.successfully" "${l_packageName}"
    gCurrentStageResult="INFO|${gLogI18NRetVal}"
  fi
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

  local l_activeProfile
  local l_shellOrYamlFile
  local l_remoteInstallProxyShell

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].activeProfile"
  l_activeProfile="${gDefaultRetVal}"

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].docker.mode"
  if [ "${gDefaultRetVal}" == "docker" ];then
    #获取docker-run.sh文件，该脚本文件的功能是执行docker run命令拉起服务。
    invokeExtendChain "onGenerateDockerRunShellFile" "${gBuildPath}" "${gBuildType}" "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_images}" "${l_remoteDir}" "${gDockerRepoName}" "${gDockerRepoAccount}" "${gDockerRepoPassword}"
    l_shellOrYamlFile="${gDefaultRetVal}"
  else
    #获取docker-compose.yaml文件，该文件是docker-compose命令的配置文件。
    invokeExtendChain "onGenerateDockerComposeYamlFile" "${gBuildPath}" "${gBuildType}" "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
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
  if ! command -v helm &> /dev/null; then
    #检查当前操作系统类型
    invokeExtendChain "onGetSystemArchInfo"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "false" ]] && error "common.deploy.extend.point.read.arch.failed" \
      || info "common.deploy.extend.point.read.arch.success" "${gDefaultRetVal}"
    #在本地系统中安装helm工具
    invokeExtendPointFunc "installHelm" "common.deploy.extend.point.install.helm" "" "${gDefaultRetVal%%/*}" "${gDefaultRetVal#*/}"
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

  getListIndexByPropertyNameQuickly "${gCiCdYamlFile}" "chart" "name" "${l_chartName}"
  [[  "${gDefaultRetVal}" =~ ^(\-1) ]] && error "common.deploy.extend.point.chart.not.found" "${gCiCdYamlFile##*/}#name=${l_chartName}#chart"
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
      info "common.deploy.extend.point.detect.and.process.vars.in.file" "${l_configFile##*/}"
      [[ "${l_configFile}" =~ ^(\./) ]] && l_configFile="${gBuildPath}/${l_configFile:2}"

      #拷贝配置文件到临时目录中。
      cp -f "${l_configFile}" "${l_localBaseDir}/${l_configFile##*/}"

      #切换到临时文件目录中的配置文件。
      l_configFile="${l_localBaseDir}/${l_configFile##*/}"

      #检测配置文件中是否存在动态配置的参数，如果存在则需要替换赋值。
      # shellcheck disable=SC2002
      l_paramList=$(grep -oE "\{\{[ ]+\.Values(\.[a-zA-Z0-9_\-]+)+[ ]*(\|[ ]*default .*)*[ ]+}}" "${l_configFile}" | sort | uniq -c)
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
          l_paramName="${l_paramName#"${l_paramName%%[![:space:]]*}"}"
          l_paramName="${l_paramName%"${l_paramName##*[![:space:]]}"}"

          l_result=$(grep -oE "${l_paramName}( |$)" <<< "${l_paramNameList}")
          if [ ! "${l_result}" ];then
            #如果参数的值未定义，则告警输出。
            l_hasUndefineParam="true"
            warn "common.deploy.extend.point.undefined.variable" "${l_configFile##*/}#${l_paramName}"
          fi

          l_paramValue="${gParamDeployedValueMap[${l_paramName}]}"
          #替换配置文件中的变量。
          l_paramItem="{${l_paramItem#*\{}"
          l_paramItem="${l_paramItem%\}*}"
          info "common.deploy.extend.point.replace.variable" "${l_configFile##*/}#${l_paramItem}#${l_paramValue}"
          sed -i "s/${l_paramItem}/${l_paramValue}/g" "${l_configFile}"

        done
      fi
    done

    ((l_loopIndex[1] = l_loopIndex[1] + 1))
  done

  if [ "${l_hasUndefineParam}" == "true" ];then
    error "common.deploy.extend.point.undefined.variables.exist"
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
  local l_forceDeployArchType
  local l_enableProxy
  local l_mode

  local l_i
  local l_nodeItems
  local l_nodeItem
  local l_array
  local l_ip
  local l_port
  local l_account
  local l_password

  local l_content
  local l_curArchType
  local l_archType
  declare -A l_archTypeMap

  local l_proxyNode
  local l_localDir
  local l_offlinePackage

  local l_configMapFiles
  local l_configFile
  local l_nodeIps
  local l_errorLog

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
    [[ ! "${gDefaultRetVal}" ]] && error "common.deploy.extend.point.node.ips.empty" "${gCiCdYamlFile##*/}#deploy[${l_index}].docker.${l_activeProfile}.nodeIPs"

    l_nodeItem="${gDefaultRetVal}"
    # shellcheck disable=SC2206
    l_array=(${l_nodeItem//|/ })
    l_ip="${l_array[0]}"
    l_port="${l_array[1]}"
    l_account="${l_array[2]}"
    l_password="${l_array[3]}"
    if [ "${#l_array[@]}" -gt 4 ];then
      l_forceDeployArchType="${l_array[4]}"
    fi

    info "common.deploy.extend.point.checking.server.arch" "${l_ip}"
    invokeExtendChain "onGetSystemArchInfo" "${l_ip}" "${l_port}" "${l_account}" "${l_password}"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "false" ]] && error "common.deploy.extend.point.read.server.arch.failed" "${l_ip}"
    info "common.deploy.extend.point.read.server.arch.success" "${l_ip}#${gDefaultRetVal}"
    l_archType="${gDefaultRetVal}"

    l_nodeItem="${l_archTypeMap[${l_archType}]},${l_nodeItem}"
    l_archTypeMap["${l_archType}"]="${l_nodeItem}"

    ((l_i = l_i + 1))
  done

  # shellcheck disable=SC2068
  for l_curArchType in ${!l_archTypeMap[@]};do
    if [ "${l_forceDeployArchType}" ];then
      l_archType="${l_forceDeployArchType}"
    else
      l_archType="${l_curArchType}"
    fi
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

      if [ "${gDockerRepoName}" ];then
        warn "common.deploy.extend.point.docker.repo.exists" "${gDockerRepoName}"
      else
        #如果没有设置镜像仓库，则继续尝试使用镜像导出文件或离线安装包进行部署。
        l_offlinePackage="${l_chartName}-${l_chartVersion}-${l_archType//\//-}.tar"
        info "common.deploy.extend.point.checking.image.export.file.exists" "${gHelmBuildOutDir}/${l_archType//\//-}#${l_offlinePackage}" "-n"
        if [ ! -f "${gHelmBuildOutDir}/${l_archType//\//-}/${l_offlinePackage}" ];then
          warn "common.deploy.extend.point.image.not.exists" "" "*"
          #如果没有找到docker镜像导出文件，则继续查找是否存在离线安装包。
          l_offlinePackage="${l_chartName}-${l_chartVersion}-${l_archType//\//-}.tar.gz"
          info "common.deploy.extend.point.checking.offline.package.file.exists" "${gHelmBuildOutDir}#${l_offlinePackage}" "-n"
          if [ ! -f "${gHelmBuildOutDir}/${l_offlinePackage}" ];then
            error "common.deploy.extend.point.image.not.exists" "" "*"
          else
            warn "common.deploy.extend.point.image.already.exists" "" "*"
            info "common.deploy.extend.point.copying.offline.package" "${l_offlinePackage}#${l_localDir}" "-n"
            #如果找到了离线安装包，则复制离线安装包到${l_localDir}目录中。
            l_errorLog=$(cp -f "${gHelmBuildOutDir}/${l_offlinePackage}" "${l_localDir}/${l_offlinePackage}" 2>&1)
            [[ "$?" -ne 0 ]] && error "common.deploy.extend.point.execute.command.failed" "${l_errorLog}" "*" || warn "common.deploy.extend.point.success" "" "*"
          fi
        else
          warn "common.deploy.extend.point.image.already.exists" "" "*"
          info "common.deploy.extend.point.copying.image.export.file" "${l_offlinePackage}#${l_localDir}" "-n"
          #如果存在docker镜像导出文件，则复制到${l_localDir}目录中。
          l_errorLog=$(cp -f "${gHelmBuildOutDir}/${l_archType//\//-}/${l_offlinePackage}" "${l_localDir}/${l_offlinePackage}" 2>&1)
          [[ "$?" -ne 0 ]] && error "common.deploy.extend.point.execute.command.failed" "${l_errorLog}" "*" || warn "common.deploy.extend.point.success" "" "*"
        fi
      fi

      info "common.deploy.extend.point.checking.docker.installed" "${l_ip}" "-n"
      l_content=$(timeout 3s ssh -o "StrictHostKeyChecking no" -p "${l_port}" "${l_account}@${l_ip}" "docker -v")
      #连接被拒绝或超时
      l_errorLog=$(grep -oE "(refused|timed[ ]*out)" <<< "${l_content}")
      [[ "${l_errorLog}" ]] && error "common.deploy.extend.point.ssh.connection.failed" "${l_ip}#${l_content}" "*"
      #命令不存在则报错退出。
      l_errorLog=$(grep -oE "not[ ]*found" <<< "${l_content}")
      [[ "${l_errorLog}" ]] && error "common.deploy.extend.point.docker.not.installed" "${l_ip}" "*"
      info "common.deploy.extend.point.installed" "" "*"

      if [ "${l_mode}" == "docker-compose" ];then
        info "common.deploy.extend.point.checking.docker-compose.installed" "${l_ip}" "-n"
        l_content=$(timeout 3s ssh -o "StrictHostKeyChecking no" -p "${l_port}" "${l_account}@${l_ip}" "docker compose version")
        #连接被拒绝或超时
        l_errorLog=$(grep -oE "(refused|timed[ ]*out)" <<< "${l_content}")
        [[ "${l_errorLog}" ]] && error "common.deploy.extend.point.ssh.connection.failed" "${l_ip}#${l_content}" "*"
        #命令不存在则报错退出。
        l_errorLog=$(grep -oE "not[ ]*found" <<< "${l_content}")
        [[ "${l_errorLog}" ]] && error "common.deploy.extend.point.docker-compose.not.installed" "${l_ip}" "*"
        info "common.deploy.extend.point.installed" "" "*"
      fi

      info "common.deploy.extend.point.copying.file.to.local.dir" "${l_shellOrYamlFile}#${l_localDir}"
      timeout 60s scp "${l_shellOrYamlFile}" "${l_localDir}/${l_shellOrYamlFile##*/}"

      info "common.deploy.extend.point.copying.file.to.local.dir" "${l_remoteInstallProxyShell##*/}#${l_localDir##*/}"
      timeout 60s scp "${l_remoteInstallProxyShell}" "${l_localDir}/${l_remoteInstallProxyShell##*/}"

      info "common.deploy.extend.point.creating.install.sh" "${l_localBaseDir##*/}#install.sh"
      l_nodeIps="${l_archTypeMap[${l_archType}]//,${l_proxyNode}/}"
      echo -e "#!/usr/bin/env bash\n source ${l_remoteDir}/${l_remoteInstallProxyShell##*/} \"${l_chartName}\" \"${l_chartVersion}\" \"${l_curArchType}\" \"${l_archType}\" \"${l_offlinePackage}\" \"${gDockerRepoName}\" \"${gDockerRepoAccount}\" \"${gDockerRepoPassword}\" \"${l_nodeIps}\"" > "${l_localDir}/install.sh"

      info "common.deploy.extend.point.creating.remote.dir" "${l_ip}#${l_remoteDir}"
      timeout 3s ssh -o "StrictHostKeyChecking no" -p "${l_port}" "${l_account}@${l_ip}" "rm -rf ${l_remoteDir} && mkdir -p ${l_remoteDir}"

      info "common.deploy.extend.point.copying.local.to.remote" "${l_localBaseDir##*/}#${l_ip}#${l_remoteDir}"
      timeout 60s scp -o \"StrictHostKeyChecking no\" -P "${l_port}" -r "${l_localDir}/" "${l_account}@${l_ip}:${l_remoteDir%/*}/"

      info "common.deploy.extend.point.executing.remote.script" "${l_ip}#${l_remoteDir}/install.sh"
      # shellcheck disable=SC2088
      timeout 30s ssh -o "StrictHostKeyChecking no" -p "${l_port}" "${l_account}@${l_ip}" "bash ${l_remoteDir}/install.sh"

      [[ "${l_enableProxy}" == "true" ]] && break

    done

  done
}

function _deployServiceInK8S() {
  export gDefaultRetVal
  export gShellExecuteResult
  export gCiCdYamlFile
  export gHelmBuildOutDir
  export gDockerRepoName
  export gDockerRepoInstanceName
  export gServiceName

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_localBaseDir=$4
  local l_installMode=$5

  local l_activeProfile
  local l_apiServers
  local l_apiServer
  local l_apiServerIndex
  local l_maxIndex

  local l_namespaces
  local l_namespaceCount
  local l_namespace

  local l_forceDeployArchType
  local l_localArchType

  local l_errorLog
  local l_offlinePackage

  local l_array
  local l_ip
  local l_port
  local l_account
  local l_password

  local l_chartFile
  local l_settingFile

  local l_content
  local l_lines
  local l_lineCount
  local l_i
  local l_settingParams
  local l_tmpParam
  local l_customizedSetParams

  local l_repoInfos
  local l_tmpIndex
  local l_paramName
  local l_paramValue

  local l_content

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].activeProfile"
  l_activeProfile="${gDefaultRetVal}"

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].k8s.${l_activeProfile}.namespace"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == null ]] \
    && error "common.deploy.extend.point.param.missing" "${gCiCdYamlFile##*/}#deploy[${l_index}].k8s.${l_activeProfile}.namespace"
  # shellcheck disable=SC2206
  l_namespaces=(${gDefaultRetVal//,/ })
  l_namespaceCount="${#l_namespaces[@]}"
  ((l_maxIndex = l_namespaceCount - 1))

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].k8s.${l_activeProfile}.apiServer"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == null ]] \
    && error "common.deploy.extend.point.param.missing" "${gCiCdYamlFile##*/}#deploy[${l_index}].k8s.${l_activeProfile}.apiServer"
  # shellcheck disable=SC2206
  l_apiServers=(${gDefaultRetVal//,/ })
  ((l_apiServerIndex = 0))
  # shellcheck disable=SC2068
  for l_apiServer in ${l_apiServers[@]};do
    #确定命名空间
    if [ "${l_apiServerIndex}" -ge "${l_namespaceCount}" ];then
      l_namespace="${l_namespaces[l_maxIndex]}"
    else
      l_namespace="${l_namespaces[${l_apiServerIndex}]}"
    fi

    # shellcheck disable=SC2206
    l_array=(${l_apiServer//\|/ })
    l_ip="${l_array[0]}"
    l_port="${l_array[1]}"
    l_account="${l_array[2]}"
    l_password="${l_array[3]}"
    #确定要发布的目标架构类型
    if [ "${#l_array[@]}" -gt 4 ];then
      l_forceDeployArchType="${l_array[4]}"
    fi

    info "common.deploy.extend.point.finding.chart.image.and.settings"
    _findChartImage "${l_chartName}" "${l_chartVersion}"
    [[ ! "${gDefaultRetVal}" ]] && error "common.deploy.extend.point.finding.chart.image.failed"

    # shellcheck disable=SC2206
    l_array=(${gDefaultRetVal})
    l_chartFile="${l_array[0]}"
    if [ "${#l_array[@]}" -gt 1 ];then
      l_settingFile="${l_array[1]}"
      #从文件中读取参数设置值对。
      readParam "${l_settingFile}" "${gServiceName}"
      l_settingParams="${gDefaultRetVal%,*}"
      #多行转成单行。
      #l_settingParams=$(echo "${l_settingParams}" | tr -d '\n' | sed 's/,[[:space:]]*/,/g')
      l_settingParams=$(sed -e ':a;N;$!ba;s/\n//g' -e 's/,[[:space:]]\+/,/g' <<< "${l_settingParams}")
    fi
    info "common.deploy.extend.point.reading.params.from.cicd" "${gCiCdYamlFile##*/}#deploy[${l_index}].params"

    readParam "${gCiCdYamlFile}" "deploy[${l_index}].params"
    l_content="${gDefaultRetVal}"

    l_tmpIndex=0
    while true;do
      readParamInList "${l_content}" "${l_tmpIndex}" "name"
      [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && break

      #得到参数名称
      # shellcheck disable=SC2001
      l_paramName=$(echo "${gDefaultRetVal}" | sed 's/\.Values\.//g')

      #去掉头部和尾部的空格。
      l_paramName="${l_paramName#"${l_paramName%%[![:space:]]*}"}"
      l_paramName="${l_paramName%"${l_paramName##*[![:space:]]}"}"

      readParamInList "${l_content}" "${l_tmpIndex}" "value"
      if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
        l_paramValue="${gDefaultRetVal}"
        #去掉头部和尾部的空格。
        l_paramValue="${l_paramValue#"${l_paramValue%%[![:space:]]*}"}"
        l_paramValue="${l_paramValue%"${l_paramValue##*[![:space:]]}"}"

        # 使用正则表达式替换已存在的参数
        l_settingParams=$(echo "${l_settingParams}" | sed -r "s/(^|,)(${l_paramName})=[^,]*(,|$)/\1\2=${l_paramValue}\3/g")
        # 如果替换后没有变化则追加参数
        [[ "${l_settingParams}" == *"${l_paramName}="* ]] || l_settingParams="${l_settingParams},${l_paramName}=${l_paramValue}"
      fi
      ((l_tmpIndex = l_tmpIndex + 1))
    done

    #如果dockerRepo参数配置有值且与当前使用的docker镜像仓库不是同一个，则需要推送docker镜像到新的仓库中。
    readParam "${gCiCdYamlFile}" "deploy[${l_index}].k8s.${l_activeProfile}.dockerRepo"
    if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
      #调用解密接口解密l_repoInfo参数值。
      invokeExtendPointFunc "decodeSecretInfo" "common.secret.extend.point.decoding.secret.info" \
        "dockerRepo" "dockerRepo" "${gDefaultRetVal}"
      l_repoInfos="${gDefaultRetVal}"

      # shellcheck disable=SC2206
      l_array=(${l_repoInfos//,/ })
      warn "common.deploy.extend.point.updating.image.repo.address" "${l_array[2]}"

      info "common.deploy.extend.point.pushing.images.to.k8s.repo"
      readParam "${gCiCdYamlFile}" "deploy[${l_index}].packageName"
      _pushDockerImageForDeployStage "${gDefaultRetVal}" "${l_repoInfos}" "${l_chartFile}" "${l_ip}" "${l_port}" \
        "${l_account}" "${l_password}" "${l_forceDeployArchType}"

      l_localArchType="${gDefaultRetVal}"

      if [[ "${l_forceDeployArchType}" && "${l_localArchType}" != "${l_forceDeployArchType}" ]];then
        _install_tonistiigi_binfmt_in_k8s "${l_forceDeployArchType}" "${l_array[2]}"
        l_settingParams=$(echo "${l_settingParams}" | sed 's/image\.archType=,//g')
        [[ "${l_settingParams}" == *"image.archType="* ]] || l_settingParams="${l_settingParams},image.archType=-${l_forceDeployArchType//\//-}"
      fi

      # 使用正则表达式替换已存在的参数
      # shellcheck disable=SC2001
      l_settingParams=$(echo "${l_settingParams}" | sed "s/\(image\.registry\)=[^,]*\(,\|\\n\|$\)/\1=${l_array[2]//\//\\\/}\2/g")
      [[ "${l_settingParams}" == *"image.registry="* ]] || l_settingParams="${l_settingParams},image.registry=${l_array[2]}"
    fi

    #如果routeHosts参数配置有值，则需要更新gatewayRoute.host参数的值。
    readParam "${gCiCdYamlFile}" "deploy[${l_index}].k8s.${l_activeProfile}.routeHosts"
    if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
      # shellcheck disable=SC2206
      l_array=(${gDefaultRetVal//,/ })
      warn "common.deploy.extend.point.updating.gateway.domain" "${l_array[0]}"
      l_settingParams=$(echo "$l_settingParams" | sed "s/\(gatewayRoute\.host\)=[^,]*\(,\|\\n\|$\)/\1=${l_array[0]//\//\\\/}\2/g")
      [[ "$l_settingParams" == *"gatewayRoute.host="* ]] || l_settingParams="${l_settingParams},gatewayRoute.host=${l_array[0]}"
    fi

    #自定义Helm命令行中set参数扩展
    invokeExtendPointFunc "onCustomizedSetParamsBeforeHelmInstall" "common.deploy.extend.point.custom.set.params" "" \
      "${gCiCdYamlFile}" "${l_index}" "${l_activeProfile}"
    if [[ "${gShellExecuteResult}" == "true" && ${gDefaultRetVal} != "null" ]];then
      l_customizedSetParams="${gDefaultRetVal}"
    fi

    if [ "${l_customizedSetParams}" ];then
      l_settingParams="${l_settingParams},${l_customizedSetParams}"
    fi

    info "common.deploy.extend.point.getting.kube.config"
    if [[ "${l_password}" =~ ^(.*).pem$ ]];then
      ssh -i "${l_password}" -p "${l_port}" "${l_account}@${l_ip}" "cat ~/.kube/config" > "${l_localBaseDir}/kube-config"
      if [ "$?" -ne "0" ];then
        warn "common.deploy.extend.point.get.kube.config.failed" "${l_ip}"
        cat ~/.kube/config > "${l_localBaseDir}/kube-config"
      fi
    else
      #todo: 这里不要在前面添加timeout指令
      ssh -o "StrictHostKeyChecking no" -p "${l_port}" "${l_account}@${l_ip}" "cat ~/.kube/config" > "${l_localBaseDir}/kube-config"
    fi

    if [[ "${l_installMode}" == "install" || "${l_installMode}" == "uninstall" ]];then
      info "common.deploy.extend.point.uninstalling.service" "${l_namespace}#${l_chartName}" "-n"
      l_content=$(helm uninstall "${l_chartName}" -n "${l_namespace}" --kubeconfig "${l_localBaseDir}/kube-config" 2>&1)
      l_errorLog=$(grep -oE "^(.*)Error:(.*)$" <<< "${l_content}")
      if [ "${l_errorLog}" ];then
        warn "common.deploy.extend.point.service.not.found" "${l_chartName}#${l_errorLog}" "*"
      else
        info "common.deploy.extend.point.success" "" "*"
      fi
      if [ "${l_installMode}" == "uninstall" ];then
        info "common.deploy.extend.point.uninstall.mode.exit"
        exit 0
      fi
    fi

    if [ "${l_installMode}" == "upgrade" ];then
      l_installMode="upgrade --install"
    fi

    #等待3秒
    sleep 3s

    if [ ! -f "${l_chartFile}" ];then
      l_chartFile="${l_chartName} --version ${l_chartVersion}"
    fi

    if [ "${l_settingParams}" ];then
      [[ "${l_settingParams}" =~ ^(,) ]] && l_settingParams="${l_settingParams:1}"
      info "common.deploy.extend.point.reinstalling.service.with.params" "${l_chartName}#helm ${l_installMode} ${l_chartName} ${l_chartFile} --namespace ${l_namespace} --create-namespace --kubeconfig ${l_localBaseDir}/kube-config --set ${l_settingParams}"
      l_content=$(helm ${l_installMode} "${l_chartName}" "${l_chartFile}" --namespace "${l_namespace}" --create-namespace --kubeconfig "${l_localBaseDir}/kube-config" --set "${l_settingParams}" 2>&1)
    else
      info "common.deploy.extend.point.reinstalling.service.with.params" "${l_chartName}#helm ${l_installMode} ${l_chartName} ${l_chartFile} --namespace ${l_namespace} --create-namespace --kubeconfig ${l_localBaseDir}/kube-config"
      l_content=$(helm ${l_installMode} "${l_chartName}" "${l_chartFile}" --namespace "${l_namespace}" --create-namespace --kubeconfig "${l_localBaseDir}/kube-config" 2>&1)
    fi

    l_errorLog=$(grep -oE "^(.*)Error:(.*)$" <<< "${l_content}")
    if [ "${l_errorLog}" ];then
      error "common.deploy.extend.point.service.install.failed" "${l_chartName}#${l_content}"
    else
      info "common.deploy.extend.point.service.install.success" "${l_chartName}#${l_content}"
    fi

    ((l_apiServerIndex = l_apiServerIndex + 1))
  done
}

function _findChartImage() {
  export gDefaultRetVal
  export gHelmBuildOutDir
  export gChartRepoInstanceName
  export gChartRepoType
  export gChartRepoName
  export gChartRepoAccount
  export gChartRepoPassword

  local l_chartName=$1
  local l_chartVersion=$2

  local l_chartFile
  local l_settingFile
  local l_fileList
  local l_offlinePackage

  gDefaultRetVal=""

  l_chartFile="${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}/chart/${l_chartName}-${l_chartVersion}.tgz"
  info "common.deploy.extend.point.finding.chart.image.locally" "" "-n"
  if [ ! -f "${l_chartFile}" ];then
    info "common.deploy.extend.point.not.found" "" "*"
    info "common.deploy.extend.point.finding.offline.package" "${gHelmBuildOutDir}#${l_chartName}-${l_chartVersion}-*.tar.gz" "-n"
    l_fileList=$(find "${gHelmBuildOutDir}" -maxdepth 1 -type f -name "${l_chartName}-${l_chartVersion}-*.tar.gz")
    if [ ! "${l_fileList}" ];then
      info "common.deploy.extend.point.not.found" "" "*"
      if [ "${gChartRepoInstanceName}" ];then
        info "common.deploy.extend.point.pulling.from.repo" "${l_chartVersion}#${l_chartName}" "-n"
        pullChartImage "${l_chartName}" "${l_chartVersion}" "${gChartRepoType}" "${gChartRepoName}" \
          "${gChartRepoInstanceName}" "${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}/chart" \
          "${gChartRepoAccount}" "${gChartRepoPassword}"
        [[ ! -f "${l_chartFile}" ]] && error "common.deploy.extend.point.failed" "" "*"
        info "common.deploy.extend.point.success" "" "*"
      fi
    else
      info "common.deploy.extend.point.found.success" "" "*"
      info "common.deploy.extend.point.unzip.offline.package" "${l_offlinePackage}#${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}" "-n"
      l_offlinePackage="${l_fileList[0]}"
      mkdir -p "${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}"
      tar -zxf "${l_offlinePackage}" -C "${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}"
      # shellcheck disable=SC2181
      if [ "$?" -ne 0 ];then
        error "common.deploy.extend.point.failed" "" "*"
      fi
      info "common.deploy.extend.point.success" "" "*"
    fi
  else
    info "common.deploy.extend.point.found.success" "" "*"
  fi

  if [ -f "${l_chartFile}" ];then
    l_settingFile="${gHelmBuildOutDir}/${l_chartName}-${l_chartVersion}/settings.yaml"
    if [ ! -f "${l_settingFile}" ];then
      warn "common.deploy.extend.point.settings.yaml.not.found"
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
    getListIndexByPropertyNameQuickly "${l_cicdYamlFile}" "package" "chartName" "${l_chartName}"
    l_packageIndex="${gDefaultRetVal}"
    if [ "${l_packageIndex}" -ge 0 ];then
      readParam "${l_cicdYamlFile}" "package[${l_packageIndex}].name"
      if [ "${gDefaultRetVal}" != "null" ];then
        l_packageName="${gDefaultRetVal}"
        getListIndexByPropertyNameQuickly "${l_cicdYamlFile}" "deploy" "packageName" "${l_packageName}"
        l_deployIndex="${gDefaultRetVal}"
      fi
    fi
  fi
  gDefaultRetVal="${l_deployIndex}"
}

function _createDeployItem(){
  export gDefaultRetVal
  export gBuildPath
  export gHelmBuildDirName
  export gBuildScriptRootDir
  export gLanguage
  export gCiCdTemplateFileName

  local l_cicdYamlFile=$1
  local l_chartIndex=$2
  local l_cicdConfigFile=$3

  local l_deployIndex
  local l_targetIndex
  local l_templateFile

  _getDeployIndexByChartIndex "${l_cicdYamlFile}" "${l_chartIndex}"
  l_deployIndex="${gDefaultRetVal}"
  [[ "${l_deployIndex}" -eq -1 ]] && error "common.deploy.extend.point.deploy.item.missing" "${l_cicdYamlFile}#chart[${l_chartIndex}]"

  readParam "${l_cicdYamlFile}" "deploy[${l_deployIndex}].name"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && error "common.deploy.extend.point.deploy.name.missing" "${l_cicdYamlFile}#deploy[${l_deployIndex}].name"

  #获取l_cicdConfigFile文件中对应的deploy项的序号
  getListIndexByPropertyNameQuickly "${l_cicdConfigFile}" "deploy" "name" "${gDefaultRetVal}" "false" "" "-1" "${gCiCdYamlFile}"
  l_targetIndex="${gDefaultRetVal}"

  if [ "${l_targetIndex}" -eq -1 ];then
    info "common.deploy.extend.point.inserting.deploy.item" "${l_cicdConfigFile##*/}#deploy[${l_deployIndex}]"
    getListSize "${l_cicdConfigFile}" "deploy"
    l_targetIndex="${gDefaultRetVal}"
    insertParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].name" ""
    insertParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].params" ""

    #从模板文件中读取deploy[${l_targetIndex}].name未替换成实际参数前的标识。
    #因为wydevops开始进行全局参数合并的时机是在实际参数值替换动作之前。
    l_templateFile="${gBuildPath}/${gHelmBuildDirName}/templates/config/${gLanguage}/_${gCiCdTemplateFileName}"
    [[ ! -f "${l_templateFile}" ]] && l_templateFile="${gBuildScriptRootDir}/templates/config/${gLanguage}/_${gCiCdTemplateFileName}"
    [[ ! -f "${l_templateFile}" ]] && l_templateFile="${gBuildScriptRootDir}/templates/config/_${gCiCdTemplateFileName}"
    [[ ! -f "${l_templateFile}" ]] && error "common.deploy.extend.point.template.not.found" "_${gCiCdTemplateFileName}"
    readParam "${l_templateFile}" "deploy[${l_deployIndex}].name"
    info "common.deploy.extend.point.updating.deploy.name" "deploy[${l_targetIndex}]#${gDefaultRetVal}"
    updateParam "${l_cicdConfigFile}" "deploy[${l_targetIndex}].name" "${gDefaultRetVal}"

  fi

  gDefaultRetVal="${l_deployIndex} ${l_targetIndex}"
}

function _readValueOfListItemNames() {
  export gDefaultRetVal

  local l_paramDefineBlock=$1

  local l_tmpContent
  local l_tmpSpaceNum
  local l_tmpSpaceNum1
  local l_lineCount
  local l_paramLines
  local l_tmpLineArray

  local l_i
  local l_paramName
  local l_paramNames

  gDefaultRetVal=""
  [ ! "${l_paramDefineBlock}" ] && return

  _getMatchedLines "${l_paramDefineBlock}" "^([ ]*\- .*$)" "first"
  l_tmpContent="${gDefaultRetVal#*:}"
  #获取前导空格数量。
  l_tmpContent="${l_tmpContent%%[^ ]*}"  # 提取行首连续空格
  l_tmpSpaceNum=${#l_tmpContent}         # 直接获取空格数量

  l_lineCount=$(grep -cE "^[ ]{${l_tmpSpaceNum}}\- " <<< "${l_paramDefineBlock}")

  #从l_paramDefineBlock中提前l_paramName参数定义所在的行内容。
  ((l_tmpSpaceNum1 = l_tmpSpaceNum + 2))
  l_paramLines=$(grep -E "^([ ]{${l_tmpSpaceNum}}\- |[ ]{${l_tmpSpaceNum1}})name:(.*)$" <<< "${l_paramDefineBlock}")
  # 将多行内容转换为数组
  mapfile -t l_tmpLineArray <<< "${l_paramLines}"

  for ((l_i = 0; l_i < l_lineCount; l_i++));do
    l_paramName="${l_tmpLineArray[${l_i}]#*:}"
    l_paramNames="${l_paramNames},${l_paramName}"
  done
  gDefaultRetVal="${l_paramNames:1}"
}

function _pushDockerImageForDeployStage() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gHelmBuildOutDir
  export gServiceName
  export gForceCoverage
  export gImageCacheDir
  export gRunID

  local l_packageName=$1
  local l_dockerRepoInfo=$2
  local l_chartFile=$3
  local l_ip=$4
  local l_port=$5
  local l_account=$6
  local l_password=$7
  local l_forceDeployArchType=$8

  local l_packageIndex
  local l_images
  local l_image
  local l_archType
  local l_localArchType
  local l_array
  local l_dockerOutDir
  local l_tmpFile
  local l_executeResult

  #aws-ecr,ylzt,749059848629.dkr.ecr.us-east-2.amazonaws.com,ec2-user,Ylzt-Mall-Key.pem,80
  local l_repoType
  local l_repoName
  local l_repoHostAndPort
  local l_repoAccount
  local l_repoPassword
  local l_addPrefix
  local l_pushedImageFile
  local l_key

  info "common.deploy.extend.point.checking.server.arch" "${l_ip}"
  invokeExtendChain "onGetSystemArchInfo" "${l_ip}" "${l_port}" "${l_account}" "${l_password}"
  # shellcheck disable=SC2015
  [[ "${gDefaultRetVal}" == "false" ]] && error "common.deploy.extend.point.read.server.arch.failed" "${l_ip}"
  info "common.deploy.extend.point.read.server.arch.success" "${l_ip}#${gDefaultRetVal}"
  l_localArchType="${gDefaultRetVal}"

  #获取需要推送的镜像名称信息。
  _getDockerImageInChart "${l_packageName}" "${l_chartFile}"
  if [ ! "${gDefaultRetVal}" ];then
    warn "common.deploy.extend.point.docker.image.not.found"
    gDefaultRetVal="${l_localArchType}"
    return
  fi

  if [[ ! "${l_forceDeployArchType}" || "${l_localArchType}" == "${l_forceDeployArchType}" ]];then
    l_archType="${l_localArchType}"
  else
    l_archType="${l_forceDeployArchType}"
  fi

  # shellcheck disable=SC2206
  l_images=(${gDefaultRetVal//,/ })

  #获取到需要推送的镜像
  # shellcheck disable=SC2206
  l_array=(${l_dockerRepoInfo//,/ })

  l_repoType="${l_array[0]}"
  l_instanceName="${l_array[1]}"
  l_repoName="${l_array[2]}"
  l_repoAccount="${l_array[3]}"
  l_repoPassword="${l_array[4]}"
  l_dockerRepoWebPort="${l_array[5]}"

  l_pushedImageFile="${gHelmBuildOutDir}/${l_archType//\//-}/pushed-images.yaml"

  # shellcheck disable=SC2068
  for l_image in ${l_images[@]};do
    #从docker构建输出目录中获取l_image镜像。
    l_dockerOutDir="${l_image//\//_}"
    l_dockerOutDir="${l_dockerOutDir//:/-}"
    l_tmpFile="${gHelmBuildOutDir}/${l_archType//\//-}/${l_dockerOutDir}-${l_archType//\//-}.tar"
    info "common.deploy.extend.point.finding.docker.image.export.file" "${l_tmpFile##*/}" "-n"
    if [ ! -f "${l_tmpFile}" ];then
      warn "common.deploy.extend.point.failed" "" "*"
      l_tmpFile="${gImageCacheDir}/${l_dockerOutDir}-${l_archType//\//-}.tar"
      warn "common.deploy.extend.point.finding.docker.image.export.file.in.cache" "${l_tmpFile}" "-n"
      if [ ! -f "${l_tmpFile}" ];then
        error "common.deploy.extend.point.failed" "" "*"
      fi
    fi
    info "common.deploy.extend.point.success" "" "*"

    info "common.deploy.extend.point.loading.docker.image.from.file" "${l_tmpFile##*/}#${l_image}" "-n"
    l_executeResult=$(docker load -i "${l_tmpFile}" 2>&1)
    if [ "$?" -ne 0 ];then
      error "common.deploy.extend.point.execute.command.failed" "${l_executeResult}" "*"
    fi
    info "common.deploy.extend.point.success" "" "*"

    if [ -f "${l_pushedImageFile}" ];then
      info "common.deploy.extend.point.reading.runid.from.file" "${l_pushedImageFile}#${l_image}" "-n"
      l_key="${l_image//:/@}"
      l_key="${l_key//./_}"
      readParam "${l_pushedImageFile}" "images.${l_key}"
      info "common.deploy.extend.point.current.runid" "${gDefaultRetVal}" "*"
      if [ "${gDefaultRetVal}" == "${gRunID}" ];then
        warn "common.deploy.extend.point.image.already.pushed"
        continue
      fi
    fi

    #完成docker仓库登录
    invokeExtendChain "onDockerLogin" "${l_repoType}" "${l_repoName}" "${l_repoAccount}" "${l_repoPassword}"

    #先删除已经存在的镜像。
    invokeExtendChain "onBeforePushDockerImage" "${l_repoType}" "${l_image}" "${l_archType}" "${gForceCoverage}" "${l_repoName}" \
                "${l_instanceName}" "${l_dockerRepoWebPort}" "${l_repoAccount}" "${l_repoPassword}"
    if [ "${gDefaultRetVal}" == "true|false" ];then
      warn "common.deploy.extend.point.image.exists.skipping"
      continue
    fi

    info "common.deploy.extend.point.pushing.image.to.repo" "${l_image}#${l_repoName}" "-n"
    invokeExtendChain "onPushDockerImage" "${l_repoType}" "${l_image}" "${l_archType}" "${l_repoName}" "${l_instanceName}"
    #删除之前加载的docker镜像
    l_executeResult=$(docker rmi -f "${l_image}" 2>&1)
    if [ "${gDefaultRetVal}" != "true" ];then
      error "common.deploy.extend.point.image.push.failed" "${l_image}" "*"
    else
      info "common.deploy.extend.point.image.push.success" "${l_image}" "*"
    fi

  done

  gDefaultRetVal="${l_localArchType}"
}

function _getDockerImageInChart() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gServiceName
  export gDockerRepoInstanceName
  export gDockerImageNameWithInstance
  export gDockerRepoType

  local l_packageName=$1
  local l_chartFile=$2

  local l_packageIndex
  local l_images

  local l_baseVersion
  local l_businessVersion

  local l_registryKey
  local l_result
  local l_lines
  local l_lineCount
  local l_i
  local l_line
  local l_prefix

  getListIndexByPropertyNameQuickly "${gCiCdYamlFile}" "package" "name" "${l_packageName}"
  if [[ "${gDefaultRetVal}" -eq -1 ]];then
    warn "common.deploy.extend.point.package.item.not.found" "${gCiCdYamlFile##*/}#${l_packageName}"
  else
    l_packageIndex="${gDefaultRetVal}"
    readParam "${gCiCdYamlFile}" "package[${l_packageIndex}].images"
    if [[ "${gDefaultRetVal}" ]];then
      l_images="${gDefaultRetVal}"
    else
      warn "common.deploy.extend.point.package.images.empty" "${gCiCdYamlFile##*/}#package[${l_packageIndex}].images"
    fi
  fi

  l_prefix=""
  #if [[ "${gDockerRepoType}" == "harbor" || ("${gDockerRepoInstanceName}" && "${gDockerImageNameWithInstance}" == "true") ]];then
  if [[ "${gDockerRepoType}" == "harbor" ]];then
    l_prefix="${gDockerRepoInstanceName}/"
  fi

  readParam "${gCiCdYamlFile}" "globalParams.buildType"
  if [ "${gDefaultRetVal}" == "single" ];then
    #删除基础镜像
    readParam "${gCiCdYamlFile}" "globalParams.baseVersion"
    l_baseVersion="${gDefaultRetVal}"
    l_result="${l_prefix}${gServiceName}-base:${l_baseVersion}"
    l_images="${l_images//${l_result}/}"
    l_images="${l_images//,,/,}"
    #删除业务镜像
    readParam "${gCiCdYamlFile}" "globalParams.businessVersion"
    l_businessVersion="${gDefaultRetVal}"
    l_result="${l_prefix}${gServiceName}-business:${l_businessVersion}"
    l_images="${l_images//${l_result}/}"
    l_images="${l_images//,,/,}"
    #添加单一镜像
    if [[ ! ("${l_images}" =~ ^(.*)${l_prefix}${gServiceName}:${l_businessVersion}(.*)$) ]];then
      l_images="${l_images},${l_prefix}${gServiceName}:${l_businessVersion}"
      l_images="${l_images//,,/,}"
    fi
  elif [ "${gDefaultRetVal}" == "base" ];then
    #删除业务镜像
    readParam "${gCiCdYamlFile}" "globalParams.businessVersion"
    l_businessVersion="${gDefaultRetVal}"
    l_result="${l_prefix}${gServiceName}-business:${l_businessVersion}"
    l_images="${l_images//${l_result}/}"
    l_images="${l_images//,,/,}"
  elif [ "${gDefaultRetVal}" == "business" ];then
    #删除基础镜像
    readParam "${gCiCdYamlFile}" "globalParams.baseVersion"
    l_baseVersion="${gDefaultRetVal}"
    l_result="${l_prefix}${gServiceName}-base:${l_baseVersion}"
    l_images="${l_images//${l_result}/}"
    l_images="${l_images//,,/,}"
  fi

  if [ "${l_images}" ];then
    gDefaultRetVal="${l_images}"
    return
  fi

  #如果没有从配置文件中读取到，则尝试从chart镜像中获取。
  #todo: 这里说明一下，为什么不直接从chart镜像中获取而先要从配置文件中读取？ 这是为了留一个上传其他镜像到仓库的接口。某些情况下需要上传chart镜像中没有使用的镜像。
  gDefaultRetVal=""

  l_registryKey="wydevops${RANDOM}"
  l_result=$(helm template "${l_chartFile}" -n test --set image.registry=${l_registryKey} 2>&1)
  if [ "$?" != 0 ];then
    l_result=$(grep -E "^.*(Error|failed).*$" <<< "${l_result}")
    error "common.deploy.extend.point.helm.template.failed" "${l_result}"
  fi

  l_result=$(grep -oE "^([ ]*)image: ${l_registryKey}/.*$" <<< "${l_result}")
  if [ "${l_result}" ];then
    stringToArray "${l_result}" "l_lines"
    l_lineCount=${#l_lines[@]}
    for ((l_i=0; l_i < l_lineCount; l_i++));do
      l_line="${l_lines[${l_i}]}"
      l_line="${l_line#*/}"
      l_images="${l_images},${l_line}"
    done
    gDefaultRetVal="${l_images:1}"
  fi

}

function _install_tonistiigi_binfmt_in_k8s() {
  export gImageCacheDir
  export gBuildScriptRootDir
  export gDefaultRetVal

  local l_targetArchType=$1
  local l_k8sDockerRepo=$2

  local l_result
  local l_templateFile
  local l_content
  local l_fromLocalRepo="false"

  l_result=$(kubectl get pods --all-namespaces | grep binfmt)
  if [ "${l_result}" ];then
    warn "common.deploy.extend.point.image.already.installed" "tonistiigi/binfmt:latest"
    return
  fi

  info "common.deploy.extend.point.checking.qemu.image.exists" "${l_targetArchType}#tonistiigi/binfmt:latest" "-n"
  l_result=$(docker image inspect tonistiigi/binfmt:latest --format '{{.Os}}/{{.Architecture}}' 2>&1)
  if [ "${l_result}" == "${l_targetArchType}" ];then
    info "common.deploy.extend.point.image.already.exists" "" "*"
  else
    l_result=$(docker rmi tonistiigi/binfmt:latest 2>&1)
    warn "common.deploy.extend.point.image.not.exists" "" "*"
  fi

  #先看本地是否存在缓存镜像
  if [ -f "${gImageCacheDir}/tonistiigi_binfmt-latest-${l_targetArchType//\//-}.tar" ];then
    info "common.deploy.extend.point.load.qemu.image.from.local.cache" "${gImageCacheDir}#${l_targetArchType}#tonistiigi_binfmt:latest" "-n"
    l_result=$(docker load -i "${gImageCacheDir}/tonistiigi_binfmt-latest-${l_targetArchType//\//-}.tar" 2>&1)
    if [ "$?" -eq 0 ];then
      info "common.deploy.extend.point.command.execute.success" "" "*"
    else
      rm -f "${gImageCacheDir}/tonistiigi_binfmt-latest-${l_targetArchType//\//-}.tar"
      warn "common.deploy.extend.point.command.execute.failed" "${l_result}" "*"
    fi
  fi

  l_result=$(docker image list | grep "tonistiigi/binfmt")
  if [ ! "${l_result}" ];then
    #尝试从本地镜像仓库中拉取目标镜像
    if [ "${gDockerRepoName}" ];then
     info "common.deploy.extend.point.pull.qemu.image.from.local.repo" "${gDockerRepoName}#${l_targetArchType}#tonistiigi/binfmt:latest" "-n"
     l_result=$(docker pull --platform "${l_targetArchType}" "${gDockerRepoName}/tonistiigi/binfmt:latest" 2>&1)
     if [ "$?" -eq 0 ];then
       warn "common.deploy.extend.point.command.execute.success" "" "*"
       # 为了后续的使用，这里需要将镜像tag为tonistiigi/binfmt:latest
       docker tag "${gDockerRepoName}/tonistiigi/binfmt:latest" "tonistiigi/binfmt:latest"
       l_fromLocalRepo="true"
     else
       warn "common.deploy.extend.point.command.execute.failed" "${l_result}" "*"
     fi
    fi
  fi

  l_result=$(docker image list | grep "tonistiigi/binfmt")
  if [ ! "${l_result}" ];then
    info "common.deploy.extend.point.pull.qemu.image.from.official.repo" "${l_targetArchType}#tonistiigi/binfmt:latest" "-n"
    l_result=$(docker pull --platform "${l_targetArchType}" "tonistiigi/binfmt:latest" 2>&1)
    if [ "$?" -ne 0 ];then
      error "common.deploy.extend.point.command.execute.failed" "${l_result}" "*"
    else
      info "common.deploy.extend.point.command.execute.success" "" "*"
    fi
  fi

  if [[ "${l_fromLocalRepo}" == "false" && "${gDockerRepoName}" ]];then
    info "common.deploy.extend.point.pushing.qemu.image.to.local.repo" "${l_targetArchType}#tonistiigi/binfmt:latest#${gDockerRepoName}"
    pushImage "tonistiigi/binfmt:latest" "${l_targetArchType}" "${gDockerRepoName}"
    if [ "${gDefaultRetVal}" == "true" ];then
      info "common.deploy.extend.point.pushing.qemu.image.success" "tonistiigi/binfmt:latest"
    fi
  fi

  if [[ "${l_k8sDockerRepo}" && "${gDockerRepoName}" != "${l_k8sDockerRepo}" ]];then
    info "common.deploy.extend.point.pushing.qemu.image.to.k8s.docker.repo" "${l_targetArchType}#tonistiigi/binfmt:latest#${l_k8sDockerRepo}"
    pushImage "tonistiigi/binfmt:latest" "${l_targetArchType}" "${l_k8sDockerRepo}"
    if [ "${gDefaultRetVal}" == "true" ];then
      info "common.deploy.extend.point.pushing.qemu.image.success" "tonistiigi/binfmt:latest"
    fi
  fi

  info "common.deploy.extend.point.save.qemu.image.to.local.cache" "${l_targetArchType}#tonistiigi/binfmt:latest#${gImageCacheDir}"
  saveImage "tonistiigi/binfmt:latest" "${l_targetArchType}" "${gImageCacheDir}"
  if [ "${gDefaultRetVal}" == "true" ];then
    info "common.deploy.extend.point.save.qemu.image.success" "tonistiigi/binfmt:latest"
  fi

  #使用kubectl apply -f 部署到k8s集群
  info "common.deploy.extend.point.apply.qemu.image.to.k8s.cluster" "${l_targetArchType}#tonistiigi/binfmt:latest" "-n"
  l_templateFile="${gBuildScriptRootDir}/templates/k8s/tonistiigi_binfmt-daemonset-install.yaml"
  #读取模板文件内容。
  l_content=$(cat "${l_templateFile}")
  #替换模板中的变量后安装资源。
  l_result=$(echo -e "${l_content}" | kubectl apply -f -)
  if [ "$?" -ne 0 ];then
    error "common.deploy.extend.point.command.execute.failed" "${l_result}" "*"
  else
    info "common.deploy.extend.point.command.execute.success" "" "*"
  fi

}

function _install_tonistiigi_binfmt() {
  export gImageCacheDir

  local l_localArchType=$1

  docker image inspect tonistiigi/binfmt:latest >/dev/null 2>&1
  # shellcheck disable=SC2181
  if [ "$?" -eq 0 ];then
    info "common.deploy.extend.point.install.qemu.image.success" "tonistiigi/binfmt:latest"
    return
  fi

  if [ "${gDockerRepoName}" ];then
   docker run --rm --privileged "${gDockerRepoName}/tonistiigi/binfmt:latest" --install all
   if [ "$?" -eq 0 ];then
     warn "common.deploy.extend.point.install.qemu.image.from.local.repo.success" "${gDockerRepoName}/tonistiigi/binfmt:latest"
     return
   fi
  fi

  if [ -f "${gImageCacheDir}/tonistiigi_binfmt-latest-${l_localArchType//\//-}.tar" ];then
    docker load -i "${gImageCacheDir}/tonistiigi_binfmt-latest-${l_localArchType//\//-}.tar"
    if [ "$?" -eq 0 ];then
      warn "common.deploy.extend.point.load.qemu.image.from.local.cache.success" "tonistiigi_binfmt:latest"
    fi
  fi

  docker run --rm --privileged tonistiigi/binfmt:latest --install all
  if [ "$?" -ne 0 ];then
    error "common.deploy.extend.point.install.qemu.image.failed" "tonistiigi/binfmt:latest"
  fi
  info "common.deploy.extend.point.install.qemu.image.success" "tonistiigi/binfmt:latest"

  if [ "${gDockerRepoName}" ];then
    info "common.deploy.extend.point.pushing.qemu.image" "tonistiigi/binfmt:latest#${gDockerRepoName}"
    pushImage "tonistiigi/binfmt:latest" "linux/${l_localArchType##*/}" "${gDockerRepoName}"
  fi

  if [ ! -f "${gImageCacheDir}/tonistiigi_binfmt-latest-${l_localArchType//\//-}.tar" ];then
    info "common.deploy.extend.point.saving.qemu.image" "tonistiigi/binfmt:latest#${gImageCacheDir}"
    saveImage "tonistiigi/binfmt:latest" "linux/${l_localArchType##*/}" "${gImageCacheDir}"
  fi
}

#**********************私有方法-结束***************************#

#参数部署值Map
declare -A gParamDeployedValueMap
export gParamDeployedValueMap
export gUninstallMode


#加载build阶段脚本库文件
loadExtendScriptFileForLanguage "deploy"

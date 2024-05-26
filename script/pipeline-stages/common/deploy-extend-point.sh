#!/usr/bin/env bash

function initialGlobalParamsForDeployStage_ex() {
  export gDefaultRetVal

}

function onBeforeDeployingServicePackage_ex() {
  export gCiCdYamlFile

  local l_index=$1
  local l_packageName=$2

  #根据deployType的不同进行不同的环境检查和准备。
  local l_deployType

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].deployType"
  l_deployType="${gDefaultRetVal}"

  if [ "${l_deployType}" == "docker" ];then
    invokeExtendPointFunc "onBeforeDeployingServicePackageByDockerMode" "采用docker方式部署服务安装包前扩展" "${l_index}" "${l_packageName}"
  elif [ "${l_deployType}" == "k8s" ];then
    invokeExtendPointFunc "onBeforeDeployingServicePackageByK8sMode" "采用K8s方式部署服务安装包前扩展" "${l_index}" "${l_packageName}"
  fi

}

function deployServicePackage_ex() {
  export gDefaultRetVal
  export gCurrentStageResult

  local l_index=$1
  local l_packageName=$2

  gCurrentStageResult="INFO|${l_packageName}安装包部署成功"
}

function onBeforeDeployingServicePackageByDockerMode_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gHelmBuildOutDir
  export gDockerRepoName
  export gDockerRepoAccount
  export gDockerRepoPassword
  export gBuildPath
  export gTempFileDir

  local l_index=$1
  local l_packageName=$2

  local l_array
  local l_chartName
  local l_chartVersion
  local l_images
  local l_remoteBaseDir
  local l_localBaseDir

  local l_shellOrYamlFile
  local l_remoteInstallProxyShell

  local l_activeProfile
  declare -A l_archTypeMap
  local l_i
  local l_nodeItem

  local l_ip
  local l_port
  local l_account
  local l_content
  local l_archType

  local l_proxyNode
  local l_remoteDir
  local l_localDir
  local l_offlinePackage
  local l_configMapFiles
  local l_configFile

  local l_nodeIps

  #获取包名对应的chart镜像的名称和版本
  _getChartVersion "${l_packageName}"
  # shellcheck disable=SC2206
  l_array=(${gDefaultRetVal})
  l_chartName="${l_array[0]}"
  l_chartVersion="${l_array[1]}"
  l_images="${l_array[2]}"

  # shellcheck disable=SC2088
  l_remoteBaseDir="~/devops/deploy"
  l_localBaseDir="${gBuildPath}/deploy"

  l_remoteDir="${l_remoteBaseDir}/${l_chartName}-${l_chartVersion}"

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].docker.mode"
  if [ "${gDefaultRetVal}" == "docker" ];then
    #获取docker-run.sh文件，该脚本文件的功能时执行docker run命令拉起服务。
    invokeExtendChain "onGenerateDockerRunShellFile" "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
    l_shellOrYamlFile="${gDefaultRetVal}"
  else
    #获取docker-compose.yaml文件，该文件是docker-compose命令的配置文件。
    invokeExtendChain "onGenerateDockerComposeYamlFile" "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
    l_shellOrYamlFile="${gDefaultRetVal}"
  fi

  invokeExtendChain "onSelectRemoteInstallProxyShell" "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_images}" "${l_remoteDir}"
  l_remoteInstallProxyShell="${gDefaultRetVal}"

  readParam "${gCiCdYamlFile}" "deploy[${l_index}].activeProfile"
  l_activeProfile="${gDefaultRetVal}"

  #循环连接所有的服务节点，按架构类型进行分类。
  ((l_i = 0))
  while true; do
    readParam "${gCiCdYamlFile}" "deploy[${l_index}].docker.${l_activeProfile}.nodeIPs[${l_i}]"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      if [ "${l_i}" -eq 0 ];then
        error "${gCiCdYamlFile##*/}文件中deploy[${l_index}].docker.${l_activeProfile}.nodeIPs参数是空的"
      else
        break
      fi
    fi

    l_nodeItem="${gDefaultRetVal}"
    # shellcheck disable=SC2206
    l_array=(${l_nodeItem//|/ })
    l_ip="${l_array[0]}"
    l_port="${l_array[1]}"
    l_account="${l_array[2]}"

    info "检查服务器${l_ip}的硬件架构 ..."
    l_content=$(ssh -p "${l_port}" "${l_account}@${l_ip}" "uname -sm" )
    invokeExtendChain "onGetLocalSystemArchInfo" "${l_content}"
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
    l_nodeItem="${l_proxyNode%%,*}"
    # shellcheck disable=SC2206
    l_array=(${l_nodeItem//|/ })
    l_ip="${l_array[0]}"
    l_port="${l_array[1]}"
    l_account="${l_array[2]}"

    # shellcheck disable=SC2088
    l_localDir="${l_localBaseDir}/${l_chartName}-${l_chartVersion}"
    rm -rf "${l_localDir}" && mkdir -p "${l_localDir}/config"

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

    readParam "${gCiCdYamlFile}" "globalParams.configMapFiles"
    l_configMapFiles="${gDefaultRetVal//,/ }"
    # shellcheck disable=SC2068
    for l_configFile in ${l_configMapFiles[@]};do
      #取临时目录中的同名文件。
      l_configFile="${gTempFileDir}/${l_configFile##*/}"
      info "将${l_configFile##*/}脚本复制本地deploy/config目录下"
      cp "${l_configFile}" "${l_localDir}/config/${l_configFile##*/}"
    done

    info "将${l_shellOrYamlFile##*/}脚本复制到本地deploy目录中"
    scp "${l_shellOrYamlFile}" "${l_localDir}/${l_shellOrYamlFile##*/}"

    info "将${l_remoteInstallProxyShell##*/}脚本复制到本地deploy目录下"
    scp "${l_remoteInstallProxyShell}" "${l_localDir}/${l_remoteInstallProxyShell##*/}"

    info "在本地deploy目录下创建install.sh"
    l_nodeIps="${l_archTypeMap[${l_archType}]//,${l_proxyNode}/}"
    echo -e "#!/usr/bin/env bash\n source ${l_remoteDir}/${l_remoteInstallProxyShell##*/} \"${l_chartName}\" \"${l_chartVersion}\" \"${l_offlinePackage}\" \"${gDockerRepoName}\" \"${gDockerRepoAccount}\" \"${gDockerRepoPassword}\" \"${l_nodeIps}\"" > "${l_localDir}/install.sh"

    #info "在服务器(${l_ip})上创建${l_remoteDir}目录"
    ssh -p "${l_port}" "${l_account}@${l_ip}" "rm -rf ${l_remoteDir} && mkdir -p ${l_remoteDir}"

    info "将本地deploy目录中的文件和子目录复制到服务器${l_ip}上的${l_remoteDir}目录中"
    scp -P "${l_port}" -r "${l_localDir}/" "${l_account}@${l_ip}:${l_remoteDir%/*}/"

    info "远程执行服务器${l_ip}上的脚本：${l_remoteDir}/install.sh"
    # shellcheck disable=SC2088
    ssh -p "${l_port}" "${l_account}@${l_ip}" "bash ${l_remoteDir}/install.sh"

  done

  info "删除本地deploy目录"
  rm -rf "${l_localDir%/*}"

}

function onBeforeDeployingServicePackageByK8sMode_ex() {
  export gCiCdYamlFile

  local l_index=$1
  local l_packageName=$2

}

#**********************私有方法-开始***************************#

function _getChartVersion() {
  export gDefaultRetVal
  export gCiCdYamlFile

  local l_packageName=$1
  local l_i
  local l_chartName
  local l_chartVersion
  local l_images

  gDefaultRetVal=""
  #获取部署的服务的版本
  ((l_i = 0))
  while true; do
    readParam "${gCiCdYamlFile}" "package[${l_i}].name"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      if [ "${l_i}" -eq 0 ];then
        error "${gCiCdYamlFile##*/}文件中package[${l_i}].name参数是空的"
      else
        break
      fi
    fi
    if [ "${gDefaultRetVal}" == "${l_packageName}" ];then
      readParam "${gCiCdYamlFile}" "package[${l_i}].chartName"
      l_chartName="${gDefaultRetVal}"
      readParam "${gCiCdYamlFile}" "package[${l_i}].chartVersion"
      l_chartVersion="${gDefaultRetVal}"
      readParam "${gCiCdYamlFile}" "package[${l_i}].images"
      l_images="${gDefaultRetVal}"
      break
    fi
    ((l_i = l_i + 1))
  done

  gDefaultRetVal="${l_chartName} ${l_chartVersion} ${l_images}"

}


#**********************私有方法-结束***************************#

#加载build阶段脚本库文件
loadExtendScriptFileForLanguage "deploy"

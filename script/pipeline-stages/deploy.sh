#!/usr/bin/env bash

function executePackageStage() {
  export gDefaultRetVal
  export gPipelineScriptsDir
  export gCiCdYamlFile
  export gCurrentStage
  export gServiceName
  export gCurrentStageResult
  export gHelmBuildDir
  export gHelmBuildOutDir
  export gBuildPath
  export gBuildType
  export gDockerRepoName

  local l_i
  local l_packageName

  local l_array
  local l_chartName
  local l_chartVersion
  local l_images
  local l_remoteBaseDir
  local l_localBaseDir
  local l_deployType
  local l_uninstallMode
  local l_installMode
  local l_deployDockerRepo

  local l_deployTempDirName
  local l_deployTempDir
  local l_deleteTempDirAfterDeployed

  local l_shellOrYamlFile
  local l_remoteInstallProxyShell

  info "加载公共${gCurrentStage}阶段功能扩展文件：${gCurrentStage}-extend-point.sh"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForDeployStage" "执行${gCurrentStage}阶段全局参数初始化前扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForDeployStage" "执行${gCurrentStage}阶段全局参数初始化扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForDeployStage" "执行${gCurrentStage}阶段全局参数初始化后扩展..." "${gCiCdYamlFile}"

  ((l_i = 0))
  while true; do
    #读取需要发布的离线安装包名称
    readParam "${gCiCdYamlFile}" "deploy[${l_i}].packageName"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      if [ "${l_i}" -eq 0 ];then
        error "${gCiCdYamlFile##*/}文件中deploy[${l_i}].packageName参数是空的"
      else
        break
      fi
    fi
    l_packageName="${gDefaultRetVal}"

    #获取包名对应的chart镜像的名称和版本
    _getChartVersion "${l_packageName}"
    # shellcheck disable=SC2206
    l_array=(${gDefaultRetVal})
    l_chartName="${l_array[0]}"
    l_chartVersion="${l_array[1]}"
    l_images="${l_array[2]}"

    readParam "${gCiCdYamlFile}" "deploy[${l_i}].deployTempDirName"
    l_deployTempDirName="${gDefaultRetVal}"
    if [[ ! "${l_deployTempDirName}" || "${l_deployTempDirName}" == "null" ]];then
      #设置默认值
      l_deployTempDirName="deploy"
    fi
    l_deployTempDir="${gHelmBuildDir}/${l_deployTempDirName}"

    readParam "${gCiCdYamlFile}" "deploy[${l_i}].deleteTempDirAfterDeployed"
    l_deleteTempDirAfterDeployed="${gDefaultRetVal}"
    if [[ ! "${l_deleteTempDirAfterDeployed}" || "${l_deleteTempDirAfterDeployed}" == "null" ]];then
      #设置默认值
      l_deleteTempDirAfterDeployed="false"
    fi

    # shellcheck disable=SC2088
    l_remoteBaseDir="~/devops/${l_deployTempDirName}"
    l_remoteDir="${l_remoteBaseDir}/${l_chartName}-${l_chartVersion}"

    l_localBaseDir="${l_deployTempDir}"
    [[ -d "${l_localBaseDir}" ]] && rm -rf "${l_localBaseDir:?}"
    mkdir -p "${l_localBaseDir}"

    readParam "${gCiCdYamlFile}" "deploy[${l_i}].deployType"
    l_deployType="${gDefaultRetVal}"

    readParam "${gCiCdYamlFile}" "deploy[${l_i}].uninstall"
    if [ "${gDefaultRetVal}" != "null" ];then
      l_uninstallMode="${gDefaultRetVal}"
    else
      l_uninstallMode="false"
    fi

    readParam "${gCiCdYamlFile}" "deploy[${l_i}].installMode"
    l_installMode="${gDefaultRetVal}"
    if [[ ! "${l_installMode}" || "${l_installMode}" == "null" ]];then
      #设置默认值
      l_installMode="install"
    fi

    readParam "${gCiCdYamlFile}" "deploy[${l_i}].k8s.dockerRepo"
    l_deployDockerRepo="${gDefaultRetVal}"

    if [[ "${l_deployType}" == "k8s" && ! "${gDockerRepoName}" && ! "${l_deployDockerRepo}" ]];then
      error "未设置docker镜像仓库(-D参数)并且目标K8S集群也未配置docker镜像仓库(deploy[${l_i}].k8s.dockerRepo)的情况下，k8s部署方式无效"
    fi

    [[ "${l_deployType}" == "docker" && ${gBuildType} != "single" ]] && \
      error "使用${gBuildType}构建类型打包的服务不能使用${l_deployType}方式部署(该方式仅适用于single构建类型打包的服务)"

    #服务安装包部署前扩展
    invokeExtendPointFunc "onBeforeDeployingServicePackage" "服务安装包部署前扩展" "${l_i}" "${l_chartName}" "${l_chartVersion}" \
      "${l_deployType}" "${l_images}" "${l_remoteDir}" "${l_localBaseDir}"
    l_array=("${gDefaultRetVal}")
    l_shellOrYamlFile="${l_array[0]}"
    l_remoteInstallProxyShell="${l_array[1]}"
    #发布服务安装包
    invokeExtendPointFunc "deployServicePackage" "服务安装包部署扩展" "${l_i}" "${l_chartName}" "${l_chartVersion}" \
      "${l_deployType}" "${l_uninstallMode}" "${l_images}" "${l_remoteDir}" "${l_localBaseDir}" "${l_shellOrYamlFile}" "${l_remoteInstallProxyShell}"
    #服务安装包部署后扩展
    invokeExtendPointFunc "onAfterDeployingServicePackage" "服务安装包部署后扩展" "${l_i}" "${l_chartName}" "${l_chartVersion}" \
      "${l_images}" "${l_remoteDir}" "${l_localBaseDir}"
    #向外部管理平台发送通知
    invokeExtendPointFunc "sendNotify" "向外部接口发送${gServiceName}服务安装包部署结果通知" "${gCurrentStageResult}"

    if [ "${l_deleteTempDirAfterDeployed}" == "true" ];then
      info "删除部署时使用的临时目录：${l_localBaseDir}"
      rm -rf "${l_localBaseDir:?}"
    fi

    ((l_i = l_i + 1))
  done

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

executePackageStage
#!/usr/bin/env bash

function executeDeployStage() {
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
  local l_activeProfile
  local l_installMode
  local l_deployDockerRepo

  local l_deployTempDirName
  local l_deployTempDir
  local l_deleteTempDirAfterDeployed

  local l_shellOrYamlFile
  local l_remoteInstallProxyShell

  info "deploy.sh.loading.common.extend.file" "${gCurrentStage}#${gCurrentStage}"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForDeployStage" "deploy.sh.before.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForDeployStage" "deploy.sh.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForDeployStage" "deploy.sh.after.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"

  ((l_i = 0))
  while true; do
    #读取需要发布的离线安装包名称
    readParam "${gCiCdYamlFile}" "deploy[${l_i}].packageName"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      if [ "${l_i}" -eq 0 ];then
        error "deploy.sh.package.name.empty" "${gCiCdYamlFile##*/}#${l_i}"
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

    readParam "${gCiCdYamlFile}" "deploy[${l_i}].installMode"
    l_installMode="${gDefaultRetVal}"
    if [[ ! "${l_installMode}" || "${l_installMode}" == "null" ]];then
      #设置默认值
      l_installMode="install"
    fi

    readParam "${gCiCdYamlFile}" "deploy[${l_i}].activeProfile"
    l_activeProfile="${gDefaultRetVal}"

    readParam "${gCiCdYamlFile}" "deploy[${l_i}].k8s.${l_activeProfile}.dockerRepo"
    l_deployDockerRepo="${gDefaultRetVal}"

    if [[ "${l_deployType}" == "k8s" && ! "${gDockerRepoName}" && ! "${l_deployDockerRepo}" ]];then
      error "deploy.sh.k8s.repo.not.set" "${l_i}"
    fi

    [[ "${l_deployType}" == "docker" && ${gBuildType} != "single" ]] && \
      error "deploy.sh.invalid.build.type" "${gBuildType}#${l_deployType}"

    #服务安装包部署前扩展
    invokeExtendPointFunc "onBeforeDeployingServicePackage" "deploy.sh.before.deploying.service.package" "" "${l_i}" "${l_chartName}" "${l_chartVersion}" \
      "${l_deployType}" "${l_images}" "${l_remoteDir}" "${l_localBaseDir}"
    # shellcheck disable=SC2206
    l_array=(${gDefaultRetVal})
    l_shellOrYamlFile="${l_array[0]}"
    l_remoteInstallProxyShell="${l_array[1]}"

    #发布服务安装包
    invokeExtendPointFunc "deployServicePackage" "deploy.sh.deploy.service.package" "" "${l_i}" "${l_chartName}" "${l_chartVersion}" \
      "${l_deployType}" "${l_installMode}" "${l_images}" "${l_remoteDir}" "${l_localBaseDir}" "${l_shellOrYamlFile}" "${l_remoteInstallProxyShell}"
    #服务安装包部署后扩展
    invokeExtendPointFunc "onAfterDeployingServicePackage" "deploy.sh.after.deploying.service.package" "" "${l_i}" "${l_chartName}" "${l_chartVersion}" \
      "${l_images}" "${l_remoteDir}" "${l_localBaseDir}"
    #向外部管理平台发送通知
    invokeExtendPointFunc "sendNotify" "deploy.sh.send.notify" "${gServiceName}" "${gCurrentStageResult}"

    if [ "${l_deleteTempDirAfterDeployed}" == "true" ];then
      info "deploy.sh.delete.temp.dir" "${l_localBaseDir}"
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
        error "deploy.sh.package.name.empty.in.file" "${gCiCdYamlFile##*/}#${l_i}"
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

executeDeployStage
#!/usr/bin/env bash

function executeDockerStage() {
  export gPipelineScriptsDir
  export gBuildType
  export gCurrentStage
  export gCiCdYamlFile
  export gDebugMode
  export gBuildStages
  export gValidBuildStages
  export gDockerBuildDir

  info "docker.sh.loading.common.extend.file" "${gCurrentStage}#${gCurrentStage}"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForDockerStage" "docker.sh.before.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForDockerStage" "docker.sh.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForDockerStage" "docker.sh.after.init.global.params" "${gCurrentStage}" "${gCiCdYamlFile}"

  if [ "${gBuildType}" == "thirdParty" ];then
    #处理第三方镜像
    _processThirdPartyImage
  elif [ "${gBuildType}" == "customize" ];then
    #从自定义构建目录中创建docker镜像。
    _createDockerImageByCustomizeDir
  else
    #根据项目生成Docker镜像
    _createDockerImageByDockerfile
  fi

  if [ "${gDebugMode}" != "true" ];then
    #删除docker-build目录下的所有文件
    rm -rf "${gDockerBuildDir:?}"/*
  fi
}

#****************************私有方法-开始***********************************#

function _processThirdPartyImage(){
  export gDefaultRetVal
  export gBuildPath
  export gArchTypes
  export gCiCdYamlFile
  export gThirdParties
  export gCurrentStageResult
  export gDeleteImageAfterBuilding

  local l_itemCount
  local l_i
  local l_allArchTypes
  local l_archType
  local l_image
  local l_location
  local l_exportFile

  readParam "${gCiCdYamlFile}" "docker.thirdParties"
  if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
    error "docker.sh.thirdparties.empty"
  fi
  #l_itemCount=$(echo -e "${gDefaultRetVal}" | grep -oP "^(\- )" | wc -l)
  l_itemCount=$(grep -cE "^- " <<< "${gDefaultRetVal}")

  # shellcheck disable=SC2206
  l_allArchTypes=(${gArchTypes//,/ })
  # shellcheck disable=SC2068
  for l_archType in ${l_allArchTypes[@]};do
    for ((l_i=0; l_i < l_itemCount; l_i++));do
      readParam "${gCiCdYamlFile}" "docker.thirdParties[${l_i}].images"
      l_image="${gDefaultRetVal}"
      if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
        error "docker.sh.thirdparties.images.empty" "${l_i}"
      fi
      readParam "${gCiCdYamlFile}" "docker.thirdParties[${l_i}].location"
      l_location="${gDefaultRetVal}"

      if [ "${l_location}" ];then
        if [[ "${l_location}" =~ ^(\.\/) ]];then
          l_location="${gBuildPath}/${l_location:1}"
        fi
        if [ ! -d "${l_location}" ];then
          error "docker.sh.thirdparty.image.dir.not.exist" "${l_image}#${l_location}"
        fi
        l_exportFile="${l_image}-${l_archType}"
        l_exportFile="${l_exportFile//\//-}"
        l_exportFile="${l_exportFile//:/-}"
        if [ ! -f "${l_location}/${l_exportFile}" ];then
          error "docker.sh.thirdparty.image.file.not.exist" "${l_location}#${l_exportFile}"
        fi
      fi

      invokeExtendPointFunc "onBeforeCreatingThirdPartyImage" "docker.sh.before.creating.thirdparty.image" "" "${l_image}" "${l_archType}" "${l_exportFile}"
      invokeExtendPointFunc "createThirdPartyImage" "docker.sh.creating.thirdparty.image" "" "${l_image}" "${l_archType}" "${l_exportFile}"
      invokeExtendPointFunc "onAfterCreatingThirdPartyImage" "docker.sh.after.creating.thirdparty.image" "" "${l_image}" "${l_archType}" "${l_exportFile}"
      #调用外部接口发送通知消息
      invokeExtendPointFunc "sendNotify" "docker.sh.send.notify" "" "${gCurrentStageResult}"
    done
  done

  if [ "${gDeleteImageAfterBuilding}" == "true" ];then
    info "docker.sh.prune.system"
    docker image prune -f
  fi

}

function _createDockerImageByCustomizeDir(){
  export gDefaultRetVal
  export gBuildPath
  export gArchTypes
  export gCiCdYamlFile
  export gThirdParties
  export gCurrentStageResult
  export gDeleteImageAfterBuilding

  local l_itemCount
  local l_allArchTypes
  local l_archType
  local l_i
  local l_image
  local l_dockerFile

  readParam "${gCiCdYamlFile}" "docker.customizes"
  if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
    error "docker.sh.customizes.empty"
  fi
  #l_itemCount=$(echo -e "${gDefaultRetVal}" | grep -oP "^(\- )" | wc -l)
  l_itemCount=$(grep -cE "^- " <<< "${gDefaultRetVal}")

  for ((l_i=0; l_i < l_itemCount; l_i++));do
    readParam "${gCiCdYamlFile}" "docker.customizes[${l_i}].name"
    l_image="${gDefaultRetVal}"
    if [[ ! "${l_image}" || "${l_image}" == "null" ]];then
      error "docker.sh.customizes.name.empty" "${l_i}"
    fi

    #读取目标架构类型
    readParam "${gCiCdYamlFile}" "docker.customizes[${l_i}].archType"
    l_archType="${gDefaultRetVal}"
    if [[ ! "${l_archType}" || "${l_archType}" == "null" ]];then
      error "docker.sh.customizes.archtype.empty" "${l_i}"
    fi

    #读取目标Dockerfile文件。
    readParam "${gCiCdYamlFile}" "docker.customizes[${l_i}].dockerfile"
    l_dockerFile="${gDefaultRetVal}"
    if [[ ! "${l_dockerFile}" || "${l_dockerFile}" == "null" ]];then
      error "docker.sh.customizes.dockerfile.empty" "${l_i}"
    fi

    if [ "${l_dockerFile}" ];then
      if [[ "${l_dockerFile}" =~ ^(\.\/) ]];then
        l_dockerFile="${gBuildPath}/${l_dockerFile:1}"
      fi
      if [ ! -f "${l_dockerFile}" ];then
        error "docker.sh.customized.dockerfile.not.exist" "${l_dockerFile}"
      fi
    fi

    invokeExtendPointFunc "onBeforeCreatingCustomizedImage" "docker.sh.before.creating.customized.image" "" "${l_image}" "${l_archType}" "${l_dockerFile}"
    invokeExtendPointFunc "creatingCustomizedImage" "docker.sh.creating.customized.image" "" "${l_image}" "${l_archType}" "${l_dockerFile}"
    invokeExtendPointFunc "onAfterCreatingCustomizedImage" "docker.sh.after.creating.customized.image" "" "${l_image}" "${l_archType}" "${l_dockerFile}"
    #调用外部接口发送通知消息
    invokeExtendPointFunc "sendNotify" "docker.sh.send.notify" "" "${gCurrentStageResult}"
  done


  if [ "${gDeleteImageAfterBuilding}" == "true" ];then
    info "docker.sh.prune.system"
    docker image prune -f
  fi
}

#通过Dockerfile文件生成docker镜像
function _createDockerImageByDockerfile() {
  export gDefaultRetVal
  export gBuildType
  export gPipelineScriptsDir
  export gCiCdYamlFile
  export gArchTypes
  export gServiceName
  export gDockerRepoName
  export gCurrentStageResult
  export gImageCacheDir

  export gDockerfileTemplates
  export gDockerFileTemplateParamMap
  export gDeleteImageAfterBuilding

  local l_DockerfileTemplates
  local l_dockerFileTemplate
  local l_targetDockerFile

  local l_allArchTypes
  local l_archType
  local l_index
  local l_image

  # shellcheck disable=SC2206
  l_allArchTypes=(${gArchTypes//,/ })

  # shellcheck disable=SC2206
  l_DockerfileTemplates=(${gDockerfileTemplates})
  # shellcheck disable=SC2068
  for l_dockerFileTemplate in ${l_DockerfileTemplates[@]};do
    #设置DockerFile文件中_FROM-IMAGE_占位符的值。
    _setFromImage "${l_dockerFileTemplate}"
    # shellcheck disable=SC2068
    for l_archType in ${l_allArchTypes[@]};do
      #设置DockerFile文件中_FROM-IMAGE_占位符的值。
      gDockerFileTemplateParamMap["_PLATFORM_"]="${l_archType}"
      gDockerFileTemplateParamMap["_OS-TYPE_"]="${l_archType%%/*}"
      gDockerFileTemplateParamMap["_ARCH-TYPE_"]="${l_archType##*/}"
      gDockerFileTemplateParamMap["_ARCH_"]="${l_archType//\//-}"
      #根据模板文件生成目标Dockerfile文件，并完成初始化(除架构参数外)
      invokeExtendPointFunc "initialDockerFile" "docker.sh.generating.and.initializing.dockerfile" "${l_dockerFileTemplate##*/}" "${gCiCdYamlFile}" "${l_dockerFileTemplate}"

      l_targetDockerFile="${gDefaultRetVal}"
      #docker镜像构建前扩展：执行构建需要的文件拷贝等操作。
      invokeExtendPointFunc "onBeforeCreatingDockerImage" "docker.sh.before.creating.docker.image.extend" "" "${gCiCdYamlFile}" "${l_archType}" "${l_targetDockerFile}"
      invokeExtendPointFunc "createDockerImage" "docker.sh.creating.docker.image.extend" "" "${gCiCdYamlFile}" "${l_archType}" "${l_targetDockerFile}"
      l_image="${gDefaultRetVal}"
      invokeExtendPointFunc "onAfterCreatingDockerImage" "docker.sh.after.creating.docker.image.extend" "" "${l_image}" "${l_archType}"
      #调用外部接口发送通知消息
      invokeExtendPointFunc "sendNotify" "docker.sh.send.notify" "" "${gCurrentStageResult}"

      if [ "${gDeleteImageAfterBuilding}" == "true" ];then
        info "docker.sh.deleting.local.image" "${l_image}"
        docker rmi -f "${l_image}"

        ((l_index = 0))
        while true; do
          l_image="${gDockerFileTemplateParamMap[_FROM-IMAGE${l_index}_]}"
          if [ ! "${l_image}" ];then
            break
          fi
          info "docker.sh.deleting.base.image" "${l_image}"
          docker rmi "${l_image}"
          ((l_index = l_index + 1))
        done
      fi

    done
  done

  if [ "${gDeleteImageAfterBuilding}" == "true" ];then
    info "docker.sh.prune.system"
    docker image prune -f
  fi
}

function _setFromImage() {
  export gDockerRepoName
  export gDockerFileTemplateParamMap
  export gTargetDockerFromImage_business
  export gTargetDockerFromImage_base

  local l_dockerFileTemplate=$1
  local l_suffix
  local l_fromImage
  local l_array
  local l_arrayLen
  local l_i
  local l_index

  l_suffix="${l_dockerFileTemplate##*_}"
  if [[ "${l_suffix}" == 'business' ]];then
    l_fromImage="${gTargetDockerFromImage_business}"
  else
    l_fromImage="${gTargetDockerFromImage_base}"
  fi

  if [ "${l_fromImage}" ];then
    # shellcheck disable=SC2206
    l_array=(${l_fromImage//,/ })
    l_arrayLen=${#l_array[@]}
    ((l_index = 0))
    for ((l_i=0; l_i < l_arrayLen; l_i++));do
      if [ "${l_array[${l_i}]}" ];then
        gDockerFileTemplateParamMap["_FROM-IMAGE${l_index}_"]="${l_array[${l_i}]}"
        ((l_index = l_index + 1))
      fi
    done
  else
    #报错退出
    error "docker.sh.from.image.placeholder.not.found" "${l_dockerFileTemplate##*/}"
  fi
}

#****************************私有方法-结束***********************************#

#在此处定义docker阶段特有的后续会使用的全局变量
export gDockerfileTemplates
export gWorkDirInDocker
export gAppDirInDocker
export gExposePorts
export gTimeZone
export gJvmOpts
export gJavaOpts
export gProjectBuildOutDir

export gDockerFileTemplateParamMap
export gTargetDockerFromImage_base
export gTargetDockerName_base
export gTargetDockerVersion_base

export gTargetDockerFromImage_business
export gTargetDockerName_business
export gTargetDockerVersion_business

#执行Docker阶段的流程
executeDockerStage

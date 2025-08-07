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

  info "加载公共${gCurrentStage}阶段功能扩展文件：${gCurrentStage}-extend-point.sh"
  # shellcheck disable=SC1090
  source "${gPipelineScriptsDir}/common/${gCurrentStage}-extend-point.sh"

  invokeExtendPointFunc "onBeforeInitialingGlobalParamsForDockerStage" "执行${gCurrentStage}阶段全局参数初始化前扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "initialGlobalParamsForDockerStage" "执行${gCurrentStage}阶段全局参数初始化扩展..." "${gCiCdYamlFile}"
  invokeExtendPointFunc "onAfterInitialingGlobalParamsForDockerStage" "执行${gCurrentStage}阶段全局参数初始化后扩展..." "${gCiCdYamlFile}"

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
    error "docker.thirdParties参数为空"
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
        error "docker.thirdParties[${l_i}].images参数为空"
      fi
      readParam "${gCiCdYamlFile}" "docker.thirdParties[${l_i}].location"
      l_location="${gDefaultRetVal}"

      if [ "${l_location}" ];then
        if [[ "${l_location}" =~ ^(\.\/) ]];then
          l_location="${gBuildPath}/${l_location:1}"
        fi
        if [ ! -d "${l_location}" ];then
          error "第三方镜像${l_image}导出文件目录${l_location}不存在"
        fi
        l_exportFile="${l_image}-${l_archType}"
        l_exportFile="${l_exportFile//\//-}"
        l_exportFile="${l_exportFile//:/-}"
        if [ ! -f "${l_location}/${l_exportFile}" ];then
          error "${l_location}目录中不存在第三方镜像的导出文件${l_exportFile}文件"
        fi
      fi

      invokeExtendPointFunc "onBeforeCreatingThirdPartyImage" "处理第三方Docker镜像前扩展" "${l_image}" "${l_archType}" "${l_exportFile}"
      invokeExtendPointFunc "createThirdPartyImage" "处理第三方Docker镜像" "${l_image}" "${l_archType}" "${l_exportFile}"
      invokeExtendPointFunc "onAfterCreatingThirdPartyImage" "处理第三方Docker镜像后扩展" "${l_image}" "${l_archType}" "${l_exportFile}"
      #调用外部接口发送通知消息
      invokeExtendPointFunc "sendNotify" "调用通知接口发送Docker镜像构建结果..." "${gCurrentStageResult}"
    done
  done

  if [ "${gDeleteImageAfterBuilding}" == "true" ];then
    info "清除无用的镜像：docker system prune -f"
    docker system prune -f
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
    error "docker.customizes参数为空"
  fi
  #l_itemCount=$(echo -e "${gDefaultRetVal}" | grep -oP "^(\- )" | wc -l)
  l_itemCount=$(grep -cE "^- " <<< "${gDefaultRetVal}")

  for ((l_i=0; l_i < l_itemCount; l_i++));do
    readParam "${gCiCdYamlFile}" "docker.customizes[${l_i}].name"
    l_image="${gDefaultRetVal}"
    if [[ ! "${l_image}" || "${l_image}" == "null" ]];then
      error "docker.customizes[${l_i}].name参数为空"
    fi

    #读取目标架构类型
    readParam "${gCiCdYamlFile}" "docker.customizes[${l_i}].archType"
    l_archType="${gDefaultRetVal}"
    if [[ ! "${l_archType}" || "${l_archType}" == "null" ]];then
      error "docker.customizes[${l_i}].archType参数为空"
    fi

    #读取目标Dockerfile文件。
    readParam "${gCiCdYamlFile}" "docker.customizes[${l_i}].dockerfile"
    l_dockerFile="${gDefaultRetVal}"
    if [[ ! "${l_dockerFile}" || "${l_dockerFile}" == "null" ]];then
      error "docker.customizes[${l_i}].dockerfile参数为空"
    fi

    if [ "${l_dockerFile}" ];then
      if [[ "${l_dockerFile}" =~ ^(\.\/) ]];then
        l_dockerFile="${gBuildPath}/${l_dockerFile:1}"
      fi
      if [ ! -f "${l_dockerFile}" ];then
        error "自定义dockerfile文件不存在:${l_dockerFile}"
      fi
    fi

    invokeExtendPointFunc "onBeforeCreatingCustomizedImage" "从自定义构建目录中创建Docker镜像前扩展" "${l_image}" "${l_archType}" "${l_dockerFile}"
    invokeExtendPointFunc "creatingCustomizedImage" "从自定义构建目录中创建Docker镜像" "${l_image}" "${l_archType}" "${l_dockerFile}"
    invokeExtendPointFunc "onAfterCreatingCustomizedImage" "从自定义构建目录中创建Docker镜像后扩展" "${l_image}" "${l_archType}" "${l_dockerFile}"
    #调用外部接口发送通知消息
    invokeExtendPointFunc "sendNotify" "调用通知接口发送Docker镜像构建结果..." "${gCurrentStageResult}"
  done


  if [ "${gDeleteImageAfterBuilding}" == "true" ];then
    info "清除无用的镜像：docker system prune -f"
    docker system prune -f
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
  local l_localArchType
  local l_archType
  local l_index
  local l_image

  # shellcheck disable=SC2206
  l_allArchTypes=(${gArchTypes//,/ })

  #info "安装QEMU用户模式模拟"
  #apt-get install qemu-user-static

  #检查当前操作系统架构类型
#  invokeExtendChain "onGetSystemArchInfo"
#  l_localArchType=${gDefaultRetVal}
#
#  if [[ "${#l_allArchTypes[@]}" -gt 1 || "${l_localArchType##*/}" != "${l_allArchTypes[0]##*/}"  ]];then
#    info "检查本地是否存在tonistiigi/binfmt:latest镜像"
#    docker image inspect tonistiigi/binfmt:latest >/dev/null 2>&1
#    # shellcheck disable=SC2181
#    if [ "$?" -ne 0 ];then
#       if [ "${gDockerRepoName}" ];then
#         docker run --rm --privileged "${gDockerRepoName}/tonistiigi/binfmt:latest" --install all
#       fi
#
#       docker image inspect "${gDockerRepoName}/tonistiigi/binfmt:latest" >/dev/null 2>&1
#       if [ "$?" -ne 0 ];then
#         docker run --rm --privileged tonistiigi/binfmt:latest --install all
#         docker image inspect tonistiigi/binfmt:latest >/dev/null 2>&1
#         if [ "$?" -eq 0 ];then
#           info "成功注册qemu解释器（Docker跨架构构建需要）"
#           if [ "${gDockerRepoName}" ];then
#             info "将tonistiigi/binfmt:latest镜像推送到镜像仓库中：${gImageCacheDir}"
#             pushImage "tonistiigi/binfmt:latest" "linux/${l_localArchType##*/}" "${gDockerRepoName}"
#           fi
#           info "将tonistiigi/binfmt:latest镜像缓存到本地镜像缓存目录中：${gImageCacheDir}"
#           saveImage "tonistiigi/binfmt:latest" "linux/${l_localArchType##*/}" "${gImageCacheDir}"
#         fi
#       else
#         info "成功注册qemu解释器（Docker跨架构构建需要）"
#       fi
#    else
#      docker run --rm --privileged tonistiigi/binfmt:latest --install all
#      info "成功注册qemu解释器（Docker跨架构构建需要）"
#    fi
#  fi

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
      invokeExtendPointFunc "initialDockerFile" "生成并初始化${l_dockerFileTemplate##*/}文件" "${gCiCdYamlFile}" "${l_dockerFileTemplate}"

      l_targetDockerFile="${gDefaultRetVal}"
      #docker镜像构建前扩展：执行构建需要的文件拷贝等操作。
      invokeExtendPointFunc "onBeforeCreatingDockerImage" "docker镜像构建前扩展" "${gCiCdYamlFile}" "${l_archType}" "${l_targetDockerFile}"
      invokeExtendPointFunc "createDockerImage" "构建docker镜像扩展" "${gCiCdYamlFile}" "${l_archType}" "${l_targetDockerFile}"
      l_image="${gDefaultRetVal}"
      invokeExtendPointFunc "onAfterCreatingDockerImage" "docker镜像构建后扩展" "${l_image}" "${l_archType}"
      #调用外部接口发送通知消息
      invokeExtendPointFunc "sendNotify" "调用通知接口发送Docker镜像构建结果..." "${gCurrentStageResult}"

      if [ "${gDeleteImageAfterBuilding}" == "true" ];then
        info "删除生成的本地镜像：${l_image}"
        docker rmi -f "${l_image}"

        ((l_index = 0))
        while true; do
          l_image="${gDockerFileTemplateParamMap[_FROM-IMAGE${l_index}_]}"
          if [ ! "${l_image}" ];then
            break
          fi
          info "删除使用的基础镜像：${l_image}"
          docker rmi "${l_image}"
          ((l_index = l_index + 1))
        done
      fi

    done
  done

  if [ "${gDeleteImageAfterBuilding}" == "true" ];then
    info "清除无用的镜像：docker system prune -f"
    docker system prune -f
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
    error "没有找到${l_dockerFileTemplate##*/}文件中的_FROM-IMAGE0_占位符的实际值"
  fi
}

#****************************私有方法-结束***********************************#

#在此处定义docker阶段特有的后续会使用的全局变量
export gDockerfileTemplates
export gWorkDirInDocker
export gAppDirInDocker
export gExposePorts
export gTimeZone
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

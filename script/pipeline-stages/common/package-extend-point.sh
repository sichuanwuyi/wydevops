#!/usr/bin/env bash
 
function initialGlobalParamsForPackageStage_ex() {
  export gBuildType
  export gCiCdYamlFile
  export gDockerRepoName
  export gDockerRepoAccount
  export gDockerRepoPassword
  export gChartRepoInstanceName
  export gChartRepoName
  export gChartRepoAccount
  export gChartRepoPassword
  export gChartRepoType

  local l_suffix

  if [[ "${gBuildType}" == "single" || "${gBuildType}" == "thirdParty" ]];then
    #制作单镜像时，对ci-cd.yaml文件进行特殊处理。
    invokeExtendPointFunc "handleBuildingSingleImageForPackage" "package阶段single构建模式下对ci-cd.yaml文件中参数的特殊调整" "${gCiCdYamlFile}"
  fi

  if [[ "${gBuildType}" == "base" || "${gBuildType}" == "business" ]];then
    #制作单镜像时，对ci-cd.yaml文件进行特殊处理。
    invokeExtendPointFunc "handleBuildingOneImageForPackage" "package阶段${gBuildType}构建模式下对ci-cd.yaml文件中参数的特殊调整" "${gCiCdYamlFile}"
  fi

  if [[ "${gChartRepoInstanceName}" ]];then
    #nexus仓库需要先登录，harbor仓库的登录会在addHelmRepo函数中完成。
    [[ "${gChartRepoType}" == "nexus" ]] && dockerLogin "${gDockerRepoName}" "${gDockerRepoAccount}" "${gDockerRepoPassword}"
    #添加Chart镜像仓库到本地配置中。
    addHelmRepo "${gChartRepoType}" "${gChartRepoInstanceName}" "${gChartRepoName}" "${gChartRepoAccount}" "${gChartRepoPassword}"
  fi
}

function createOfflinePackage_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gHelmBuildOutDir
  export gCurrentStageResult

  local l_index=$1
  local l_chartName=$2

  local l_chartVersion
  local l_targetDir
  local l_archTypes
  local l_archType

  #读取对应的chart版本
  readParam "${gCiCdYamlFile}" "package[${l_index}].chartVersion"
  if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
    error "${gCiCdYamlFile##*/}文件中的package[${l_index}].chartVersion参数不能为空"
  fi
  l_chartVersion="${gDefaultRetVal}"

  #得到离线包打包路径。
  l_targetDir="${gHelmBuildOutDir}/${l_chartName//\//_}-${l_chartVersion}"

  invokeExtendPointFunc "copyChartImage" "获取${l_chartName}离线安装包中Chart镜像扩展" "${l_index}" "${l_chartName}" "${l_chartVersion}" "${l_targetDir}/chart"
  invokeExtendPointFunc "createConfigFile" "创建${l_chartName}离线安装包中的配置文件扩展" "${l_chartName}" "${l_chartVersion}" "${l_targetDir}"

  #读取离线打包的架构类型。
  readParam "${gCiCdYamlFile}" "package[${l_index}].archTypes"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    # shellcheck disable=SC2206
    l_archTypes=(${gDefaultRetVal//,/ })
  else
    #默认需要打包两种。
    l_archTypes=("linux/arm64" "linux/amd64")
  fi

  #循环打包出不同架构类型的离线安装包。
  # shellcheck disable=SC2068
  for l_archType in ${l_archTypes[@]};do
    #读取需要打包的镜像名称列表。
    readParam "${gCiCdYamlFile}" "package[${l_index}].images"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      break
    fi
    invokeExtendPointFunc "copyDockerImage" "获取${l_chartName}离线安装包中${l_archType}架构的Docker镜像扩展" "${l_index}" "${l_archType}" "${l_targetDir}/docker"
    invokeExtendPointFunc "zipOfflinePackage" "创建${l_archType}架构的${l_chartName}离线安装包压缩文件扩展" "${l_chartName}" "${l_chartVersion}" "${l_targetDir}" "${l_archType}"
  done

  gCurrentStageResult="INFO|${l_chartName}项目离线安装包打包成功"

}

function copyChartImage_ex() {
  export gChartRepoInstanceName

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_targetDir=$4

  if [ ! -f "${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz" ];then
    info "从Chart镜像仓库中拉取目标镜像：${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz ..."
    helm pull "${gChartRepoInstanceName}/${l_chartName}" --destination "${l_targetDir}" --version "${l_chartVersion}"
  fi

  if [ -f "${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz" ];then
    #通过chart镜像收集所有需要的docker镜像，并与package[l_index].images参数合并。
    _scanAllDockerImages "${l_index}" "${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz"
    #过滤出有效的docker镜像信息
    _filterValidDockerImages "${gDefaultRetVal}"
    #更新需要打包到安装包中的docker镜像参数。
    updateParam "${gCiCdYamlFile}" "package[${l_index}].images" "${gDefaultRetVal}"
  else
    warn "未找到目标chart镜像：${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz"
  fi

}

function createConfigFile_ex() {
  export gDefaultRetVal
  export gDockerRepoName
  export gCiCdYamlFile

  local l_chartName=$1
  local l_chartVersion=$2
  local l_targetDir=$3

  local l_gatewayHost
  local l_valuesYaml
  local l_settingFile
  local l_curDir
  local l_keys
  local l_key


  #仅当存在${l_chartName}-${l_chartVersion}.tgz文件时才生成setting.conf文件。
  if [ -f "${l_targetDir}/chart/${l_chartName}-${l_chartVersion}.tgz" ];then

    readParam "${gCiCdYamlFile}" "globalParams.gatewayHost"
    [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]] && l_gatewayHost="${gDefaultRetVal}"

    l_valuesYaml="${l_chartName}/values.yaml"

    #创建setting.conf文件。
    l_settingFile="${l_targetDir}/setting.conf"
    echo "image.registry=${gDockerRepoName}," > "${l_settingFile}"
    echo "gatewayRoute.host=${l_gatewayHost}," >> "${l_settingFile}"

    l_curDir=$(pwd)

    #解压chart镜像压缩文件。
    # shellcheck disable=SC2164
    cd "${l_targetDir}/chart"
    tar -zxf "${l_chartName}-${l_chartVersion}.tgz"

    declare -A paramMaps
    getAllParamPathAndValue "${l_valuesYaml}" "params" "paramMaps"

    # shellcheck disable=SC2124
    l_keys=${!paramMaps[@]}
    # shellcheck disable=SC2068
    for l_key in ${l_keys[@]};do
      echo "${l_key}=${paramMaps[${l_key}]}," >> "${l_settingFile}"
    done

    #删除解压出的目录
    rm -rf "./${l_chartName}/"

    # shellcheck disable=SC2164
    cd "${l_curDir}"

  fi

}

function copyDockerImage_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gHelmBuildOutDir
  export gImageCacheDir

  local l_index=$1
  local l_archType=$2
  local l_targetDir=$3

  local l_images
  local l_image
  local l_tmpImage
  local l_exportedFile
  local l_savedFile

  #读取需要打包的镜像名称列表。
  readParam "${gCiCdYamlFile}" "package[${l_i}].images"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    #清除l_targetDir目录中现有文件。
    rm -rf "${l_targetDir:?}/" && mkdir -p "${l_targetDir}"

    #循环获取镜像的导出文件。
    # shellcheck disable=SC2206
    l_images=(${gDefaultRetVal//,/ })
    # shellcheck disable=SC2068
    for l_image in ${l_images[@]};do

      l_tmpImage="${l_image//\//_}"
      l_savedFile="${gHelmBuildOutDir}/${l_archType//\//-}/${l_tmpImage//:/-}-${l_archType//\//-}.tar"
      if [ ! -f "${l_savedFile}" ];then
        l_exportedFile="${gImageCacheDir}/${l_tmpImage//:/-}-${l_archType//\//-}.tar"
        if [ ! -f  "${l_exportedFile}" ];then
          info "拉取${l_image}镜像，并导出到目录${l_savedFile%/*}中"
          pullImage "${l_image}" "${l_archType}" "${gDockerRepoName}" "${gImageCacheDir}" "${l_savedFile%/*}"
          info "删除拉取得镜像"
          docker rmi -f "${l_image}"
        else
          l_savedFile="${l_exportedFile}"
        fi
      fi

      if [ -f "${l_savedFile}" ];then
        info "成功获取离线安装包中Docker镜像导出文件：${l_tmpImage//:/-}-${l_archType//\//-}.tar"
        cp -f "${l_savedFile}" "${l_targetDir}/"
      else
        error "获取离线安装包中Docker镜像导出文件失败：${l_tmpImage//:/-}-${l_archType//\//-}.tar"
      fi

    done
  fi

}

function zipOfflinePackage_ex() {
  export gDefaultRetVal
  export gHelmBuildOutDir

  local l_chartName=$1
  local l_chartVersion=$2
  local l_targetDir=$3
  local l_archType=$4

  local l_zipFile
  local l_curDir

  # shellcheck disable=SC2154
  l_curDir=${pwd}
  # shellcheck disable=SC2164
  cd "${l_targetDir}"

  l_zipFile="${l_chartName//\//_}-${l_chartVersion}-${l_archType//\//-}.tar.gz"
  info "将${l_targetDir##*/}目录压缩为${l_zipFile}"
  tar -zcf "../${l_zipFile}" "."

  # shellcheck disable=SC2164
  cd "${l_curDir}"

}

function handleBuildingSingleImageForPackage_ex() {
  export gDefaultRetVal
  export gBuildType
  export gDockerRepoType
  export gDockerRepoInstanceName
  export gDockerImageNameWithInstance

  local l_ciCdYamlFile=$1

  local l_serviceName
  local l_businessVersion
  local l_i
  local l_j
  local l_images
  local l_arrayLen
  local l_flag
  local l_paramValue

  #读取服务名称
  readParam "${l_ciCdYamlFile}" "globalParams.serviceName"
  l_serviceName="${gDefaultRetVal}"

  #读取服务的版本
  readParam "${l_ciCdYamlFile}" "globalParams.businessVersion"
  l_businessVersion="${gDefaultRetVal}"

  ((l_i = 0))
  while true; do
    readParam "${l_ciCdYamlFile}" "package[${l_i}].images"
    if [ "${gDefaultRetVal}" == "null" ];then
      break
    fi

    #将gDefaultRetVal值转换成数组。
    stringToArray "${gDefaultRetVal}" "l_images" $','
    #获取数组的长度
    l_arrayLen="${#l_images[@]}"

    l_paramValue=""
    for (( l_j=0; l_j < l_arrayLen; l_j++ )) do
      #如果是单镜像打包模式，则需要移除可能存在的业务镜像和基础镜像。
      if [ "${gBuildType}" == "single" ];then
        l_flag=$(echo -e "${l_images[${l_j}]}" | grep -oP "^(.*)${l_serviceName//-/\-}(\-base|\-business):" )
        if [ "${l_flag}" ];then
          debug "从package[${l_i}].images参数值中移除${l_images[${l_j}]}镜像"
          #是基础镜像，则直接跳过。
          continue
        fi
      fi

      #去重后追加到l_paramValue参数后面，英文逗号隔开。
      l_flag=$(echo "${l_paramValue}" | grep -ioP "^(.*)${l_images[${l_j}]//-/\-}(.*)$" )
      if [ ! "${l_flag}" ];then
        l_paramValue="${l_paramValue},${l_images[${l_j}]}"
      fi
    done

    if [[ "${gDockerRepoType}" == "harbor" || ("${gDockerRepoInstanceName}" && "${gDockerImageNameWithInstance}" == "true") ]];then
      l_serviceName="${gDockerRepoInstanceName}/${l_serviceName}"
    fi

    debug "添加单镜像名:${l_serviceName}:${l_businessVersion}"
    if [ "${l_paramValue}" ];then
      l_flag=$(echo "${l_paramValue}" | grep -oP "^(.*)${l_serviceName}:${l_businessVersion}")
      [[ ! "${l_flag}" ]] && l_paramValue="${l_serviceName}:${l_businessVersion},${l_paramValue:1}"
    else
      l_paramValue="${l_serviceName}:${l_businessVersion}"
    fi

    debug "更新globalParams.packageImages参数的值为：${l_paramValue}"
    updateParam "${l_ciCdYamlFile}" "globalParams.packageImages" "${l_paramValue}"

    debug "更新package[${l_i}].images参数的值为：${l_paramValue}"
    updateParam "${l_ciCdYamlFile}" "package[${l_i}].images" "${l_paramValue}"

    ((l_i = l_i + 1))
  done

}

function handleBuildingOneImageForPackage_ex() {
  export gDefaultRetVal
  export gBuildType

  local l_ciCdYamlFile=$1

  local l_serviceName
  local l_businessVersion
  local l_suffix

  local l_i
  local l_j
  local l_images
  local l_arrayLen
  local l_flag
  local l_paramValue

  #读取服务名称
  readParam "${l_ciCdYamlFile}" "globalParams.serviceName"
  l_serviceName="${gDefaultRetVal}"

  #读取服务的版本
  readParam "${l_ciCdYamlFile}" "globalParams.businessVersion"
  l_businessVersion="${gDefaultRetVal}"

  l_suffix="base"
  [[ "${gBuildType}" == "base" ]] && l_suffix="business"

  ((l_i = 0))
  while true; do
    readParam "${l_ciCdYamlFile}" "package[${l_i}].images"
    if [ "${gDefaultRetVal}" == "null" ];then
      break
    fi

    #将gDefaultRetVal值转换成数组。
    stringToArray "${gDefaultRetVal}" "l_images" $','
    #获取数组的长度
    l_arrayLen="${#l_images[@]}"

    l_paramValue=""
    for (( l_j=0; l_j < l_arrayLen; l_j++ )) do
      #如果是单镜像打包模式，则需要移除可能存在的业务镜像和基础镜像。
      l_flag=$(echo -e "${l_images[${l_j}]}" | grep -oP "^(.*)${l_serviceName//-/\-}\-${l_suffix}:" )
      if [ "${l_flag}" ];then
        debug "从package[${l_i}].images参数值中移除${l_images[${l_j}]}镜像"
        #直接跳过。
        continue
      fi

      #去重后追加到l_paramValue参数后面，英文逗号隔开。
      l_flag=$(echo "${l_paramValue}" | grep -ioP "^(.*)${l_images[${l_j}]//-/\-}(.*)$" )
      if [ ! "${l_flag}" ];then
        l_paramValue="${l_paramValue},${l_images[${l_j}]}"
      fi
    done

    debug "更新globalParams.packageImages参数的值为：${l_paramValue:1}"
    updateParam "${l_ciCdYamlFile}" "globalParams.packageImages" "${l_paramValue:1}"

    debug "更新package[${l_i}].images参数的值为：${l_paramValue:1}"
    updateParam "${l_ciCdYamlFile}" "package[${l_i}].images" "${l_paramValue:1}"

    ((l_i = l_i + 1))
  done

}

function handleBuildingBusinessImageForPackage_ex() {
  export gDefaultRetVal
  export gBuildType

  local l_ciCdYamlFile=$1

  local l_serviceName
  local l_businessVersion

  local l_i
  local l_j
  local l_images
  local l_arrayLen
  local l_flag
  local l_paramValue

  #读取服务名称
  readParam "${l_ciCdYamlFile}" "globalParams.serviceName"
  l_serviceName="${gDefaultRetVal}"

  #读取服务的版本
  readParam "${l_ciCdYamlFile}" "globalParams.businessVersion"
  l_businessVersion="${gDefaultRetVal}"

  ((l_i = 0))
  while true; do
    readParam "${l_ciCdYamlFile}" "package[${l_i}].images"
    if [ "${gDefaultRetVal}" == "null" ];then
      break
    fi

    #将gDefaultRetVal值转换成数组。
    stringToArray "${gDefaultRetVal}" "l_images" $','
    #获取数组的长度
    l_arrayLen="${#l_images[@]}"

    l_paramValue=""
    for (( l_j=0; l_j < l_arrayLen; l_j++ )) do
      #如果是单镜像打包模式，则需要移除可能存在的业务镜像和基础镜像。
      if [ "${gBuildType}" == "business" ];then
        l_flag=$(echo -e "${l_images[${l_j}]}" | grep -oP "^(.*)${l_serviceName//-/\-}\-base:" )
        if [ "${l_flag}" ];then
          debug "从package[${l_i}].images参数值中移除${l_images[${l_j}]}镜像"
          #是基础镜像，则直接跳过。
          continue
        fi
      fi
      #去重后追加到l_paramValue参数后面，英文逗号隔开。
      l_flag=$(echo "${l_paramValue}" | grep -ioP "^(.*)${l_images[${l_j}]//-/\-}(.*)$" )
      if [ ! "${l_flag}" ];then
        l_paramValue="${l_paramValue},${l_images[${l_j}]}"
      fi
    done

    debug "更新globalParams.packageImages参数的值为：${l_paramValue:1}"
    updateParam "${l_ciCdYamlFile}" "globalParams.packageImages" "${l_paramValue:1}"

    debug "更新package[${l_i}].images参数的值为：${l_paramValue:1}"
    updateParam "${l_ciCdYamlFile}" "package[${l_i}].images" "${l_paramValue:1}"

    ((l_i = l_i + 1))
  done

}

#**********************私有方法-开始***************************#

#收集某个Chart镜像需要的所有docker镜像。
function _scanAllDockerImages() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gTempFileDir
  export gBuildType

  local l_index=$1
  local l_chartImage=$2

  local l_tmpFile
  local l_content
  local l_splitLines
  local l_splitLine

  local l_startRow
  local l_endRow
  local l_subContent
  local l_flag
  local l_subTempFile

  local l_i
  local l_imageArray
  local l_images
  local l_image
  local l_tmpImage

  # shellcheck disable=SC2088
  l_tmpFile="${gTempFileDir}/helm-template-${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"

  l_content=$(helm template test "${l_chartImage}" -n test.com --set image.registry=)
  echo "${l_content}" > "${l_tmpFile}"

  l_imageArray=","
  l_splitLines=$(echo "${l_content}" | grep -noP "\-\-\-")
  # shellcheck disable=SC2068
  for l_splitLine in ${l_splitLines[@]};do
    if [ ! "${l_startRow}" ];then
      l_startRow="${l_splitLine%%:*}"
    elif [ ! "${l_endRow}" ];then
      l_endRow="${l_splitLine%%:*}"
    else
      l_subContent=$(awk "NR==${l_startRow}, NR==${l_endRow}" "${l_tmpFile}")
      l_startRow=""
      l_endRow=""
      l_flag=$(echo "${l_subContent}" | grep -ioP "^(.*)kind: (DaemonSet|StatefulSet|Deployment)(.*)$")
      if [ "${l_flag}" ];then
        # shellcheck disable=SC2088
        l_subTempFile="${gTempFileDir}/service-${RANDOM}.tmp"
        registerTempFile "${l_subTempFile}"
        echo "${l_subContent}" > "${l_subTempFile}"

        ((l_i = 0))
        while true; do
          readParam "${l_subTempFile}" "spec.template.spec.initContainers[${l_i}].image"
          if [ "${gDefaultRetVal}" == "null" ];then
            break
          fi
          #将读取的docker镜像名称保存到l_imageArray数组中。
          l_image="${gDefaultRetVal//\//\\\/}"
          l_image="${l_image//-/\\-}"
          if [[ ! "${l_imageArray}" =~ ^(.*),${l_image},(.*)$ ]];then
            l_imageArray="${l_imageArray}${gDefaultRetVal},"
          fi
          ((l_i = l_i + 1))
        done

        ((l_i = 0))
        while true; do
          readParam "${l_subTempFile}" "spec.template.spec.containers[${l_i}].image"
          if [ "${gDefaultRetVal}" == "null" ];then
            break
          fi
          #将读取的docker镜像名称保存到l_imageArray数组中。
          l_image="${gDefaultRetVal//\//\\\/}"
          l_image="${l_image//-/\\-}"
          if [[ ! "${l_imageArray}" =~ ^(.*),${l_image},(.*)$ ]];then
            l_imageArray="${l_imageArray}${gDefaultRetVal},"
          fi
          ((l_i = l_i + 1))
        done
        #删除临时文件
        unregisterTempFile "${l_subTempFile}"
      fi
    fi
  done
  #删除临时文件
  unregisterTempFile "${l_tmpFile}"

  readParam "${gCiCdYamlFile}" "package[${l_index}].images"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    #合并数据。
    # shellcheck disable=SC2206
    l_images=(${gDefaultRetVal//,/ })
    # shellcheck disable=SC2068
    for l_tmpImage in ${l_images[@]};do
      l_image="${l_tmpImage//\//\\\/}"
      l_image="${l_image//-/\\-}"
      if [[ ! "${l_imageArray}" =~ ^(.*),${l_image},(.*)$ ]];then
        l_imageArray="${l_imageArray}${l_tmpImage},"
      fi
    done
  fi

  l_imageArray="${l_imageArray%,*}"
  gDefaultRetVal="${l_imageArray:1}"
}

function _filterValidDockerImages() {
  export gDefaultRetVal
  export gCiCdYamlFile

  local l_imageArray=$1

  local l_images
  local l_dockerName
  local l_dockerVersion

  local l_singleImage
  local l_baseImage
  local l_businessImage

  l_imageArray=",${l_imageArray},"

  readParam "${gCiCdYamlFile}" "docker.base.name"
  l_dockerName="${gDefaultRetVal}"
  readParam "${gCiCdYamlFile}" "docker.base.version"
  l_dockerVersion="${gDefaultRetVal}"
  l_baseImage="${l_dockerName}:${l_dockerVersion}"

  readParam "${gCiCdYamlFile}" "docker.business.name"
  l_dockerName="${gDefaultRetVal}"
  readParam "${gCiCdYamlFile}" "docker.business.version"
  l_dockerVersion="${gDefaultRetVal}"
  l_businessImage="${l_dockerName}:${l_dockerVersion}"

  l_singleImage="${l_businessImage%-*}:${l_businessImage##*:}"

  #存储不需要镜像名称
  l_images=()
  if [ "${gBuildType}" == "single" ];then
    l_images[0]="${l_singleImage%:*}-business:${l_singleImage##*:}"
    l_images[1]="${l_singleImage%:*}-base:${l_singleImage##*:}"
    #检查必须要的镜像是否存在。
    if [[ ! "${l_imageArray}" =~ ^(.*),${l_singleImage},(.*)$ ]];then
      error "chart镜像中未使用docker镜像:${l_singleImage},请检查并修正配置文件。"
    fi
  elif [ "${gBuildType}" == "double" ];then
    l_images[0]="${l_singleImage}"
    #检查必须要的镜像是否存在。
    if [[ ! "${l_imageArray}" =~ ^(.*),${l_baseImage},(.*)$ ]];then
      error "chart镜像中未使用docker镜像:${l_baseImage},请检查并修正配置文件。"
    fi
    if [[ ! "${l_imageArray}" =~ ^(.*),${l_businessImage},(.*)$ ]];then
      error "chart镜像中未使用docker镜像:${l_businessImage},请检查并修正配置文件。"
    fi
  elif [ "${gBuildType}" == "base" ];then
    l_images[0]="${l_singleImage}"
    l_images[1]="${l_singleImage%-*}-business:${l_singleImage##*:}"
    #检查必须要的镜像是否存在。
    if [[ ! "${l_imageArray}" =~ ^(.*),${l_baseImage},(.*)$ ]];then
      error "chart镜像中未使用docker镜像:${l_baseImage},请检查并修正配置文件。"
    fi
  elif [ "${gBuildType}" == "business" ];then
    l_images[0]="${l_singleImage}"
    l_images[1]="${l_singleImage%-*}-base:${l_singleImage##*:}"
    #检查必须要的镜像是否存在。
    if [[ ! "${l_imageArray}" =~ ^(.*),${l_businessImage},(.*)$ ]];then
      error "chart镜像中未使用docker镜像:${l_businessImage},请检查并修正配置文件。"
    fi
  fi

  #删除不需要的镜像。
  # shellcheck disable=SC2068
  for l_image in ${l_images[@]};do
    if [[ "${l_imageArray}" =~ ^(.*),${l_image},(.*)$ ]];then
      warn "从打包的docker镜像列表中移除了不需要的镜像：${l_image}"
      l_imageArray="${l_imageArray//,${l_image},/,}"
    fi
  done

  l_imageArray="${l_imageArray%,*}"
  gDefaultRetVal="${l_imageArray:1}"
}
#**********************私有方法-结束***************************#

#加载package阶段脚本库文件
loadExtendScriptFileForLanguage "package"
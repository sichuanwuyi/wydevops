#!/usr/bin/env bash
 
function initialGlobalParamsForPackageStage_ex() {
  export gBuildType
  export gCiCdYamlFile
  export gDockerRepoName
  export gDockerRepoAccount
  export gDockerRepoPassword
  export gChartRepoAliasName
  export gChartRepoName
  export gChartRepoAccount
  export gChartRepoPassword

  if [ "${gBuildType}" == "single" ];then
    #制作单镜像时，对ci-cd.yaml文件进行特殊处理。
    invokeExtendPointFunc "handleBuildingSingleImageForPackage" "package阶段单镜像构建模式下对ci-cd.yaml文件中参数的特殊调整" "${gCiCdYamlFile}"
  fi

  if [[ "${gDockerRepoName}" && "${gDockerRepoAccount}" && "${gDockerRepoPassword}" ]];then
    #完成docker仓库登录
    dockerLogin "${gDockerRepoName}" "${gDockerRepoAccount}" "${gDockerRepoPassword}"
  else
    warn "docker仓库登录失败：docker仓库地址、登录账号、登录密码均不能为空"
  fi

  if [[ "${gChartRepoName}" && "${gChartRepoAccount}" && "${gChartRepoPassword}" ]];then
    #添加Chart镜像仓库到本地配置中。
    addHelmRepo "${gChartRepoAliasName}" "${gChartRepoName}" "${gChartRepoAccount}" "${gChartRepoPassword}"
  else
    warn "在本地Helm配置中添加Chart镜像仓库信息失败：chart仓库别名、chart仓库地址、登录账号、登录密码均不能为空"
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
  export gChartRepoAliasName

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_targetDir=$4

  if [ ! -f "${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz" ];then
    info "从Chart镜像仓库中拉取目标镜像：${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz ..."
    helm pull "${gChartRepoAliasName}/${l_chartName}" --destination "${l_targetDir}" --version "${l_chartVersion}"
  fi

  if [ -f "${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz" ];then
    #通过chart镜像收集所有需要的docker镜像，并与package[l_index].images参数合并。
    _scanAllDockerImages "${l_index}" "${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz"
    #过滤出有效的docker镜像信息
    filterValidDockerImages "${gDefaultRetVal}"
    #更新需要打包到安装包中的docker镜像参数。
    updateParam "${gCiCdYamlFile}" "package[${l_index}].images" "${gDefaultRetVal}"
  else
    warn "未找到目标chart镜像：${l_targetDir}/${l_chartName}-${l_chartVersion}.tgz"
  fi

}

function createConfigFile_ex() {
  export gDefaultRetVal
  export gDockerRepoName

  local l_chartName=$1
  local l_chartVersion=$2
  local l_targetDir=$3

  local l_valuesYaml
  local l_settingFile
  local l_curDir
  local l_index
  local l_content

  local l_paramLines
  local l_lineCount
  local l_i
  local l_paramName
  local l_paramPath

  #仅当存在${l_chartName}-${l_chartVersion}.tgz文件时才生成setting.conf文件。
  if [ -f "${l_targetDir}/chart/${l_chartName}-${l_chartVersion}.tgz" ];then

    l_valuesYaml="${l_chartName}/values.yaml"

    #创建setting.conf文件。
    l_settingFile="${l_targetDir}/setting.conf"
    echo "image.registry=${gDockerRepoName},\\" > "${l_settingFile}"

    l_curDir=$(pwd)

    #解压chart镜像压缩文件。
    # shellcheck disable=SC2164
    cd "${l_targetDir}/chart"
    tar -zxf "${l_chartName}-${l_chartVersion}.tgz"

    ((l_index = 0))
    while true;do
      readParam "${l_chartName}/values.yaml" "params.deployment${l_index}"
      if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
        break
      fi

      #过滤出有效行
      l_content=$(echo "${gDefaultRetVal}" | grep -oP "^[a-zA-Z]+(.*)$")
      stringToArray "${l_content}" "l_paramLines"
      l_lineCount="${#l_paramLines[@]}"

      # shellcheck disable=SC2068
      for ((l_i = 0; l_i < l_lineCount; l_i++));do
        l_paramName="${l_paramLines[${l_i}]}"
        l_paramName="${l_paramName%%:*}"
        l_paramName="${l_paramName// /}"
        l_paramPath="params.deployment${l_index}.${l_paramName}"
        info "正在向setting.conf文件写入${l_paramPath}参数 ..."
        _writeSettingConfFile "${l_valuesYaml}" "${l_paramPath}" "${l_settingFile}"
      done

      ((l_index = l_index + 1))
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
      l_exportedFile="${gHelmBuildOutDir}/${l_archType//\//-}/${l_tmpImage//:/-}-${l_archType//\//-}.tar"
      if [ ! -f "${l_exportedFile}" ];then
        l_exportedFile="${gImageCacheDir}/${l_tmpImage//:/-}-${l_archType//\//-}.tar"
        if [ ! -f  "${l_exportedFile}" ];then
          #拉取镜像，并导出到本地镜像缓存目录gImageCacheDir中。
          pullImage "${l_image}" "${l_archType}" "${gDockerRepoName}" "${gImageCacheDir}"
          #删除拉取得镜像。
          docker rmi -f "${l_image}"
        fi
      fi

      if [ -f "${l_exportedFile}" ];then
        info "成功获取离线安装包中Docker镜像导出文件：${l_tmpImage//:/-}-${l_archType//\//-}.tar"
        cp -f "${l_exportedFile}" "${l_targetDir}/"
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
  export gCiCdYamlFile
  export gBuildType

  local l_serviceName
  local l_businessVersion
  local l_i
  local l_j
  local l_images
  local l_arrayLen
  local l_flag
  local l_paramValue

  #读取服务名称
  readParam "${gCiCdYamlFile}" "globalParams.serviceCode"
  l_serviceName="${gDefaultRetVal}"

  #读取服务的版本
  readParam "${gCiCdYamlFile}" "globalParams.businessVersion"
  l_businessVersion="${gDefaultRetVal}"

  ((l_i = 0))
  while true; do
    readParam "${gCiCdYamlFile}" "package[${l_i}].images"
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
        l_flag=$(echo "${l_images[${l_j}]}" | grep -ioP "^([ ]*)${l_serviceName//-/\-}(\-base|\-business)*:" )
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

    debug "添加单镜像名:${l_serviceName}:${l_businessVersion}"
    if [ "${l_paramValue}" ];then
      l_paramValue="${l_serviceName}:${l_businessVersion},${l_paramValue:1}"
    else
      l_paramValue="${l_serviceName}:${l_businessVersion}"
    fi

    debug "更新globalParams.packageImages参数的值为：${l_paramValue}"
    updateParam "${gCiCdYamlFile}" "globalParams.packageImages" "${l_paramValue}"

    debug "更新package[${l_i}].images参数的值为：${l_paramValue}"
    updateParam "${gCiCdYamlFile}" "package[${l_i}].images" "${l_paramValue}"

    ((l_i = l_i + 1))
  done

}

#**********************私有方法-开始***************************#

function _writeSettingConfFile() {
  export gDefaultRetVal

  local l_valuesYaml=$1
  local l_paramPath=$2
  local l_settingFile=$3

  local l_content
  local l_dataLines
  local l_lineCount
  local l_paramName
  local l_i

  readParam "${l_valuesYaml}" "${l_paramPath}"
  if [ ! "${gDefaultRetVal}" ];then
    info "设置参数${l_paramPath}的值为："
    echo "${l_paramPath}=,\\" >> "${l_settingFile}"
  elif [ "${gDefaultRetVal}" != "null" ];then
    if [[ "${gDefaultRetVal}" =~ ^(\-) ]];then
      #处理列表项
      l_lineCount=$(echo -e "${gDefaultRetVal}" | grep -oP "^(\-)" | wc -l)
      for ((l_i = 0; l_i < l_lineCount; l_i++));do
        info "正在向setting.conf文件写入${l_paramPath}[${l_i}]参数..."
        _writeSettingConfFile "${l_valuesYaml}" "${l_paramPath}[${l_i}]" "${l_settingFile}"
      done
    elif [[ "${gDefaultRetVal}" =~ ^([ ]*)\[.*\]([ ]*)$ ]];then
      #处理数组项
      l_content="${gDefaultRetVal//[/}"
      l_content="${l_content//]/}"
      # shellcheck disable=SC2206
      l_dataLines=(${l_content//,/ })
      l_lineCount="${#l_dataLines[@]}"
      for ((l_i = 0; l_i < l_lineCount; l_i++));do
        info "正在向setting.conf文件写入${l_paramPath}[${l_i}]参数..."
        _writeSettingConfFile "${l_valuesYaml}" "${l_paramPath}[${l_i}]" "${l_settingFile}"
      done
    else
      #将字符串转换为多行数组
      stringToArray "${gDefaultRetVal}" "l_dataLines"
      l_lineCount="${#l_dataLines[@]}"

      if [[ "${l_lineCount}" -eq 1 ]];then
        #如果该行是以冒号结尾，则继续递归
        if [[ "${l_dataLines[0]}" =~ ^(.*):([ ]*)$ ]];then
          l_paramName="${l_dataLines[0]%%:*}"
          info "正在向setting.conf文件写入${l_paramPath}.${l_paramName}参数..."
          _writeSettingConfFile "${l_valuesYaml}" "${l_paramPath}.${l_paramName}" "${l_settingFile}"
        else
          info "设置参数${l_paramPath}的值为：${l_dataLines[0]}"
          echo "${l_paramPath}=${l_dataLines[0]},\\" >> "${l_settingFile}"
        fi
      else
        for ((l_i = 0; l_i < l_lineCount; l_i++));do
          l_paramName="${l_dataLines[${l_i}]}"
          l_paramName="${l_paramName%%:*}"
          if [[ ! "${l_paramName}" =~ ^([ ]+) ]];then
            info "正在向setting.conf文件写入${l_paramPath}.${l_paramName}参数..."
            _writeSettingConfFile "${l_valuesYaml}" "${l_paramPath}.${l_paramName}" "${l_settingFile}"
          fi
        done
      fi

    fi
  fi
}

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

  unset l_index
  unset l_chartImage

  unset l_tmpFile
  unset l_content
  unset l_splitLines
  unset l_splitLine

  unset l_startRow
  unset l_endRow
  unset l_subContent
  unset l_flag
  unset l_subTempFile

  unset l_i
  unset l_imageArray
  unset l_images
  unset l_image
  unset l_tmpImage
}

function filterValidDockerImages() {
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

  unset l_imageArray

  unset l_images
  unset l_dockerName
  unset l_dockerVersion

  unset l_baseImage
  unset l_businessImage
}
#**********************私有方法-结束***************************#

#加载package阶段脚本库文件
loadExtendScriptFileForLanguage "package"
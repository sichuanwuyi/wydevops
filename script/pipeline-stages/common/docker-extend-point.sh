#!/usr/bin/env bash

function createThirdPartyImage_ex(){
  export gDockerRepoName
  export gImageCacheDir
  export gCurrentStageResult

  local l_image=$1
  local l_archType=$2
  local l_exportFile=$3

  gDefaultRetVal=""
  #如果没有提供第三方镜像的导出文件，则拉取该镜像。
  if [ ! "${l_exportFile}" ];then
    #打包第三方镜像：拉取第三方镜像，缓存到本地镜像缓存目录中，
    #然后推送到私库中，最后导出到gDockerBuildOutDir目录中。
    pullImage "${l_image}" "${l_archType}" "${gDockerRepoName}" "${gImageCacheDir}"
    gCurrentStageResult="INFO|成功拉取${l_archType}架构的${l_image}镜像"
    gDefaultRetVal="${l_image}"
  fi

  unset l_image
  unset l_archType
  unset l_exportFile
}

function onAfterCreatingThirdPartyImage_ex() {
  export gDefaultRetVal
  export gBuildPath

  #l_image参数前面没有仓库前缀。
  local l_image=$1
  local l_archType=$2
  local l_exportFile=$3

  if [ "${l_exportFile}" ];then
    info "直接将第三方镜像导出文件复制到${gHelmBuildOutDir}/${l_archType//\//-}目录中"
    cp -f "${l_exportFile}" "${gHelmBuildOutDir}/${l_archType//\//-}"
  else
    info "将第三方镜像导出到${gHelmBuildOutDir}/${l_archType//\//-}目录的文件中"
    saveImage "${l_image}" "${l_archType}" "${gHelmBuildOutDir}/${l_archType//\//-}"
    if [ "${gDeleteImageAfterBuilding}" == "true" ];then
      info "删除本地第三方镜像：${l_image}"
      docker rmi "${l_image}"
    fi
  fi

  gDefaultRetVal="成功处理${l_archType}架构的第三方镜像：${l_image}"

  unset l_image
  unset l_archType
  unset l_exportFile
}

function onBeforeCreatingCustomizedImage_ex() {
  export gDockerRepoName
  export gImageCacheDir
  export gDockerFileTemplateParamMap

  local l_image=$1
  local l_archType=$2
  local l_dockerFile=$3

  local l_content
  local l_lines
  local l_lineCount
  local l_i
  local l_fromLine
  local l_params
  local l_fromImage

  #检查l_dockerFile文件中是否设定了--platform=${l_archType}
  # shellcheck disable=SC2002
  l_content=$(cat "${l_dockerFile}" | grep -ioP "^([ ]*)FROM([ ]+).*$")
  if [ ! "${l_content}" ];then
    error "自定义的${l_dockerFile}文件中未找到From语句"
  fi

  stringToArray "${l_content}" "l_lines"
  # shellcheck disable=SC2154
  l_lineCount=${#l_lines[@]}

  # shellcheck disable=SC2068
  for ((l_i = 0; l_i < l_lineCount; l_i++ ));do
    l_fromLine="${l_lines[${l_i}]}"
    l_fromLine=$(echo "${l_fromLine}" | grep -inoP "^.*(--platform=${l_archType//\//\\\/}).*$" )
    if [[ ! "${l_fromLine}" ]];then
      error "自定义的${l_dockerFile}文件中From语句中未定义\"--platform\"参数或该参数的值不为${l_archType}"
    fi
    #拉取from语句中定义的基础镜像
    # shellcheck disable=SC2206
    l_params=(${l_fromLine})
    l_fromImage="${l_params[2]}"
    pullImage "${l_fromImage}" "${l_archType}" "${gDockerRepoName}" "${gImageCacheDir}"
    gDockerFileTemplateParamMap["_FROM-IMAGE${l_i}_"]="${l_fromImage}"
  done

  unset l_image
  unset l_archType
  unset l_dockerFile

  unset l_content
  unset l_lines
  unset l_lineCount
  unset l_i
  unset l_fromLine
  unset l_params
  unset l_fromImage
}

function creatingCustomizedImage_ex() {
  local l_image=$1
  local l_archType=$2
  local l_dockerFile=$3

  _createDockerImage "${l_image}" "${l_archType}" "${l_dockerFile}"

  unset l_image
  unset l_archType
  unset l_dockerFile
}

function onAfterCreatingCustomizedImage_ex(){
  #l_image参数前面没有仓库前缀。
  local l_image=$1
  local l_archType=$2

  _onAfterCreatingDockerImage "${l_image}" "${l_archType}"

  unset l_image
  unset l_archType
}

function onBeforeInitialingGlobalParamsForDockerStage_ex(){
  export gBuildType
  export gCiCdYamlFile

  if [ "${gBuildType}" == "single" ];then
    #制作单镜像时，对ci-cd.yaml文件进行特殊处理。
    invokeExtendPointFunc "handleBuildingSingleImageForDocker" "docker阶段单镜像构建模式下对ci-cd.yaml文件中参数的特殊调整" "${gCiCdYamlFile}"
  fi
}

function initialGlobalParamsForDockerStage_ex(){
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gArchTypes
  export gBuildType
  export gUseTemplate
  export gBuildPath
  export gLanguage

  #docker阶段特有的全局变量
  export gDockerfileTemplates
  export gWorkDirInDocker
  export gAppDirInDocker
  export gExposePorts
  export gTimeZone
  export gProjectBuildOutDir
  export gThirdParties
  export gSaveBackImmediately

  local l_cicdYaml=$1
  local l_dockerFiles
  local l_dockerFile

  local l_typeNames
  local l_typeName
  local l_params
  local l_param

  #先清除内存中缓存的旧的文件内容,确保以下读取操作读到的都是最新内容
  clearCachedFileContent "${l_cicdYaml}"

  if [ ! "${gBuildType}" ];then
    readParam "${l_cicdYaml}" "docker.buildType"
    gBuildType="${gDefaultRetVal}"
  fi
  info "读取参数docker.buildType的值:${gBuildType}"

  if [ ! "${gArchTypes}" ];then
    readParam "${l_cicdYaml}" "docker.archTypes"
    gArchTypes="${gDefaultRetVal}"
  fi
  info "读取参数docker.archTypes的值:${gArchTypes}"

  if [ "${gBuildType}" != "thirdParty" ];then
    #是否强制使用Docker模板文件。
    readParam "${l_cicdYaml}" "docker.useTemplate"
    gUseTemplate="${gDefaultRetVal}"
    info "读取参数docker.useTemplate的值:${gUseTemplate}"

    #应用基础容器中应用工作路径，
    readParam "${l_cicdYaml}" "docker.workDir"
    gWorkDirInDocker="${gDefaultRetVal}"
    info "读取参数docker.workDir的值:${gWorkDirInDocker}"

    #应用业务镜像中应用文件的存储路径，注意要与挂载的ConfigMap目录保持一致。
    readParam "${l_cicdYaml}" "docker.appDir"
    gAppDirInDocker="${gDefaultRetVal}"
    info "读取参数docker.appDir的值:${gAppDirInDocker}"

    #应用业务镜像中应用文件的存储路径，注意要与挂载的ConfigMap目录保持一致。
    readParam "${l_cicdYaml}" "docker.exposePorts"
    gExposePorts="${gDefaultRetVal//,/ }"
    info "读取参数docker.exposePorts的值:${gExposePorts}"

    #docker容器内的时区配置
    readParam "${l_cicdYaml}" "docker.timeZone"
    gTimeZone="${gDefaultRetVal}"
    info "读取参数docker.timeZone的值:${gTimeZone}"
    # shellcheck disable=SC2028
    l_typeNames=("business" "base")
    l_params=("name" "version" "fromImage")
    # shellcheck disable=SC2068
    for l_typeName in ${l_typeNames[@]};do
      for l_param in ${l_params[@]};do
        readParam "${l_cicdYaml}" "docker.${l_typeName}.${l_param}"
        eval "export gTargetDocker${l_param^}_${l_typeName}=\"${gDefaultRetVal}\""
        eval "info \"读取参数docker.${l_typeName}.${l_param}的值(gTargetDocker${l_param^}_${l_typeName}):\${gTargetDocker${l_param^}_${l_typeName}}\""
      done
    done

    # single：单镜像模式，构建“应用镜像”
    # double：双镜像模式，同时构建应用基础镜像和应用业务镜像
    # base：仅构建“应用基础镜像”
    # business：仅构建“应用业务镜像”
    # all：同时构建应用镜像、应用基础镜像和应用业务镜像
    case ${gBuildType} in
      single)
        l_dockerFiles="Dockerfile"
        ;;
      double)
        l_dockerFiles="Dockerfile_base Dockerfile_business"
        ;;
      base)
        l_dockerFiles="Dockerfile_base"
        ;;
      business)
        l_dockerFiles="Dockerfile_business"
        ;;
      thirdParty)
        l_dockerFiles=""
        ;;
      customize)
        l_dockerFiles=""
        ;;
      *)
        error "不存在的构建类型参数：${gBuildType}"
        ;;
    esac

    if [[ "${gBuildType}" != "thirdParty" && "${gBuildType}" != "customize" ]];then
      gDockerfileTemplates=""
      # shellcheck disable=SC2206
      l_dockerFiles=(${l_dockerFiles})
      # shellcheck disable=SC2068
      for l_dockerFile in ${l_dockerFiles[@]};do
        if [ -f "${gBuildPath}/${l_dockerFile}" ];then
          gDockerfileTemplates="${gDockerfileTemplates} ${gBuildPath}/${l_dockerFile}"
        elif [ -f "${gBuildScriptRootDir}/templates/docker/${gLanguage}/${l_dockerFile}" ];then
          gDockerfileTemplates="${gDockerfileTemplates} ${gBuildScriptRootDir}/templates/docker/${gLanguage}/${l_dockerFile}"
        elif [ -f "${gBuildScriptRootDir}/templates/docker/${l_dockerFile}" ];then
          gDockerfileTemplates="${gDockerfileTemplates} ${gBuildScriptRootDir}/templates/docker/${l_dockerFile}"
        else
          error "指定的模板文件不存在:${l_dockerFile}"
        fi
      done

      #定义项目默认的编译输出目录，各语言项目可在语言级扩展中重新定义各个变量。
      gProjectBuildOutDir="${gBuildPath}/out"

      if [ "${gDockerBuildDir}" ];then
        info "清空${gDockerBuildDir##*/}目录"
        rm -rf "${gDockerBuildDir:?}/*" || true
      fi

      gDockerfileTemplates="${gDockerfileTemplates:1}"

    fi

  fi

}

function onAfterInitialingGlobalParamsForDockerStage_ex() {
  export gDockerRepoName
  export gDockerRepoAccount
  export gDockerRepoPassword
  export gDockerA
  export gDockerBuildDir
  export gExposePorts
  export gTimeZone
  export gWorkDirInDocker
  export gAppDirInDocker

  local l_ciCdYamlFile=$1

  #定义Dockerfile文件中占位符的具体值。
  gDockerFileTemplateParamMap["_EXPOSE_"]="${gExposePorts}"
  gDockerFileTemplateParamMap["_TZ_"]="${gTimeZone}"
  gDockerFileTemplateParamMap["_WORK-DIR-IN-CONTAINER_"]="${gWorkDirInDocker}"
  gDockerFileTemplateParamMap["_APP-DIR-IN-CONTAINER_"]="${gAppDirInDocker}"
  #以下参数必须知道当前Dockerfile文件名称后才能确定。
  gDockerFileTemplateParamMap["_FROM-IMAGE0_"]=""
  #以下参数必须知道当前处理的架构类型后才能确定。
  gDockerFileTemplateParamMap["_PLATFORM_"]=""
  gDockerFileTemplateParamMap["_ARCH_"]=""

  info "处理docker.copyFiles参数"
  _copyFilesIntoDockerBuildDir "${l_ciCdYamlFile}"

  if [[ "${gDockerRepoName}" && "${gDockerRepoAccount}" && "${gDockerRepoPassword}" ]];then
    #完成docker仓库登录
    dockerLogin "${gDockerRepoName}" "${gDockerRepoAccount}" "${gDockerRepoPassword}"
  fi
}

#生成并初始化DockerFile文件
function initialDockerFile_ex() {
  export gDefaultRetVal
  export gDockerBuildDir
  export gDockerFileTemplateParamMap

  local l_cicdYaml=$1
  local l_dockerFileTemplate=$2

  local l_fileList
  local l_tmpFile

  local l_targetDockerFile
  local l_arrayInfo
  local l_placeholders
  local l_placeholder
  local l_value

  #删除已经存在的Dockerfile文件。
  l_targetDockerFile="${l_dockerFileTemplate##*/}"
  # shellcheck disable=SC2206
  l_arrayInfo=(${l_targetDockerFile//_/ })
  l_fileList=$(find "${gDockerBuildDir}" -maxdepth 1 -type f -name "${l_arrayInfo[0]}*")
  if [ "${l_fileList}" ];then
    # shellcheck disable=SC2068
    for l_tmpFile in ${l_fileList[@]};do
      rm -f "${l_tmpFile:?}"
    done
  fi

  #复制模板文件到Docker镜像构建目录中。
  l_targetDockerFile="${gDockerBuildDir}/${l_dockerFileTemplate##*/}"
  cat "${l_dockerFileTemplate}" > "${l_targetDockerFile}"

  #Dockerfile模板文件中的占位符号只能是大写字母、数子和”-“构成。
  # shellcheck disable=SC2002
  l_placeholders=$(cat "${l_targetDockerFile}" | grep -oP "_([A-Z]?[A-Z0-9\-]+)_" | sort | uniq -c)
  # shellcheck disable=SC2068
  for l_placeholder in ${l_placeholders[@]};do
    if [[ "${l_placeholder}" =~ ^(_).*$ ]];then
      eval "l_value=\${gDockerFileTemplateParamMap[\"${l_placeholder}\"]}"
      if [ "${l_value}" ];then
        l_value="${l_value//\//\\\/}"
        sed -i "s/${l_placeholder}/${l_value}/g" "${l_targetDockerFile}"
      else
        warn "未配置${l_targetDockerFile##*/}文件中占位符${l_placeholder}的值"
      fi
    fi
  done

  gDefaultRetVal="${l_targetDockerFile}"
}

function onBeforeCreatingDockerImage_ex() {
  export gDockerRepoName
  export gTargetDockerFromImage_business
  export gTargetDockerFromImage_base
  export gImageCacheDir

  local l_ciCdYamlFile=$1
  local l_archType=$2
  local l_dockerFile=$3

  local l_image

  #将配置的目录拷贝到Docker构建目录中。
  _copyDirsIntoDockerBuildDir "${l_ciCdYamlFile}" "${l_archType}"

  #提前拉取Dockerfile文件中From语句中定义的基础镜像。
  #如果配置了私库信息，则尝试将拉取的镜像推送到私库中。
  #为封闭网络环境下开发做好工作。
  if [[ "${l_dockerFile}" =~ ^(.*)_business$ ]];then
    l_image="${gTargetDockerFromImage_business}"
  else
    l_image="${gTargetDockerFromImage_base}"
  fi

  #提前拉取好fromImage镜像。
  pullImage "${l_image}" "${l_archType}" "${gDockerRepoName}" "${gImageCacheDir}"
}

function createDockerImage_ex() {
  export gBuildType
  export gTargetDockerName_business
  export gTargetDockerVersion_business
  export gTargetDockerName_base
  export gTargetDockerVersion_base

  local l_cicdYaml=$1
  local l_archType=$2
  local l_dockerFile=$3

  local l_imageName
  local l_imageVersion

  if [[ "${l_dockerFile}" =~ ^(.*)_business$ ]];then
    l_imageName="${gTargetDockerName_business}"
    l_imageVersion="${gTargetDockerVersion_business}"
  else
    l_imageName="${gTargetDockerName_base}"
    l_imageVersion="${gTargetDockerVersion_base}"
  fi

  _createDockerImage "${l_imageName}:${l_imageVersion}" "${l_archType}" "${l_dockerFile}"

}

function onAfterCreatingDockerImage_ex(){
  #l_image参数前面没有仓库前缀。
  local l_image=$1
  local l_archType=$2

  _onAfterCreatingDockerImage "${l_image}" "${l_archType}"

}

#docker阶段单镜像模式下（默认是双镜像模式）对ci-cd.yaml文件的调整
function handleBuildingSingleImageForDocker_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gBuildType

  local l_paramArray
  local l_paramItem
  local l_paramName
  local l_paramName1
  local l_paramValue

  #对于单镜像打包，要修正docker.base.name和docker.base.version的值。
  l_paramArray=("docker.base.name|globalParams.businessImage" \
    "docker.base.version|globalParams.businessVersion" )
  # shellcheck disable=SC2068
  for l_paramItem in ${l_paramArray[@]};do
    l_paramName="${l_paramItem%%|*}"
    l_paramName1="${l_paramItem#*|}"

    if [[ "${l_paramName1}" =~ ^(globalParams\.) ]];then
      readParam "${gCiCdYamlFile}" "${l_paramName1}"
      [[ "${gDefaultRetVal}" == "null" ]] && error "读取${gCiCdYamlFile##*/}文件中${l_paramName1}参数失败"
      l_paramValue="${gDefaultRetVal}"
      if [ "${l_paramName1}" == "globalParams.businessImage" ];then
        #删除业务镜像的后缀"-business"
        l_paramValue="${l_paramValue//-business/}"
      fi
    else
      #直接将l_paramName1作为参数值。
      l_paramValue="${l_paramName1}"
    fi

    updateParam "${gCiCdYamlFile}" "${l_paramName}" "${l_paramValue}"
    if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
      error "更新${gCiCdYamlFile##*/}文件中${l_paramName}参数失败"
    else
      warn "更新${gCiCdYamlFile##*/}文件中${l_paramName}参数的值为:${l_paramValue}"
    fi
  done

}

#**********************私有方法-开始***************************#

function _copyFilesIntoDockerBuildDir() {
  export gBuildPath
  export gDockerBuildDir

  local l_ciCdYamlFile=$1

  local l_copyFiles
  local l_copyFile
  local l_path
  local l_fileName

  local l_targetFiles
  local l_targetFile

  readParam "${l_ciCdYamlFile}" "docker.copyFiles"
  if [ "${gDefaultRetVal}" != "null" ];then
    # shellcheck disable=SC2206
    l_copyFiles=(${gDefaultRetVal//,/ })
    # shellcheck disable=SC2068
    for l_copyFile in ${l_copyFiles[@]};do

      if [[ "${l_copyFile}" =~ ^([ ]*)\. ]];then
        #相对路径转绝对路径
        l_copyFile="${gBuildPath}${l_copyFile:1}"
      elif [[ "${l_copyFile}" =~ ^([ ]*)([a-zA-Z_]?) ]];then
        #相对路径转绝对路径
        l_copyFile="${gBuildPath}/${l_copyFile}"
      fi

      l_path="${l_copyFile%/*}"
      l_fileName="${l_copyFile##*/}"
      l_targetFiles=$(find "${l_path}" -maxdepth 1 -type f -name "${l_fileName}")
      for l_targetFile in ${l_targetFiles[@]};do
        info "复制${l_fileName}文件到Docker构建目录中"
        cp -f "${l_targetFile}" "${gDockerBuildDir}"
      done

    done
  fi

}

function _copyDirsIntoDockerBuildDir() {
  export gDefaultRetVal
  export gBuildPath
  export gDockerBuildDir

  local l_ciCdYamlFile=$1
  local l_archType=$2

  local l_copyDirs
  local l_copyDir

  readParam "${l_ciCdYamlFile}" "docker.copyDirs"
  if [ "${gDefaultRetVal}" != "null" ];then
    # shellcheck disable=SC2206
    l_copyDirs=(${gDefaultRetVal//,/ })
    # shellcheck disable=SC2068
    for l_copyDir in ${l_copyDirs[@]};do

      if [[ "${l_copyDir}" =~ ^([ ]*)\. ]];then
        #相对路径转绝对路径
        l_copyDir="${gBuildPath}${l_copyDir:1}"
      elif [[ "${l_copyDir}" =~ ^([ ]*)([a-zA-Z_]?) ]];then
        #相对路径转绝对路径
        l_copyDir="${gBuildPath}/${l_copyDir}"
      fi

      if [ -d "${l_copyDir}/${l_archType//\//-}" ];then
        rm -rf "${gDockerBuildDir:?}/${l_copyDir##*/}" 2>&1
        if [ ! -d "${gDockerBuildDir}/${l_copyDir##*/}/${l_archType//\//-}" ];then
          mkdir -p "${gDockerBuildDir}/${l_copyDir##*/}/${l_archType//\//-}"
        fi
        info "复制${l_copyDir##*/}/${l_archType//\//-}目录中的文件到Docker构建目录中"
        cp -rf "${l_copyDir}/${l_archType//\//-}/" "${gDockerBuildDir}/${l_copyDir##*/}"
      fi

    done
  fi

}

function _createDockerImage() {
  export gDefaultRetVal
  export gDeleteImageAfterBuilding
  export gDockerRepoName
  export gDockerRepoInstanceName
  export gDockerRepoWebPort
  export gDockerRepoAccount
  export gDockerRepoPassword

  export gCurrentStageResult
  export gTempFileDir
  export gDockerRepoType

  local l_image=$1
  local l_archType=$2
  local l_dockerFile=$3

  local l_dockerBuildDir
  local l_errorLog

  l_dockerBuildDir="${l_dockerFile%/*}"

  existDockerImage "${l_image}"
  if [ "${gDefaultRetVal}" == "${l_image}" ];then
    info "创建docker镜像前,先删除现有的同名Docker镜像: ${l_image}..." "-n"
    docker rmi "${l_image}"
    info "成功" "*"
  fi

  # shellcheck disable=SC2088
  l_tmpFile="${gTempFileDir}/docker-build-${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"
  info "构建docker镜像:${l_image} ..."
  docker build --no-cache -t "${l_image}" -f "${l_dockerFile}" "${l_dockerBuildDir}" 2>&1 | tee "${l_tmpFile}"
  # shellcheck disable=SC2002
  l_errorLog=$(cat "${l_tmpFile}" | grep -oP "^.*(Error|failed).*$")
  unregisterTempFile "${l_tmpFile}"

  if [ "${l_errorLog}" ];then
    error "docker镜像构建(docker build --no-cache -t ${l_image} -f ${l_dockerFile} ${l_dockerBuildDir})失败:${l_errorLog}"
  fi

  #将生成的镜像推送到私有仓库（测试环境使用的仓库）中
  if [ "${gDockerRepoName}" ];then
    #先删除已经存在的镜像。
    invokeExtendChain "onBeforePushDockerImage" "${gDockerRepoType}" "${l_image}" "${gDockerRepoName}" \
      "${gDockerRepoInstanceName}" "${gDockerRepoWebPort}" "${gDockerRepoAccount}" "${gDockerRepoPassword}"
    info "将${l_image}镜像推送到${gDockerRepoName}仓库中..."
    pushImage "${l_image}" "${l_archType}" "${gDockerRepoName}"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" != "true" ]] && error "镜像推送失败" || info "镜像推送成功"
  fi

  gCurrentStageResult="INFO|成功构建${l_archType}架构的${l_image}镜像"
  gDefaultRetVal="${l_image}"

}

function _onAfterCreatingDockerImage(){
  export gHelmBuildOutDir

  #l_image参数前面没有仓库前缀。
  local l_image=$1
  local l_archType=$2

  info "将生成的镜像导出到${gHelmBuildOutDir}/${l_archType//\//-}目录的文件中"
  saveImage "${l_image}" "${l_archType}" "${gHelmBuildOutDir}/${l_archType//\//-}"

}
#**********************私有方法-结束***************************#

#加载build阶段脚本库文件
loadExtendScriptFileForLanguage "docker"

declare -A gDockerFileTemplateParamMap
export gDockerFileTemplateParamMap

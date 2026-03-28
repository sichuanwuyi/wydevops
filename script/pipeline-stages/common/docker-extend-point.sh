#!/usr/bin/env bash

function createThirdPartyImage_ex(){
  export gDockerRepoName
  export gImageCacheDir
  export gCurrentStageResult
  export gDefaultRetVal
  export gLogI18NRetVal

  local l_image=$1
  local l_archType=$2
  local l_exportFile=$3

  gDefaultRetVal=""
  #如果没有提供第三方镜像的导出文件，则拉取该镜像。
  if [ ! "${l_exportFile}" ];then
    #打包第三方镜像：拉取第三方镜像，缓存到本地镜像缓存目录中，
    #然后推送到私库中，最后导出到gDockerBuildOutDir目录中。
    pullImage "${l_image}" "${l_archType}" "${gDockerRepoName}" "${gImageCacheDir}"
    convertI18NText "common.docker.extend.point.pull.third.party.image.success" "${l_archType}#${l_image}"
    gCurrentStageResult="INFO|${gLogI18NRetVal}"
    gDefaultRetVal="${l_image}"
  fi
}

function onAfterCreatingThirdPartyImage_ex() {
  export gDefaultRetVal
  export gBuildPath

  #l_image参数前面没有仓库前缀。
  local l_image=$1
  local l_archType=$2
  local l_exportFile=$3

  if [ "${l_exportFile}" ];then
    info "common.docker.extend.point.copying.third.party.image" "${gHelmBuildOutDir}/${l_archType//\//-}"
    cp -f "${l_exportFile}" "${gHelmBuildOutDir}/${l_archType//\//-}"
  else
    info "common.docker.extend.point.exporting.third.party.image" "${gHelmBuildOutDir}/${l_archType//\//-}"
    saveImage "${l_image}" "${l_archType}" "${gHelmBuildOutDir}/${l_archType//\//-}"
    if [ "${gDeleteImageAfterBuilding}" == "true" ];then
      info "common.docker.extend.point.deleting.local.third.party.image" "${l_image}"
      docker rmi "${l_image}"
    fi
  fi

  gDefaultRetVal="common.docker.extend.point.handle.third.party.image.success" "${l_archType}#${l_image}"
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
  l_content=$(grep -ioE "^([ ]*)FROM([ ]+).*$" "${l_dockerFile}")
  if [ ! "${l_content}" ];then
    error "common.docker.extend.point.from.statement.not.found" "${l_dockerFile}"
  fi

  stringToArray "${l_content}" "l_lines"
  # shellcheck disable=SC2154
  l_lineCount=${#l_lines[@]}

  # shellcheck disable=SC2068
  for ((l_i = 0; l_i < l_lineCount; l_i++ ));do
    l_fromLine="${l_lines[${l_i}]}"
    l_fromLine=$(grep -inoE "^.*(--platform=${l_archType//\//\\\/}).*$" <<< "${l_fromLine}")
    if [[ ! "${l_fromLine}" ]];then
      error "common.docker.extend.point.platform.not.defined" "${l_dockerFile}#${l_archType}"
    fi
    #拉取from语句中定义的基础镜像
    # shellcheck disable=SC2206
    l_params=(${l_fromLine})
    l_fromImage="${l_params[2]}"
    pullImage "${l_fromImage}" "${l_archType}" "${gDockerRepoName}" "${gImageCacheDir}"
    gDockerFileTemplateParamMap["_FROM-IMAGE${l_i}_"]="${l_fromImage}"
  done
}

function creatingCustomizedImage_ex() {
  local l_image=$1
  local l_archType=$2
  local l_dockerFile=$3

  _createDockerImage "${l_image}" "${l_archType}" "${l_dockerFile}"
}

function onAfterCreatingCustomizedImage_ex(){
  #l_image参数前面没有仓库前缀。
  local l_image=$1
  local l_archType=$2

  _onAfterCreatingDockerImage "${l_image}" "${l_archType}"
}

function onBeforeInitialingGlobalParamsForDockerStage_ex(){
  export gBuildType
  export gCiCdYamlFile

  if [ "${gBuildType}" == "single" ];then
    #制作单镜像时，对ci-cd.yaml文件进行特殊处理。
    invokeExtendPointFunc "handleBuildingSingleImageForDocker" "common.docker.extend.point.handling.single.image.build" "" "${gCiCdYamlFile}"
  fi
}

function initialGlobalParamsForDockerStage_ex(){
  export gDefaultRetVal
  export gLogI18NRetVal
  export gBuildScriptRootDir
  export gArchTypes
  export gBuildType
  export gUseTemplate
  export gBuildPath
  export gLanguage
  export gProjectDockerTemplateDir
  export gProjectTemplateDirName
  export gProjectDockerTemplateDirName
  export gRuntimeVersion

  #docker阶段特有的全局变量
  export gDockerfileTemplates
  export gWorkDirInDocker
  export gAppDirInDocker
  export gExposePorts
  export gTimeZone
  export gJvmOpts
  export gJavaOpts
  export gProjectBuildOutDir
  export gThirdParties
  export gSaveBackImmediately
  export gEnableNoCacheOnDockerBuild
  export gOfflineDockerFileDir

  local l_cicdYaml=$1
  local l_dockerFiles
  local l_dockerFile

  local l_offlineDir
  local l_runtimeVersion
  local l_dockerFilePath

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
  info "common.docker.extend.point.reading.param.buildtype" "${gBuildType}"

  if [ ! "${gEnableNoCacheOnDockerBuild}" ];then
    readParam "${l_cicdYaml}" "docker.enableNoCache"
    gEnableNoCacheOnDockerBuild="${gDefaultRetVal}"
  fi
  info "common.docker.extend.point.reading.param.enablenocache" "${gEnableNoCacheOnDockerBuild}"

  #如果gArchTypes尚未赋值，择从ci-cd.yaml文件中读取。
  if [ ! "${gArchTypes}" ];then
    readParam "${l_cicdYaml}" "docker.archTypes"
    gArchTypes="${gDefaultRetVal}"
    warn "common.docker.extend.point.reading.param.archtypes" "${gArchTypes}"
  fi

  if [ "${gBuildType}" != "thirdParty" ];then
    #是否强制使用Docker模板文件。
    readParam "${l_cicdYaml}" "docker.useTemplate"
    gUseTemplate="${gDefaultRetVal}"
    info "common.docker.extend.point.reading.param.usetemplate" "${gUseTemplate}"

    #应用基础容器中应用工作路径，
    readParam "${l_cicdYaml}" "docker.workDir"
    gWorkDirInDocker="${gDefaultRetVal}"
    info "common.docker.extend.point.reading.param.workdir" "${gWorkDirInDocker}"

    #应用业务镜像中应用文件的存储路径，注意要与挂载的ConfigMap目录保持一致。
    readParam "${l_cicdYaml}" "docker.appDir"
    gAppDirInDocker="${gDefaultRetVal}"
    info "common.docker.extend.point.reading.param.appdir" "${gAppDirInDocker}"

    #应用业务镜像中应用文件的存储路径，注意要与挂载的ConfigMap目录保持一致。
    readParam "${l_cicdYaml}" "docker.exposePorts"
    gExposePorts="${gDefaultRetVal//,/ }"
    info "common.docker.extend.point.reading.param.exposeports" "${gExposePorts}"

    #docker容器内的时区配置
    readParam "${l_cicdYaml}" "docker.timeZone"
    gTimeZone="${gDefaultRetVal}"
    info "common.docker.extend.point.reading.param.timezone" "${gTimeZone}"

    #读取JvmOpts参数
    readParam "${l_cicdYaml}" "docker.jvmOpts"
    gJvmOpts="${gDefaultRetVal}"
    info "common.docker.extend.point.reading.param.jvmopts" "${gJvmOpts}"

    #读取JavaOpts参数
    readParam "${l_cicdYaml}" "docker.javaOpts"
    gJavaOpts="${gDefaultRetVal}"
    info "common.docker.extend.point.reading.param.javaopts" "${gJavaOpts}"

    # shellcheck disable=SC2028
    l_typeNames=("business" "base")
    l_params=("name" "version" "fromImage")
    # shellcheck disable=SC2068
    for l_typeName in ${l_typeNames[@]};do
      for l_param in ${l_params[@]};do
        readParam "${l_cicdYaml}" "docker.${l_typeName}.${l_param}"
        eval "export gTargetDocker${l_param^}_${l_typeName}=\"${gDefaultRetVal}\""
        convertI18NText "common.docker.extend.point.reading.param.value" "docker.${l_typeName}.${l_param}#gTargetDocker${l_param^}_${l_typeName}#${gDefaultRetVal}"
        eval "info \"${gLogI18NRetVal}\""
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
        error "common.docker.extend.point.invalid.build.type" "${gBuildType}"
        ;;
    esac

    l_offlineDir=""
    [[ "${gOfflineDockerFileDir}" ]] && l_offlineDir="${gOfflineDockerFileDir}/"

    l_runtimeVersion=""
    [[ "${gRuntimeVersion}" ]] && l_runtimeVersion="${gRuntimeVersion}/"

    l_dockerFilePath="${gBuildScriptRootDir}/${gProjectTemplateDirName}/${gProjectDockerTemplateDirName}"

    if [[ "${gBuildType}" != "thirdParty" && "${gBuildType}" != "customize" ]];then
      gDockerfileTemplates=""
      # shellcheck disable=SC2206
      l_dockerFiles=(${l_dockerFiles})
      # shellcheck disable=SC2068
      for l_dockerFile in ${l_dockerFiles[@]};do
        if [ -f "${gProjectDockerTemplateDir}/${l_runtimeVersion}${l_offlineDir}${l_dockerFile}" ];then
          #使用项目级配置的Dockerfile文件
          gDockerfileTemplates="${gDockerfileTemplates} ${gProjectDockerTemplateDir}/${l_runtimeVersion}${l_offlineDir}${l_dockerFile}"
        elif  [ -f "${gProjectDockerTemplateDir}/${l_offlineDir}${l_dockerFile}" ];then
          #使用项目级配置的Dockerfile文件
          gDockerfileTemplates="${gDockerfileTemplates} ${gProjectDockerTemplateDir}/${l_offlineDir}${l_dockerFile}"
        elif  [ -f "${gProjectDockerTemplateDir}/${l_dockerFile}" ];then
          #使用项目级配置的Dockerfile文件
          gDockerfileTemplates="${gDockerfileTemplates} ${gProjectDockerTemplateDir}/${l_dockerFile}"

        elif [ -f "${l_dockerFilePath}/${gLanguage}/${l_runtimeVersion}${l_offlineDir}${l_dockerFile}" ];then
          #使用语言级指定SDK版本的Dockerfile文件
          gDockerfileTemplates="${gDockerfileTemplates} ${l_dockerFilePath}/${gLanguage}/${l_runtimeVersion}${l_offlineDir}${l_dockerFile}"
        elif [ -f "${l_dockerFilePath}/${gLanguage}/${l_offlineDir}${l_dockerFile}" ];then
          #使用语言级指定Dockerfile文件
          gDockerfileTemplates="${gDockerfileTemplates} ${l_dockerFilePath}/${gLanguage}/${l_offlineDir}${l_dockerFile}"
        elif [ -f "${l_dockerFilePath}/${gLanguage}/${l_dockerFile}" ];then
          #使用语言级指定Dockerfile文件
          gDockerfileTemplates="${gDockerfileTemplates} ${l_dockerFilePath}/${gLanguage}/${l_dockerFile}"
        elif [ -f "${l_dockerFilePath}/${l_dockerFile}" ];then
          #使用公共级Dockerfile文件
          gDockerfileTemplates="${gDockerfileTemplates} ${l_dockerFilePath}/${l_dockerFile}"
        else
          error "common.docker.extend.point.template.file.not.found" "${l_dockerFile}"
        fi
      done

      warn "common.docker.extend.point.enabled.dockerfiles" "${gDockerfileTemplates}"

      #定义项目默认的编译输出目录，各语言项目可在语言级扩展中重新定义各个变量。
      gProjectBuildOutDir="${gBuildPath}/out"

      if [ "${gDockerBuildDir}" ];then
        info "common.docker.extend.point.clearing.dir" "${gDockerBuildDir##*/}"
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
  export gJvmOpts
  export gJavaOpts
  export gWorkDirInDocker
  export gAppDirInDocker
  export gServiceName

  export gDockerFileTemplateParamMap

  local l_ciCdYamlFile=$1

  #定义Dockerfile文件中占位符的具体值。
  gDockerFileTemplateParamMap["_EXPOSE_"]="${gExposePorts}"
  gDockerFileTemplateParamMap["_TZ_"]="${gTimeZone}"
  gDockerFileTemplateParamMap["_WORK-DIR-IN-CONTAINER_"]="${gWorkDirInDocker}"
  gDockerFileTemplateParamMap["_APP-DIR-IN-CONTAINER_"]="${gAppDirInDocker}"
  gDockerFileTemplateParamMap["_SERVICE-NAME_"]="${gServiceName}"
  gDockerFileTemplateParamMap["_JVM-OPTS_"]="${gJvmOpts}"
  gDockerFileTemplateParamMap["_JAVA-OPTS_"]="${gJavaOpts}"
  #以下参数必须知道当前Dockerfile文件名称后才能确定。
  gDockerFileTemplateParamMap["_FROM-IMAGE0_"]=""
  #以下参数必须知道当前处理的架构类型后才能确定。
  gDockerFileTemplateParamMap["_PLATFORM_"]=""
  gDockerFileTemplateParamMap["_OS-TYPE_"]=""
  gDockerFileTemplateParamMap["_ARCH-TYPE_"]=""
  gDockerFileTemplateParamMap["_ARCH_"]=""

  info "common.docker.extend.point.processing.copyfiles"
  _copyFilesIntoDockerBuildDir "${l_ciCdYamlFile}"

  info "common.docker.extend.point.copying.configmap.files"
  _copyConfigMapFiles "${l_ciCdYamlFile}"

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
  l_placeholders=$(grep -oE "_([A-Z]?[A-Z0-9\-]+)_" "${l_targetDockerFile}" | sort | uniq -c)
  # shellcheck disable=SC2068
  for l_placeholder in ${l_placeholders[@]};do
    if [[ "${l_placeholder}" =~ ^(_).*$ ]];then
      eval "l_value=\${gDockerFileTemplateParamMap[\"${l_placeholder}\"]}"
      if [ "${l_value}" ];then
        l_value="${l_value//\//\\\/}"
        sed -i "s/${l_placeholder}/${l_value}/g" "${l_targetDockerFile}"
      else
        warn "common.docker.extend.point.placeholder.not.configured" "${l_targetDockerFile##*/}#${l_placeholder}"
        sed -i "s/${l_placeholder}//g" "${l_targetDockerFile}"
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

  local l_content
  local l_image
  local l_images

  #将配置的目录拷贝到Docker构建目录中。
  _copyDirsIntoDockerBuildDir "${l_ciCdYamlFile}" "${l_archType}"

  #提前拉取Dockerfile文件中From语句中定义的基础镜像。
  #如果配置了私库信息，则尝试将拉取的镜像推送到私库中。
  #为封闭网络环境下开发做好工作。
  if [[ "${l_dockerFile}" =~ ^(.*)_business$ ]];then
    l_content="${gTargetDockerFromImage_business}"
  else
    l_content="${gTargetDockerFromImage_base}"
  fi

  # shellcheck disable=SC2206
  l_images=(${l_content//,/ })
  # shellcheck disable=SC2068
  for l_image in ${l_images[@]};do
    #删除空格符
    l_image="${l_image// /}"
    [[ "${l_image}" =~ ^scratch(:|$).* ]] && continue
    info "common.docker.extend.point.pulling.image" "${l_image}"
    pullImage "${l_image}" "${l_archType}" "${gDockerRepoName}" "${gImageCacheDir}"
  done
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
      [[ "${gDefaultRetVal}" == "null" ]] && error "common.docker.extend.point.read.param.failed" "${gCiCdYamlFile##*/}#${l_paramName1}"
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
      error "common.docker.extend.point.update.param.failed" "${gCiCdYamlFile##*/}#${l_paramName}"
    else
      warn "common.docker.extend.point.update.param.success" "${gCiCdYamlFile##*/}#${l_paramName}#${l_paramValue}"
    fi
  done

}

#**********************私有方法-开始***************************#

function _copyFilesIntoDockerBuildDir() {
  export gBuildPath
  export gDockerBuildDir
  export gActiveProfile

  local l_ciCdYamlFile=$1

  local l_copyFiles
  local l_copyFile
  local l_path
  local l_fileName

  local l_targetFiles
  local l_targetFile
  local l_arrays
  local l_arrayLen

  readParam "${l_ciCdYamlFile}" "docker.copyFiles"
  if [ "${gDefaultRetVal}" != "null" ];then
    # shellcheck disable=SC2206
    l_copyFiles=(${gDefaultRetVal//,/ })
    # shellcheck disable=SC2068
    for l_copyFile in ${l_copyFiles[@]};do

      if [[ "${l_copyFile}" =~ ^([ ]*)\.\/ ]];then
        #相对路径转绝对路径
        l_copyFile="${gBuildPath}${l_copyFile:1}"
      elif [[ "${l_copyFile}" =~ ^([ ]*)([a-zA-Z_]?) ]];then
        #相对路径转绝对路径
        l_copyFile="${gBuildPath}/${l_copyFile}"
      fi

      # shellcheck disable=SC2206
      l_arrays=(${l_copyFile//|/ })
      l_arrayLen="${#l_arrays[@]}"

      l_path="${l_arrays[0]%/*}"
      l_fileName="${l_arrays[0]##*/}"

      # shellcheck disable=SC2081
      if [[ "${l_fileName}" != *\** && "${l_fileName}" != *"${gActiveProfile}"* ]];then
        l_fileName="${l_fileName%.*}-${gActiveProfile}.${l_fileName##*.}"
      fi

      l_targetFiles=$(find "${l_path}" -maxdepth 1 -type f -name "${l_fileName}")
      if [ ! -f "${l_targetFiles}" ];then
        l_targetFiles="${l_arrays[0]}"
      fi

      for l_targetFile in ${l_targetFiles[@]};do
        if  [ "${l_arrayLen}" -ge 2 ];then
          #如果目录不存在则创建之。
          if [ ! -d "${gDockerBuildDir}/${l_arrays[1]}" ];then
            mkdir -p "${gDockerBuildDir}/${l_arrays[1]}"
          fi
          info "common.docker.extend.point.copying.file.to.subdir" "${l_targetFile}#${l_arrays[1]}"
          cp -f "${l_targetFile}" "${gDockerBuildDir}/${l_arrays[1]}"
        else
          info "common.docker.extend.point.copying.file.to.build.dir" "${l_targetFile}"
          cp -f "${l_targetFile}" "${gDockerBuildDir}"
        fi
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
      if [[ "${l_copyDir}" =~ ^([ ]*)\.\/ ]];then
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
        info "common.docker.extend.point.copying.files.from.arch.dir" "${l_copyDir##*/}/${l_archType//\//-}"
        cp -rf "${l_copyDir}/${l_archType//\//-}/" "${gDockerBuildDir}/${l_copyDir##*/}"
      else
        #先删除存在的目标目录。
        rm -rf "${gDockerBuildDir:?}/${l_copyDir##*/}" 2>&1
        info "common.docker.extend.point.copying.files.from.arch.dir" "${l_copyDir##*/}"
        cp -rf "${l_copyDir}/" "${gDockerBuildDir}/${l_copyDir##*/}"
      fi

    done
  fi

}

function _createDockerImage() {
  export gDefaultRetVal
  export gLogI18NRetVal
  export gDeleteImageAfterBuilding
  export gDockerRepoName
  export gDockerRepoInstanceName
  export gDockerRepoWebPort
  export gDockerRepoAccount
  export gDockerRepoPassword
  export gRunID

  export gCurrentStageResult
  export gTempFileDir
  export gDockerRepoType
  export gEnableNoCacheOnDockerBuild

  local l_image=$1
  local l_archType=$2
  local l_dockerFile=$3

  local l_dockerBuildDir
  local l_errorLog
  local l_pushedImageFile
  local l_key

  l_dockerBuildDir="${l_dockerFile%/*}"

  existDockerImage "${l_image}"
  if [ "${gDefaultRetVal}" == "${l_image}" ];then
    info "common.docker.extend.point.deleting.existing.image" "${l_image}" "-n"
    docker rmi "${l_image}"
    info "common.docker.extend.point.success" "" "*"
  fi

  # shellcheck disable=SC2088
  l_tmpFile="${gTempFileDir}/docker-build-${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"
  info "common.docker.extend.point.building.image" "${l_image}"

  if [ "${gEnableNoCacheOnDockerBuild}" == "true" ];then
    info "common.docker.extend.point.executing.command" "docker buildx build --no-cache --platform ${l_archType} --tag ${l_image} --file ${l_dockerFile} ${l_dockerBuildDir}"
    docker buildx build --no-cache --platform "${l_archType}" --tag "${l_image}" --file "${l_dockerFile}" "${l_dockerBuildDir}" 2>&1 | tee "${l_tmpFile}"
  else
    info "common.docker.extend.point.executing.command" "docker buildx build --platform ${l_archType} --tag ${l_image} --file ${l_dockerFile} ${l_dockerBuildDir}"
    docker buildx build --platform "${l_archType}" --tag "${l_image}" --file "${l_dockerFile}" "${l_dockerBuildDir}" 2>&1 | tee "${l_tmpFile}"
  fi

  l_errorLog=$(cat "${l_tmpFile}")
  unregisterTempFile "${l_tmpFile}"

  # shellcheck disable=SC2181
  if [ "$?" -ne 0 ];then
    error "common.docker.extend.point.image.build.failed" "${l_errorLog}"
  fi

  #将生成的镜像推送到私有仓库（测试环境使用的仓库）中
  if [ "${gDockerRepoName}" ];then
    #先删除已经存在的镜像。
    invokeExtendChain "onBeforePushDockerImage" "${gDockerRepoType}" "${l_image}" "${l_archType}" "true" "${gDockerRepoName}" \
      "${gDockerRepoInstanceName}" "${gDockerRepoWebPort}" "${gDockerRepoAccount}" "${gDockerRepoPassword}"
    info "common.docker.extend.point.pushing.image.to.repo" "${l_image}#${gDockerRepoName}" "-n"
    pushImage "${l_image}" "${l_archType}" "${gDockerRepoName}"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" != "true" ]] && error "common.docker.extend.point.failed" "" "*" || info "common.docker.extend.point.success" "" "*"

    l_pushedImageFile="${gHelmBuildOutDir}/${l_archType//\//-}/pushed-images.yaml"
    l_key="${l_image//:/@}"
    l_key="${l_key//./_}"
    info "common.docker.extend.point.recording.pushed.image.info" "${l_pushedImageFile}#${l_key}#${gRunID}"
    echo "images:" > "${l_pushedImageFile}"
    insertParam "${l_pushedImageFile}" "images.${l_key}" "${gRunID}"
  fi

  convertI18NText "common.docker.extend.point.build.image.success.arch" "${l_archType}#${l_image}"
  gCurrentStageResult="INFO|${gLogI18NRetVal}"
  gDefaultRetVal="${l_image}"
}

function _onAfterCreatingDockerImage(){
  export gHelmBuildOutDir

  #l_image参数前面没有仓库前缀。
  local l_image=$1
  local l_archType=$2

  info "common.docker.extend.point.exporting.image.to.dir" "${gHelmBuildOutDir}/${l_archType//\//-}"
  saveImage "${l_image}" "${l_archType}" "${gHelmBuildOutDir}/${l_archType//\//-}"

}

function _copyConfigMapFiles() {
  export gBuildType
  export gBuildPath
  export gDockerBuildDir
  export gDefaultRetVal

  local l_ciCdYamlFile=$1

  local l_targetFiles
  local l_targetFile
  local l_applicationYamls

  if [ "${gBuildType}" != "thirdParty" ];then
    mkdir -p "${gDockerBuildDir}/wydevops-config"
    #读取globalParams.configMapFiles参数的值。
    readParam "${l_ciCdYamlFile}" "globalParams.configMapFiles"
    [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && return
    l_targetFiles="${gDefaultRetVal}"
    # shellcheck disable=SC2206
    l_applicationYamls=(${l_targetFiles//,/ })
    # shellcheck disable=SC2068
    for l_targetFile in ${l_applicationYamls[@]};do
      [[ "${l_targetFile}" =~ ^(\./) ]] && l_targetFile="${gBuildPath}/${l_targetFile:2}"
      cp -f "${l_targetFile}" "${gDockerBuildDir}/wydevops-config" || true
    done
  fi
}

#**********************私有方法-结束***************************#

#加载build阶段脚本库文件
loadExtendScriptFileForLanguage "docker"

declare -A gDockerFileTemplateParamMap
export gDockerFileTemplateParamMap

export gEnableNoCacheOnDockerBuild

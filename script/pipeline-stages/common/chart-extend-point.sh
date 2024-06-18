#!/usr/bin/env bash

function onBeforeInitialingGlobalParamsForChartStage_ex() {
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gHelmBuildDir
  export gBuildType
  export gCiCdYamlFile
  export gChartRepoType
  export gChartRepoInstanceName

  local l_systemType
  local l_archType
  local l_info

  #检查是否安装有helm工具。
  if ! command -v helm &> /dev/null; then
    #检查当前操作系统类型
    invokeExtendChain "onGetSystemArchInfo"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "false" ]] && error "读取本地系统架构信息失败" || info "读取到当前系统架构为:${gDefaultRetVal}"
    #将生成的Chart镜像推送到gChartRepoName仓库中。
    invokeExtendPointFunc "installHelm" "在本地系统中安装helm工具" "${gDefaultRetVal%%/*}" "${gDefaultRetVal#*/}"
  fi

  if [ "${gChartRepoInstanceName}" ];then
    l_info="在本地系统中注册helm仓库"
    [[ "${gChartRepoType}" == "harbor" ]] && l_info="登录harbor仓库"
    invokeExtendPointFunc "addHelmRepo" "${l_info}"
  fi

  if [ "${gBuildType}" == "single" ];then
    #制作单镜像时，对ci-cd.yaml文件进行特殊处理。
    invokeExtendPointFunc "handleBuildingSingleImageForChart" "chart阶段单镜像构建模式下对ci-cd.yaml文件中参数的特殊调整" "${gCiCdYamlFile}"
  fi

  #处理ci-cd.yaml文件中的container[].ports，生成service配置，并展开containerPort配置项。
  _processContainerPorts "${gCiCdYamlFile}"

  #将ci-cd.yaml文件中chart配置列表项拆分为多个服务目录下的package.yaml文件。
  _initialPackageYamlFile

}

function onBeforeCreatingChartImage_ex() {
  export gDefaultRetVal
  export gCustomizedHelm
  export gCurrentChartName
  export gCurrentChartVersion
  export gCurrentAppVersion
  export gCurrentAppDescription

  local l_chartPath=$1

  local l_packageFile
  local l_chartYaml
  local l_content
  local l_mustExistFiles
  local l_abortedFiles
  local l_file

  l_packageFile="${l_chartPath}/package.yaml"

  readParam "${l_packageFile}" "name"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && error "name参数值不能为空"
  gCurrentChartName="${gDefaultRetVal}"

  readParam "${l_packageFile}" "version"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && error "version参数值不能为空"
  gCurrentChartVersion="${gDefaultRetVal}"

  readParam "${l_packageFile}" "appVersion"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && error "appVersion参数值不能为空"
  gCurrentAppVersion="${gDefaultRetVal}"

  gCurrentAppDescription=""
  readParam "${l_packageFile}" "description"
  [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]] && gCurrentAppDescription="${gDefaultRetVal}"

  readParam "${l_packageFile}" "customizedHelmDir"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    gCustomizedHelm="true"
  else
    gCustomizedHelm="false"
  fi

  if [ "${gCustomizedHelm}" == "false" ];then
    #执行helm create生成打包内容
    l_content=$(helm create "${l_chartPath}" | grep -ioP "^.*(Error|failed).*$")
    if [ "${l_content}" ];then
      error "执行命令(helm create ${l_chartPath})失败: ${l_content}"
    fi
    #删除的无效的文件或目录。
    l_abortedFiles=("tests" "NOTES.txt" "ingress.yaml" "_helpers.tpl" \
      "deployment.yaml" "hpa.yaml" "service.yaml" "serviceAccount.yaml")
    # shellcheck disable=SC2068
    for l_file in ${l_abortedFiles[@]};do
      if [[ "${l_file}" =~ ^.*\..*$ ]];then
        if [ -f "${l_chartPath}/templates/${l_file}" ];then
          rm -f "${l_chartPath}/templates/${l_file}"
        else
          warn "helm打包目录(${l_chartPath})中不存在需要删除的${l_file}文件"
        fi
      else
        if [ -d "${l_chartPath}/templates/${l_file}" ];then
          rm -rf "${l_chartPath}/templates/${l_file}"
        else
          warn "helm打包目录(${l_chartPath})中不存在需要删除的${l_file}子目录"
        fi
      fi
    done
  else
    l_chartPath="${gDefaultRetVal}"

    #检查自定义helm打包目录的有效性
    l_mustExistFiles=("Chart.yaml" "values.yaml")
    # shellcheck disable=SC2068
    for l_file in ${l_mustExistFiles[@]};do
      if [ ! -f "${l_chartPath}/${l_file}" ];then
        error "自定义的helm打包目录(${l_chartPath})中不存在${l_file}文件"
      fi
    done

    l_chartYaml="${l_chartPath}/Chart.yaml"

    readParam "${l_chartYaml}" "name"
    if [ "${gDefaultRetVal}" != "${gCurrentChartName}" ];then
      error "自定义的helm打包目录中Chart.yaml文件name参数值不等于package.yaml文件中的name参数值"
    fi

    readParam "${l_chartYaml}" "version"
    if [ "${gDefaultRetVal}" != "${gCurrentChartVersion}" ];then
      error "自定义的helm打包目录中Chart.yaml文件version参数值不等于package.yaml文件中的version参数值"
    fi

  fi

  #返回当前实际的Chart镜像构建目录。
  gDefaultRetVal="${l_chartPath}"
}

function createChartImage_ex() {
  export gCustomizedHelm
  export gHelmBuildOutDir
  export gCurrentStageResult

  local l_chartPath=$1

  # shellcheck disable=SC2164
  cd "${l_chartPath}"

  if [ "${gCustomizedHelm}" == "false" ];then
    #编辑自动生成的Chart.yaml文件
    invokeExtendPointFunc "onModifyingChartYaml" "编辑自动生成的Chart.yaml文件..." "${l_chartPath}"
    #编辑自动生成的values.yaml文件
    invokeExtendPointFunc "onModifyingValuesYaml" "编辑自动生成的values.yaml文件..." "${l_chartPath}"
    #设置要发送的通知消息。
    gCurrentStageResult="INFO|成功打包项目${l_chartPath##*/}的chart镜像"
  fi
}

function onAfterCreatingChartImage_ex() {
  export gDefaultRetVal
  export gHelmBuildOutDir
  export gCurrentChartName
  export gCurrentChartVersion
  export gChartRepoInstanceName

  local l_chartTgzOutDir
  local l_errorFlag

  #获得输出目录
  l_chartTgzOutDir="${gHelmBuildOutDir}/${gCurrentChartName//\//-}-${gCurrentChartVersion}/chart"
  if [ -d "${l_chartTgzOutDir}" ];then
    #删除已经存在的目标目录
    rm -rf "${l_chartTgzOutDir}:?"
  fi
  #创建输出目录
  mkdir -p "${l_chartTgzOutDir}"

  #调用helm package执行前扩展。
  invokeExtendPointFunc "onBeforeHelmPackage" "HelmPackage执行前扩展" "${l_chartTgzOutDir}" "${gCurrentChartName}" "${gCurrentChartVersion}"

  #执行helm的打包命令
  l_errorFlag=$(helm package . -d "${l_chartTgzOutDir}" 2>&1 | grep -oP "^.*(Error|failed).*$")
  if [ "${l_errorFlag}" ];then
    error "执行命令(helm package . -d ${l_chartTgzOutDir})失败: ${l_errorFlag}"
  fi

  #测试chart镜像是否正确。
  l_errorFlag=$(helm template test "${l_chartTgzOutDir}/${gCurrentChartName//\//-}-${gCurrentChartVersion}.tgz" -n test.com 2>&1 | grep "^.*(Error|failed).*$")
  if [ "${l_errorFlag}" ];then
    error "chart镜像(${gCurrentChartName//\//-}-${gCurrentChartVersion}.tgz)正确性检测未通过: ${l_errorFlag}"
  else
    info "chart镜像(${gCurrentChartName//\//-}-${gCurrentChartVersion}.tgz)正确性检测已通过"
  fi

  if [ "${gChartRepoInstanceName}" ];then
    #将生成的Chart镜像推送到chart仓库中。不同的仓库类型chart镜像推送方式是不同的。
    invokeExtendPointFunc "helmPushChartImage" "Chart镜像推送扩展" "${l_chartTgzOutDir}/${gCurrentChartName}-${gCurrentChartVersion}.tgz"
  fi
}

function onModifyingChartYaml_ex(){
  export gCustomizedHelm
  export gCurrentChartName
  export gCurrentChartVersion
  export gCurrentAppVersion
  export gCurrentAppDescription

  local l_chartPath=$1
  local l_chartYaml
  local l_saveBackStatus

  disableSaveBackImmediately
  l_saveBackStatus="${gDefaultRetVal}"

  l_chartYaml="${l_chartPath}/Chart.yaml"
  updateParam "${l_chartYaml}" "name" "${gCurrentChartName}"
  updateParam "${l_chartYaml}" "version" "${gCurrentChartVersion}"
  updateParam "${l_chartYaml}" "appVersion" "${gCurrentAppVersion}"
  if [ "${gCurrentAppDescription}" ];then
    updateParam "${l_chartYaml}" "description" "${gCurrentAppDescription}"
  fi

  #恢复gSaveBackImmediately的值。
  enableSaveBackImmediately "${l_saveBackStatus}"

}

function onModifyingValuesYaml_ex(){
  export gDefaultRetVal
  export gDockerRepoName
  export gFileContentMap
  export gBuildPath

  local l_chartPath=$1

  local l_packageYaml
  local l_valuesYaml

  local l_index
  local l_deploymentItem
  local l_moduleName
  local l_pluginIndex

  local l_kind
  local l_generatorName
  local l_configPath

  l_packageYaml="${l_chartPath}/package.yaml"
  l_valuesYaml="${l_chartPath}/values.yaml"

  #覆盖l_valuesYaml文件内容。
  echo "#定义容器内的Docker镜像仓库地址，用于容器内镜像的拉取" > "${l_valuesYaml}"
  echo "image:" >> "${l_valuesYaml}"
  #在values.yaml文件中定义image.registry参数
  insertParam "${l_valuesYaml}" "image.registry" "${gDockerRepoName}"
  #在values.yaml文件中定义gatewayRoute.host参数
  insertParam "${l_valuesYaml}" "gatewayRoute.host" ""

  #将l_packageYaml文件中的params参数配置节添加到values.yaml文件中。
  #并将l_packageYaml文件中configMaps[?].files参数中所有文件中配置的变量(”{{ .Values.* }}“)写入values.yaml的params配置节中。
  invokeExtendPointFunc "addParamsToValuesYaml" "为values.yaml文件添加params配置节扩展" "${l_packageYaml}" "params" "${l_valuesYaml}"

  #向l_valuesYaml文件中插入refExternalCharts的值
  readParam "${l_packageYaml}" "refExternalCharts"
  insertParam "${l_valuesYaml}" "refExternalCharts" "${gDefaultRetVal}"

  ((l_index = 0))
  while true;do
    readParam "${l_packageYaml}" "deployments[${l_index}]"
    [[ "${gDefaultRetVal}" == "null" ]] && break

    if [ ! "${gDefaultRetVal}" ];then
      ((l_index = l_index + 1))
      return
    fi

    l_deploymentItem="${gDefaultRetVal}"
    l_moduleName="deployment${l_index}"

    #将读取的l_deploymentItem插入到l_valuesYaml文件中。
    insertParam "${l_valuesYaml}" "${l_moduleName}" "${l_deploymentItem}"

    invokeExtendPointFunc "onBeforeGeneratingExternalContainer" "处理引入外部Chart镜像中容器前扩展" "ExternalContainer" "default" \
    "${l_valuesYaml}" "${l_index}" "${l_moduleName}.refExternalContainers"

    #先处理引用的外部容器，这会改变l_valuesYaml文件中deployment${l_index}项中的内容。
    #直接调用资源生成器。
    invokeResourceGenerator "ExternalContainer" "default" "${l_valuesYaml}" "${l_index}" \
      "${l_moduleName}.refExternalContainers"

    invokeExtendPointFunc "onAfterGeneratingExternalContainer" "处理引入外部Chart镜像中容器后扩展" "ExternalContainer" "default" \
      "${l_valuesYaml}" "${l_index}" "${l_moduleName}.refExternalContainers"

    ((l_pluginIndex = 0))
    while true;do
      readParam "${l_valuesYaml}" "${l_moduleName}.resourcePlugins[${l_pluginIndex}].name"
      [[ "${gDefaultRetVal}" == "null" ]] && break

      if [ ! "${gDefaultRetVal}" ];then
        ((l_pluginIndex = l_pluginIndex + 1))
        continue
      fi

      l_kind="${gDefaultRetVal}"

      readParam "${l_valuesYaml}" "${l_moduleName}.resourcePlugins[${l_pluginIndex}].enable"
      if [ "${gDefaultRetVal}" == "false" ];then
        ((l_pluginIndex = l_pluginIndex + 1))
        continue
      fi

      #获取插件的资源文件生成器名称
      l_generatorName="default"
      readParam "${l_valuesYaml}" "${l_moduleName}.resourcePlugins[${l_pluginIndex}].generatorName"
      [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]] && l_generatorName="${gDefaultRetVal}"

      #获取插件配置数据
      l_configPath=""
      readParam "${l_valuesYaml}" "${l_moduleName}.resourcePlugins[${l_pluginIndex}].configPath"
      [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]] && l_configPath="${gDefaultRetVal}"

      #调用扩展点方法，为三级管理层人员提供干预机会。
      invokeExtendPointFunc "generateResourceByPlugin" "通过插件生成${l_kind}类型的资源配置文件" "${l_kind}" \
        "${l_generatorName}" "${l_valuesYaml}" "${l_index}" "${l_configPath}"

      ((l_pluginIndex = l_pluginIndex + 1))
    done

    #最后删除l_valuesYaml文件中deployment${l_index}.resourcePlugins配置。
    deleteParam "${l_valuesYaml}" "${l_moduleName}.resourcePlugins"

    ((l_index = l_index + 1))
  done

  invokeExtendPointFunc "onBeforeGeneratingExternalChart" "处理引入的外部Chart镜像前扩展" "ExternalChart" "default" \
    "${l_valuesYaml}" "${l_index}" "refExternalCharts"

  #最后处理引用的外部服务，这会为l_valuesYaml文件中增加deployment${l_index}配置项。
  #直接调用资源生成器。
  invokeResourceGenerator "ExternalChart" "default" "${l_valuesYaml}" "${l_index}" "refExternalCharts"

  invokeExtendPointFunc "onAfterGeneratingExternalChart" "处理引入的外部Chart镜像后扩展" "ExternalChart" "default" \
    "${l_valuesYaml}" "${l_index}" "refExternalCharts"

  #删除已经无用的l_packageYaml文件。
  rm -f "${l_packageYaml}"
}

function generateResourceByPlugin_ex() {
  #直接调用资源生成器。
  invokeResourceGenerator "${@}"
}

function installHelm_ex() {
  export gBuildScriptRootDir
  local l_systemType=$1
  local l_archType=$2
  #调用扩展链，不同系统下安装的方法不同。
  invokeExtendChain "onInstallHelmTool" "${gBuildScriptRootDir}" "${l_systemType}" "${l_archType}"
}

function addHelmRepo_ex(){
  export gChartRepoType
  export gChartRepoInstanceName
  export gChartRepoName
  export gChartRepoAccount
  export gChartRepoPassword
  #调用helm-helper.sh文件中的方法。
  addHelmRepo "${gChartRepoType}" "${gChartRepoInstanceName}" "${gChartRepoName}" "${gChartRepoAccount}" "${gChartRepoPassword}"
}

function onBeforeHelmPackage_ex() {
  export gBuildPath
  export gCustomizedHelm
  export gProjectChartTemplatesDir

  local l_yamlList
  local l_ymalFile

  if [[ "${gCustomizedHelm}" == "false" && -d "${gProjectChartTemplatesDir}" ]];then
    info "尝试将主模块目录下chart-templates子目录中的*.yaml文件复制到./templates目录中 ..."
    #为项目自定义部分特殊配置提供了扩展。
    l_yamlList=$(find "${gProjectChartTemplatesDir}" -type f -name "*.yaml")
    if [ "${l_yamlList}" ];then
      # shellcheck disable=SC2068
      for l_ymalFile in ${l_yamlList[@]};do
        info "将项目配置的额外的${l_ymalFile##*/}文件复制到chart镜像的templates目录中"
        cp "${l_ymalFile}" "./templates/"
      done
    fi
  fi
}

function helmPushChartImage_ex() {
  export gChartRepoType
  export gChartRepoName
  export gChartRepoInstanceName
  export gChartRepoAccount
  export gChartRepoPassword

  local l_chartFile=$1
  #调用helm-helper.sh文件中的方法。
  pushChartImage "${l_chartFile}" "${gChartRepoType}" "${gChartRepoInstanceName}" "${gChartRepoName}" \
    "${gChartRepoAccount}" "${gChartRepoPassword}"
}

function addParamsToValuesYaml_ex(){
  export gDefaultRetVal

  local l_packageYaml=$1
  local l_paramPath=$2
  local l_valuesYaml=$3

  local l_itemCount
  local l_i
  local l_j
  local l_k
  local l_type
  local l_key
  local l_value

  readParam "${l_packageYaml}" "${l_paramPath}"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    #向values.yaml文件中追加params配置节。
    insertParam "${l_valuesYaml}" "${l_paramPath}" "${gDefaultRetVal}"
    #读取params.configurable配置节中的参数和默认值，并写入params配置节下。
    #最后删除params.configurable配置节
    ((l_i = 0))
    while true; do
      readParam "${l_valuesYaml}" "${l_paramPath}.configurable[${l_i}].items"
      [[ "${gDefaultRetVal}" == "null" ]] && break
      [[  ! "${gDefaultRetVal}" ]] && \
        error "${l_valuesYaml##*/}文件中${l_paramPath}.configurable[${l_i}].items配置节异常：值为空"

      ((l_j = 0))
      while true; do
        readParam "${l_valuesYaml}" "${l_paramPath}.configurable[${l_i}].items[${l_j}].type"
        [[ "${gDefaultRetVal}" == "null" ]] && break
        [[ ! "${gDefaultRetVal}" ]] && \
          error "${l_valuesYaml##*/}文件中${l_paramPath}.configurable[${l_i}].items[${l_j}].type参数异常：值为空"

        l_type="${gDefaultRetVal}"

        readParam "${l_valuesYaml}" "${l_paramPath}.configurable[${l_i}].items[${l_j}].key"
        [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && \
          error "${l_valuesYaml##*/}文件中${l_paramPath}.configurable[${l_i}].items[${l_j}].key参数异常：缺失或值为空"

        l_key="${gDefaultRetVal}"

        if [ "${l_type}" == "group" ];then
          ((l_k = 0))
          while true; do
            readParam "${l_valuesYaml}" "${l_paramPath}.configurable[${l_i}].items[${l_j}].items[${l_k}].key"
            [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && \
              error "${l_valuesYaml##*/}文件中${l_paramPath}.configurable[${l_i}].items[${l_j}].items[${l_k}].key参数异常：缺失或值为空"

            l_key="${l_key}[${l_k}].${gDefaultRetVal}"

            readParam "${l_valuesYaml}" "${l_paramPath}.configurable[${l_i}].items[${l_j}].items[${l_k}].value"
            [[ "${gDefaultRetVal}" == "null" ]] && \
              error "${l_valuesYaml##*/}文件中缺失了${l_paramPath}.configurable[${l_i}].items[${l_j}].items[${l_k}].value参数"

            l_value="${gDefaultRetVal}"
            insertParam "${l_valuesYaml}" "params.${l_key//\"/}" "${l_value}"
            [[ "${gDefaultRetVal}" =~ ^(\-1) ]] && \
              error "向${l_valuesYaml##*/}文件中插入params.${l_key//\"/}参数失败"
            info "向${l_valuesYaml##*/}文件中插入params.${l_key//\"/}参数成功，值为：${l_value}"

            ((l_k = l_k + 1))
          done
        else
          readParam "${l_valuesYaml}" "${l_paramPath}.configurable[${l_i}].items[${l_j}].value"
          [[ "${gDefaultRetVal}" == "null" ]] && \
            error "${l_valuesYaml##*/}文件中缺失了${l_paramPath}.configurable[${l_i}].items[${l_j}].value参数"

          l_value="${gDefaultRetVal}"
          insertParam "${l_valuesYaml}" "params.${l_key//\"/}" "${l_value}"
          [[ "${gDefaultRetVal}" =~ ^(\-1) ]] && \
              error "向${l_valuesYaml##*/}文件中插入params.${l_key//\"/}参数失败"
          info "向${l_valuesYaml##*/}文件中插入params.${l_key//\"/}参数成功，值为：${l_value}"
        fi

        ((l_j = l_j + 1))
      done

      ((l_i = l_i + 1))
    done
    #删除params.configurable配置节
    deleteParam "${l_valuesYaml}" "${l_paramPath}.configurable"
    if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
      warn "删除${l_valuesYaml##*/}文件中${l_paramPath}.configurable参数失败：参数不存在"
    else
      info "删除${l_valuesYaml##*/}文件中${l_paramPath}.configurable参数成功"
    fi
  fi

  #将l_paramNameList中的params参数配置到values.yaml文件的params配置节中。
  invokeExtendPointFunc "combineParamsToValuesYaml" "向values.yaml文件中params配置追加业务参数扩展" "${l_packageYaml}" "${l_valuesYaml}"

}

function combineParamsToValuesYaml_ex() {
  export gDefaultRetVal
  export gBuildPath

  local l_packageYaml=$1
  local l_valuesYaml=$2

  declare -A _paramDeployValueMap

  local l_chartName
  local l_loopIndex
  local l_layerLevel

  local l_configMapFiles
  local l_configFile
  local l_paramList

  local l_lines
  local l_lineCount
  local l_i
  local l_result
  local l_info

  readParam "${l_packageYaml}" "name"
  l_chartName="${gDefaultRetVal}"

  #读取参数部署时设置的值。
  getDeployValueOfParam "${l_chartName}"

  l_loopIndex=(0 0)
  ((l_layerLevel = 2))
  while true;do
    readParam "${l_packageYaml}" "deployments[${l_loopIndex[0]}].configMaps[${l_loopIndex[1]}].files"
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
      info "正在检测${l_configFile##*/}文件中的变量..."
      [[ "${l_configFile}" =~ ^(\.) ]] && l_configFile="${gBuildPath}/${l_configFile#*/}"

      # shellcheck disable=SC2002
      l_paramList=$(cat "${l_configFile}" | grep -oP "\{\{[ ]+\.Values(\.[a-zA-Z0-9_\-]+)+[ ]*(\|[ ]*default.*)*[ ]+\}\}" | sort | uniq -c)
      if [ "${l_paramList}" ];then

        stringToArray "${l_paramList}" "l_lines"
        l_lineCount="${#l_lines[@]}"
        for ((l_i=0; l_i < l_lineCount; l_i++ ));do
          l_paramName=$(echo -e "${l_lines[${l_i}]}" | grep -oP ".Values(\.[a-zA-Z0-9_\-]+)+( |\|)")
          [[ "${l_paramName}" =~ ^(.*)\|$ ]] && l_paramName="${l_paramName%|*}"
          l_paramName=$(echo -e "${l_paramName}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
          l_paramName="${l_paramName/\.Values\./}"

          # shellcheck disable=SC2145
          l_result=$(echo "${!_paramDeployValueMap[@]} " | grep -oP "${l_paramName} ")
          if [ "${l_result}" ];then
            #读取部署时设置的值。
            l_paramValue="${_paramDeployValueMap[${l_paramName}]}"
          else
            #读取配置文件中定义的缺省值。
            l_paramValue=""
            if [[ "${l_lines[${l_i}]}" =~ ^(.*)(\|[ ]*default)(.*) ]];then
              l_paramValue="${l_lines[${l_i}]#*|}"
              l_paramValue="${l_paramValue%%\}*}"
              l_paramValue="${l_paramValue// default/}"
              l_paramValue=$(echo -e "${l_paramValue}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
              if [[ "${l_paramValue}" =~ ^(\") ]];then
                #去掉头尾引号
                l_paramValue="${l_paramValue/\"/}"
                l_paramValue="${l_paramValue%\"*}"
              fi
            fi
          fi

          #向l_valuesYaml文件中插入参数。
          insertParam "${l_valuesYaml}" "${l_paramName}" "${l_paramValue}"
          l_info="向${l_valuesYaml##*/}文件中插入${l_paramName}参数"
          if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
            [[ "${l_paramValue}" ]] && l_info="${l_info}失败：${l_paramValue}"
            [[ ! "${l_paramValue}" ]] && l_info="${l_info}失败：(值为空)"
            error "${l_info}"
          else
            [[ "${l_paramValue}" ]] && l_info="${l_info}成功：${l_paramValue}"
            [[ ! "${l_paramValue}" ]] && l_info="${l_info}成功：(值为空)"
            info "${l_info}"
          fi

        done
      fi
    done

    ((l_loopIndex[1] = l_loopIndex[1] + 1))
  done

}

#chart阶段单镜像模式下（默认是双镜像模式）对ci-cd.yaml文件的调整
function handleBuildingSingleImageForChart_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gBuildType
  export gServiceName

  local l_saveBackStatus
  local l_baseImage
  local l_baseVersion
  local l_i
  local l_j
  local l_k
  local l_array
  local l_paramArray
  local l_paramItem
  local l_paramName
  local l_paramValue

  #关闭yaml-helper.sh文件中的gImmediatelySaveBack标志。
  disableSaveBackImmediately
  l_saveBackStatus="${gDefaultRetVal}"

  #读取业务镜像的版本号。
  readParam "${gCiCdYamlFile}" "globalParams.baseImage"
  l_baseImage="${gDefaultRetVal//-base/}"

  #读取业务镜像的版本号。
  readParam "${gCiCdYamlFile}" "globalParams.businessVersion"
  l_baseVersion="${gDefaultRetVal}"

  ((l_i = 0))
  while true; do
    readParam "${gCiCdYamlFile}" "chart[${l_i}].name"
    [[ "${gDefaultRetVal}" == "null" ]] && break
    if [ "${gDefaultRetVal}" == "${gServiceName}" ];then
      ((l_j = 0))
      while true; do
        readParam "${gCiCdYamlFile}" "chart[${l_i}].deployments[${l_j}].name"
        [[ "${gDefaultRetVal}" == "null" ]] && break
        if [ "${gDefaultRetVal}" == "${gServiceName}" ];then

          #删除volumes中的${gServiceName}-workdir目录挂载配置
          getListIndexByPropertyName "${gCiCdYamlFile}" "chart[${l_i}].deployments[${l_j}].volumes" "name" "${gServiceName}-workdir"
          if [ "${gDefaultRetVal}" -ge 0 ];then
            l_k="${gDefaultRetVal}"
            l_param="chart[${l_i}].deployments[${l_j}].volumes[${l_k}]"
            deleteParam "${gCiCdYamlFile}" "${l_param}"
            if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
              error "删除${gCiCdYamlFile##*/}文件中${l_param}配置项失败"
            else
              info "成功删除${gCiCdYamlFile##*/}文件中${l_param}配置项"
            fi
          fi

          #删除initContainers中的业务镜像配置。
          getListIndexByPropertyName "${gCiCdYamlFile}" "chart[${l_i}].deployments[${l_j}].initContainers" "name" "${gServiceName}-business"
          if [ "${gDefaultRetVal}" -ge 0 ];then
            l_param="chart[${l_i}].deployments[${l_j}].initContainers[${gDefaultRetVal}]"
            deleteParam "${gCiCdYamlFile}" "${l_param}"
            if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
              error "删除${gCiCdYamlFile##*/}文件中${l_param}配置项失败"
            else
              info "成功删除${gCiCdYamlFile##*/}文件中${l_param}配置项"
            fi
          fi

          #对containers中name为${gServiceName}-base的配置项进行修正。
          getListIndexByPropertyName "${gCiCdYamlFile}" "chart[${l_i}].deployments[${l_j}].containers" "name" "${gServiceName}-base"
          if [ "${gDefaultRetVal}" -ge 0 ];then
            l_k="${gDefaultRetVal}"
            l_param="chart[${l_i}].deployments[${l_j}].containers[${l_k}]"

            #对当前container中docker镜像相关的参数进行修正。
            l_paramArray=("name|${gServiceName}" "repository|${l_baseImage}" "tag|${l_baseVersion}")
            # shellcheck disable=SC2068
            for l_paramItem in ${l_paramArray[@]};do
              l_paramName="${l_paramItem%%|*}"
              l_paramValue="${l_paramItem#*|}"
              l_paramName="${l_param}.${l_paramName}"
              updateParam "${gCiCdYamlFile}" "${l_paramName}" "${l_paramValue}"
              if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
                error "更新${gCiCdYamlFile##*/}文件中${l_paramName}参数失败"
              else
                info "更新${gCiCdYamlFile##*/}文件中${l_paramName}参数值为：${l_paramValue}"
              fi
            done

            #删除当前container中的name属性为${gServiceName}-workdir的volumeMounts列表项。
            getListIndexByPropertyName "${gCiCdYamlFile}" "${l_param}.volumeMounts" "name" "${gServiceName}-workdir"
            if [ "${gDefaultRetVal}" -ge 0 ];then
              l_k="${gDefaultRetVal}"
              deleteParam "${gCiCdYamlFile}" "${l_param}.volumeMounts[${gDefaultRetVal}]"
              if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
                error "删除${gCiCdYamlFile##*/}文件中${l_param}.volumeMounts[${l_k}]配置项失败"
              else
                info "成功删除${gCiCdYamlFile##*/}文件中${l_param}.volumeMounts[${l_k}]配置项"
              fi
            fi
          fi

        fi
        ((l_j = l_j + 1))
      done
    fi
    ((l_i = l_i + 1))
  done

  #恢复gSaveBackImmediately的值。
  enableSaveBackImmediately "${l_saveBackStatus}"
}

#**********************私有方法-开始***************************#

function _processContainerPorts(){
  export gDefaultRetVal

  local l_cicdYaml=$1

  local l_loopIndex
  local l_layerLevel
  local l_paramPath

  #子方法中回使用。
  declare -A _portAndServiceNameMap

  l_loopIndex=(0 0 0)
  ((l_layerLevel = 3))
  while true;do
    l_paramPath="chart[${l_loopIndex[0]}].deployments[${l_loopIndex[1]}].containers[${l_loopIndex[2]}]"
    readParam "${l_cicdYaml}" "${l_paramPath}.name"
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
    #恢复层级数。
    ((l_layerLevel = 3))

    info "检查并生成项目Service配置信息..."
    _createServiceConfig "${l_cicdYaml}" "${l_paramPath}" "${gDefaultRetVal}"

    info "检查并处理项目开放了多个容器端口的情况..."
    _processMultiplePorts "${l_cicdYaml}" "${l_paramPath}"

    info "更新路由配置信息中后端服务的名称"
    _updateServiceNameOfBackendInGatewayRoute "${l_cicdYaml}" "chart[${l_loopIndex[0]}].deployments[${l_loopIndex[1]}]"

    ((l_loopIndex[2] = l_loopIndex[2] + 1))
  done
}

function _createServiceConfig() {
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gTempFileDir
  export gFileDataBlockMap

  export _portAndServiceNameMap

  local l_cicdYaml=$1
  local l_paramPath=$2
  local l_containerName=$3

  local l_configTemplate
  local l_tmpFile
  local l_version

  local l_portName
  local l_servicePort
  local l_containerPort
  local l_nodePort
  local l_clusterIPIndex
  local l_nodePortIndex
  local l_tmpIndex
  local l_subPath

  local l_nodePortList
  local l_servicePortList
  local l_containerPortList
  local l_nodePortCount
  local l_servicePortCount
  local l_containerPortCount
  local l_i
  local l_j

  local l_serviceResourceName

  readParam "${l_cicdYaml}" "${l_paramPath}.service"
  if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then

    #将现有配置写入临时文件中。
    # shellcheck disable=SC2088
    l_tmpFile="${gTempFileDir}/${RANDOM}.tmp"
    registerTempFile "${l_tmpFile}"
    echo "service:" > "${l_tmpFile}"

    readParam "${l_cicdYaml}" "${l_paramPath}.tag"
    l_version="${gDefaultRetVal}"

    disableSaveBackImmediately
    l_saveBackStatus="${gDefaultRetVal}"

    ((l_clusterIPIndex = -1))
    ((l_nodePortIndex = -1))
    ((l_i = 0))
    while true;do
      readParam "${l_cicdYaml}" "${l_paramPath}.ports[${l_i}].servicePort"
      [[ "${gDefaultRetVal}" == "null" ]] && break

      if [ "${gDefaultRetVal}" ];then
        l_servicePort="${gDefaultRetVal}"
        readParam "${l_cicdYaml}" "${l_paramPath}.ports[${l_i}].containerPort"
        l_containerPort="${gDefaultRetVal}"
        readParam "${l_cicdYaml}" "${l_paramPath}.ports[${l_i}].nodePort"
        l_nodePort="${gDefaultRetVal}"
        readParam "${l_cicdYaml}" "${l_paramPath}.ports[${l_i}].name"
        l_portName="${gDefaultRetVal}"

        ((l_nodePortCount = 0))
        l_nodePortList=()
        if [[ "${l_nodePort}" && "${l_nodePort}" != "null" ]];then
          # shellcheck disable=SC2206
          l_nodePortList=(${l_nodePort//,/ })
          l_nodePortCount="${#l_nodePortList[@]}"
        fi

        ((l_servicePortCount = 0))
        l_servicePortList=()
        if [[ "${l_servicePort}" && "${l_servicePort}" != "null" ]];then
          # shellcheck disable=SC2206
          l_servicePortList=(${l_servicePort//,/ })
          l_servicePortCount="${#l_servicePortList[@]}"
        fi

        ((l_containerPortCount = 0))
        l_containerPortList=()
        if [[ "${l_containerPort}" && "${l_containerPort}" != "null" ]];then
          # shellcheck disable=SC2206
          l_containerPortList=(${l_containerPort//,/ })
          l_containerPortCount="${#l_containerPortList[@]}"
        fi

        for ((l_j=0; l_j < l_containerPortCount; l_j++ ));do
          l_subPath=""
          if [[ "${l_j}" -lt "${l_nodePortCount}" && "${l_nodePortList[${l_j}]}" -gt 0 ]];then
            l_subPath="nodePort"
            [[ "${l_servicePortList[${l_j}]}" -le 0 ]] && error "${l_paramPath}.ports[${l_i}].servicePort参数中第${l_j}个端口号必须大于0"
            ((l_tmpIndex = l_nodePortIndex))
          elif [[ "${l_j}" -lt "${l_servicePortCount}" && "${l_servicePortList[${l_j}]}" -gt 0 ]];then
            l_subPath="clusterIP"
            ((l_tmpIndex = l_clusterIPIndex))
          fi

          if [ "${l_subPath}" ];then
            info "生成${l_subPath^}类型的Service(服务端口:${l_servicePortList[${l_j}]})配置..."
            [[ "${l_containerPortList[${l_j}]}" -le 0 ]] && error "${l_paramPath}.ports[${l_i}].containerPort参数中第${l_j}个端口号必须大于0"

            l_configTemplate=""
            if [ "${l_tmpIndex}" -lt 0 ];then
              l_configTemplate="${gBuildScriptRootDir}/templates/chart/${l_subPath}-service-config-template.yaml"
            fi

            if [[ "${l_subPath}" == "nodePort" ]];then
              ((l_nodePortIndex = l_nodePortIndex + 1))
              ((l_tmpIndex = l_nodePortIndex))
            else
              ((l_clusterIPIndex = l_clusterIPIndex + 1))
              ((l_tmpIndex = l_clusterIPIndex))
            fi

            if [ "${l_configTemplate}" ];then
              readParam "${l_configTemplate}" "${l_subPath}"
              if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
                error "读取模板文件内容失败：${l_subPath}-service-config-template.yaml"
              else
                info "成功读取模板文件内容：${l_subPath}-service-config-template.yaml"
              fi
              insertParam "${l_tmpFile}" "service.${l_subPath}" "${gDefaultRetVal}"
              updateParam "${l_tmpFile}" "service.${l_subPath}.name" "${l_containerName}"
              updateParam "${l_tmpFile}" "service.${l_subPath}.version" "${l_version}"
            else
              #读取Port项配置模板
              readParam "${l_tmpFile}" "service.${l_subPath}.ports[0]"
              #插入新的Port配置项
              insertParam "${l_tmpFile}" "service.${l_subPath}.ports[${l_tmpIndex}]" "${gDefaultRetVal}"
            fi
            insertParam "${l_tmpFile}" "service.${l_subPath}.ports[${l_tmpIndex}].name" "${l_portName}-${l_servicePortList[${l_j}]}"
            insertParam "${l_tmpFile}" "service.${l_subPath}.ports[${l_tmpIndex}].port" "${l_servicePortList[${l_j}]}"
            insertParam "${l_tmpFile}" "service.${l_subPath}.ports[${l_tmpIndex}].targetPort" "${l_containerPortList[${l_j}]}"
            l_serviceResourceName="${l_containerName}-clusterip"
            if [[ "${l_subPath}" == "nodePort" ]];then
              insertParam "${l_tmpFile}" "service.${l_subPath}.ports[${l_tmpIndex}].nodePort" "${l_nodePortList[${l_j}]}"
              l_serviceResourceName="${l_containerName}-nodeport"
            fi
            #记录端口对应的Service资源名称。
            _portAndServiceNameMap["${l_containerPortList[${l_j}]}"]="${l_serviceResourceName}"
          fi
        done
        #删除已处理过的servicePort和nodePort信息。
        deleteParam "${l_cicdYaml}" "${l_paramPath}.ports[${l_i}].servicePort"
        if [[ "${l_subPath}" == "nodePort" ]];then
          deleteParam "${l_cicdYaml}" "${l_paramPath}.ports[${l_i}].nodePort"
        fi
      fi
      ((l_i = l_i + 1))
    done

    #恢复gSaveBackImmediately的值。
    enableSaveBackImmediately "${l_saveBackStatus}"

    #从临时文件中读出service配置信息
    readParam "${l_tmpFile}" "service"
    #清除临时文件
    unregisterTempFile "${l_tmpFile}"

    #回写ports参数
    insertParam "${l_cicdYaml}" "${l_paramPath}.service" "${gDefaultRetVal}"
    if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
      error "多Service配置错误：回写${l_paramPath}.service参数失败"
    fi

  fi

}

#处理指定路径的多端口参数。
function _processMultiplePorts() {
  export gDefaultRetVal
  export gTempFileDir
  export gFileContentMap

  local l_cicdYaml=$1
  local l_paramPath=$2

  local l_templateContent
  local l_tmpFile

  local l_i
  local l_containerPorts
  local l_containerPortCount
  local l_containerPort

  local l_portName
  local l_j
  local l_index

  local l_saveBackStatus

  #读取ports配置节的内容，并写入临时文件中。
  readParam "${l_cicdYaml}" "${l_paramPath}.ports"
  if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
    warn "${l_cicdYaml##*/}文件中${l_paramPath}.ports配置节是空的"
    return
  fi

  #缓存配置模板。
  readParam "${l_cicdYaml}" "${l_paramPath}.ports[0]"
  l_templateContent="${gDefaultRetVal}"

  #将现有配置写入临时文件中。
  # shellcheck disable=SC2088
  l_tmpFile="${gTempFileDir}/${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"
  echo "ports:" > "${l_tmpFile}"

  #读取端口名称。
  readParam "${l_cicdYaml}" "${l_paramPath}.ports[0].name"
  l_portName="${gDefaultRetVal}"
  if [[ "${l_portName}" == "null" ]];then
    error "读取ports[0].name参数失败"
  fi

  disableSaveBackImmediately
  l_saveBackStatus="${gDefaultRetVal}"

  ((l_i = 0))
  ((l_index = -1))
  while true; do
    #读取containerPort数组信息
    readParam "${l_cicdYaml}" "${l_paramPath}.ports[${l_i}].containerPort"
    [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && break

    #字符串转数组。
    # shellcheck disable=SC2206
    l_containerPorts=(${gDefaultRetVal//,/ })
    l_containerPortCount="${#l_containerPorts[@]}"

    if [ "${l_containerPortCount}" -eq 1 ];then
      info "正在添加开放${l_containerPorts[0]}端口的配置..."
      readParam "${l_cicdYaml}" "${l_paramPath}.ports[${l_i}]"
      #插入端口配置节。
      ((l_index = l_index + 1))
      insertParam "${l_tmpFile}" "ports[${l_index}]" "${gDefaultRetVal}"
      #清除servicePort和nodePort属性
      deleteParam "${l_tmpFile}" "ports[${l_index}].servicePort"
      deleteParam "${l_tmpFile}" "ports[${l_index}].nodePort"
    else
      #循环展开端口配置。
      for (( l_j=0; l_j < l_containerPortCount; l_j++ )); do
        l_containerPort=$(echo "${l_containerPorts[${l_j}]}" | grep -oP "^([ ]*)([0-9]+)([ ]*)$")
        if [ ! "${l_containerPort}" ];then
          error "多端口配置错误：containerPort端口必须是整数，端口间以逗号隔开"
        fi

        info "正在添加开放${l_containerPort}端口的配置..."

        ((l_index = l_index + 1))
        #插入端口配置节。
        insertParam "${l_tmpFile}" "ports[${l_index}]" "${l_templateContent}"
        if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
          error "多端口配置错误：向临时文件中插入ports[${l_index}]失败"
        fi

        #更新端口名称
        updateParam "${l_tmpFile}" "ports[${l_index}].name" "${l_portName}-${l_containerPort}"
        if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
          error "多端口配置错误：更新ports[${l_index}].name参数失败"
        fi

        #更新容器端口
        updateParam "${l_tmpFile}" "ports[${l_index}].containerPort" "${l_containerPort}"
        if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
          error "多端口配置错误：更新ports[${l_index}].containerPort参数失败"
        fi
        #清除servicePort和nodePort属性
        deleteParam "${l_tmpFile}" "ports[${l_index}].servicePort"
        deleteParam "${l_tmpFile}" "ports[${l_index}].nodePort"
      done
    fi
    #调整数组下标，跳过新增加的数组项。
    ((l_i = l_i + 1))
  done

  #恢复gSaveBackImmediately的值。
  enableSaveBackImmediately "${l_saveBackStatus}"

  #从临时文件中读出ports配置信息
  readParam "${l_tmpFile}" "ports"
  unregisterTempFile "${l_tmpFile}"

  #回写ports参数
  updateParam "${l_cicdYaml}" "${l_paramPath}.ports" "${gDefaultRetVal}"
  if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
    error "多端口配置错误：回写ports参数失败"
  fi

}

function _updateServiceNameOfBackendInGatewayRoute() {
  export _portAndServiceNameMap

  local l_cicdYaml=$1
  local l_paramPath=$2

  local l_loopIndex
  local l_layerLevel

  local l_portList
  local l_configPaths
  local l_configPath
  local l_array
  local l_name

  # shellcheck disable=SC2124
  l_portList="${!_portAndServiceNameMap[@]}"

  l_configPaths=("ingressRoute.rules,paths" "apisixRoute.routes,backends")
  # shellcheck disable=SC2068
  for l_configPath in ${l_configPaths[@]};do
    # shellcheck disable=SC2206
    l_array=(${l_configPath//,/ })
    l_loopIndex=(0 0)
    ((l_layerLevel = 2))
    while true;do
      readParam "${l_cicdYaml}" "${l_paramPath}.${l_array[0]}[${l_loopIndex[0]}].${l_array[1]}[${l_loopIndex[1]}].servicePort"
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

      if [[ "${l_portList}" =~ ^(.*)${gDefaultRetVal}( |$) ]];then
        l_name="${_portAndServiceNameMap[${gDefaultRetVal}]}"
        info "更新${l_cicdYaml##*/}文件中${l_array[0]##.*}配置中${gDefaultRetVal}端口对应的后端服务的名称为${l_name}..." "-n"
        updateParam "${l_cicdYaml}" "${l_paramPath}.${l_array[0]}[${l_loopIndex[0]}].${l_array[1]}[${l_loopIndex[1]}].serviceName" "${l_name}"
        if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
          error "失败"
        else
          info "成功" "*"
        fi
      fi

      ((l_loopIndex[1] = l_loopIndex[1] + 1))
    done
  done
}

function _initialPackageYamlFile() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gChartBuildDir
  export gChartNames

  local l_content
  local l_listItems
  local l_itemCount
  local l_i
  local l_chartName
  local l_chartNames

  if [ "${gChartBuildDir}" ];then
    info "清空${gChartBuildDir##*/}目录"
    rm -rf "${gChartBuildDir:?}/*" || true
  fi

  l_chartNames=""
  #将ci-cd.yaml文件中的chart列表项拆分到对应的目录下，并命名为package.yaml。
  readParam "${gCiCdYamlFile}" "chart"
  l_content="${gDefaultRetVal}"
  l_listItems=$(echo "${l_content}" | grep -oP "^(- ).*$")
  l_itemCount=${#l_listItems[@]}
  for (( l_i=0; l_i < l_itemCount; l_i++ ));do
    readParam "${gCiCdYamlFile}" "chart[${l_i}].name"
    l_chartName="${gDefaultRetVal}"
    #创建Chart镜像构建目录
    mkdir -p "${gChartBuildDir}/${l_chartName}"
    #读取列表项的内容写入package.yaml文件中
    readParam "${gCiCdYamlFile}" "chart[${l_i}]"
    l_content="${gDefaultRetVal}"
    if [[ "${l_content}" && "${l_content}" != "null" ]];then
      echo -e "${l_content}" > "${gChartBuildDir}/${l_chartName}/package.yaml"
    else
      warn "读取${gCiCdYamlFile##*/}文件中chart[${l_i}]配置节失败"
    fi
    l_chartNames="${l_chartNames} ${l_chartName}"
  done

  gChartNames="${l_chartNames:1}"

}

#获取参数的部署值。
function getDeployValueOfParam() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export _paramDeployValueMap

  local l_chartName=$1
  local l_index
  local l_array
  local l_packageName

  ((l_index = -1))
  info "根据chart打包项的名称，获取该chart镜像对应的部署配置节的序号(用于后续读取参数的初始化值) ..." "-n"
  #根据l_chartName获取打包名。
  getListIndexByPropertyName "${gCiCdYamlFile}" "package" "chartName" "${l_chartName}"
  if [ "${gDefaultRetVal}" -ge 0 ];then
    # shellcheck disable=SC2206
    l_array=(${gDefaultRetVal})
    #获取打包名称
    readParam "${gCiCdYamlFile}" "package[${l_array[0]}].name"
    if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
      l_packageName="${gDefaultRetVal}"
      #根据l_packageName获取打包名。
      getListIndexByPropertyName "${gCiCdYamlFile}" "deploy" "packageName" "${l_packageName}"
      #获得l_chartName对应的部署配置项的序号，根据这个序号读取各个参数的默认配置值。
      # shellcheck disable=SC2206
      l_index="${gDefaultRetVal}"
    fi
  fi

  if [ "${l_index}" -lt 0 ];then
    warn "获取序号失败" "*"
    return
  fi

  info "成功获取序号：${l_index}" "*"
  info "获取服务在部署阶段配置的参数及其值..."
  ((l_i = 0))
  while true;do
    readParam "${gCiCdYamlFile}" "deploy[${l_index}].params[${l_i}]"
    [[ "${gDefaultRetVal}" == "null" ]] && break
    l_paramName=$(echo "${gDefaultRetVal}" | grep "^name:.*$")
    l_paramName="${l_paramName//name:/}"
    l_paramName=$(echo -e "${l_paramName}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    l_paramValue=$(echo "${gDefaultRetVal}" | grep "^value:.*$")
    l_paramValue="${l_paramValue//value:/}"
    l_paramValue=$(echo -e "${l_paramValue}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    l_paramName="${l_paramName/\.Values\./}"
    # shellcheck disable=SC2034
    _paramDeployValueMap["${l_paramName}"]="${l_paramValue}"
    if [ "${l_paramValue}" ];then
      info "加载参数默认值：${l_paramName}=>${l_paramValue}"
    else
      warn "加载参数默认值：${l_paramName}=> (值为空)"
    fi
    ((l_i = l_i + 1))
  done

}
#**********************私有方法-结束***************************#

#加载chart阶段脚本库文件
loadExtendScriptFileForLanguage "chart"

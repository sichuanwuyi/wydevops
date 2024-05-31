#!/usr/bin/env bash

function onBeforeInitialingGlobalParamsForChartStage_ex() {
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gHelmBuildDir
  export gBuildType
  export gCiCdYamlFile

  local l_content
  local l_systemType
  local l_archType

  #检查是否安装有helm工具。
  l_content=$(helm version | grep -oP "not found" )
  if [ "${l_content}" ];then
    #检查当前操作系统类型
    invokeExtendChain "onGetSystemArchInfo"
    # shellcheck disable=SC2015
    [[ "${gDefaultRetVal}" == "false" ]] && error "读取本地系统架构信息失败" || info "读取到当前系统架构为:${gDefaultRetVal}"
    #将生成的Chart镜像推送到gChartRepoName仓库中。
    invokeExtendPointFunc "installHelm" "在本地系统中安装helm工具" "${gDefaultRetVal%%/*}" "${gDefaultRetVal#*/}"
  fi

  #将生成的Chart镜像推送到gChartRepoName仓库中。
  invokeExtendPointFunc "addHelmRepo" "在本地系统中注册helm仓库"

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
    l_abortedFiles=("tests" "NOTES.txt" "ingress.yaml" "_helpers.tpl")
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
  export gChartRepoName
  export gChartRepoAccount
  export gChartRepoPassword

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

  #将生成的Chart镜像推送到gChartRepoName仓库中。
  #对于不同的push插件，CHart镜像推送方式是不同的。
  invokeExtendPointFunc "helmPushChartImage" "Chart镜像推送扩展" "${l_chartTgzOutDir}/${gCurrentChartName}-${gCurrentChartVersion}.tgz"
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
  local l_itemCount
  local l_content
  local l_i
  local l_item
  local l_key
  local l_serviceName
  local l_chartName
  local l_externalChartImages
  local l_externalChartImage

  local l_createGatewayRoute
  local l_createK8sService

  l_packageYaml="${l_chartPath}/package.yaml"
  l_valuesYaml="${l_chartPath}/values.yaml"

  #覆盖l_valuesYaml文件内容。
  echo "image:" > "${l_valuesYaml}"
  #在values.yaml文件中定义image.registry参数
  insertParam "${l_valuesYaml}" "image.registry" "${gDockerRepoName}"

  #先向values.yaml文件中插入params配置。
  readParam "${l_packageYaml}" "params"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    #将l_packageYaml文件中的params参数配置节添加到values.yaml文件中。
    invokeExtendPointFunc "addParamsToValuesYaml" "为values.yaml文件添加params配置节扩展" "${l_packageYaml}" "params" "${l_valuesYaml}"
  fi

  readParam "${l_packageYaml}" "name"
  l_chartName="${gDefaultRetVal}"

  readParam "${l_packageYaml}" "createGatewayRoute"
  l_createGatewayRoute="${gDefaultRetVal}"

  readParam "${l_packageYaml}" "createK8sService"
  l_createK8sService="${gDefaultRetVal}"

  readParam "${l_packageYaml}" "deployments"
  l_content="${gDefaultRetVal}"
  l_itemCount=$(echo -e "${l_content}" | grep -oP "^(\-)" | wc -l)
  for ((l_i = 0; l_i < l_itemCount; l_i++));do
    readParam "${l_packageYaml}" "deployments[${l_i}]"
    l_item="${gDefaultRetVal}"
    l_key="deployment${l_i}"
    insertParam "${l_valuesYaml}" "${l_key}" "${l_item}"

    #读取服务名称
    readParam "${l_packageYaml}" "deployments[${l_i}].name"
    l_serviceName="${gDefaultRetVal}"
    #删除已经无用的l_packageYaml文件。
    rm -f "${l_packageYaml}"

    #创建相关的K8s相关的ConfigMap配置。
    invokeExtendPointFunc "createConfigMapYamls" "创建ConfigMap配置扩展" "${l_valuesYaml}"  "${l_key}.configMaps" "${l_serviceName}"

    #将l_paramNameList中的params参数配并到values.yaml文件的params配置节中。
    invokeExtendPointFunc "combineParamsToValuesYaml" "为values.yaml文件追加params配置扩展" "${l_valuesYaml}" "${gDefaultRetVal}" "${l_chartName}"
    #deleteParam "${l_valuesYaml}" "${l_key}.configMaps"

    #检查并插入应用的外部镜像中的容器。
    readParam "${l_valuesYaml}" "${l_key}.refExternalChart"
    if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
      # shellcheck disable=SC2206
      l_externalChartImages=(${gDefaultRetVal//,/ })
      # shellcheck disable=SC2068
      for l_externalChartImage in ${l_externalChartImages[@]};do
        if [[ "${l_externalChartImage}" =~ ^(\./) ]];then
          l_externalChartImage="${gBuildPath}${l_externalChartImage:1}"
        fi
        info "正在处理外部Chart镜像引用：${l_externalChartImage}"
        #将外部Chart镜像中values.yaml文件中的params.deployment0配置节复制到l_valuesYaml文件中。
        #并将外部chart镜像中deployment[0]的initialContainers和containers合并到当前chart的deployment0中。
        invokeExtendChain "onProcessExternalChart" "${l_valuesYaml}" "${l_externalChartImage}" "${l_i}"
      done
    fi

    if [ "${l_createGatewayRoute}" == "true" ];then
      #创建K8s相关的网关配置。
      invokeExtendPointFunc "createGatewayRouteYamls" "创建网关路由配置" "${l_valuesYaml}" "${l_key}.gatewayRoute" "${l_serviceName}"
    fi

    if [ "${l_createK8sService}" == "true" ];then
      #创建K8S相关的Service资源
      invokeExtendPointFunc "createServiceYaml" "创建K8S相关的Service资源" "${l_valuesYaml}" "${l_key}" "${l_serviceName}"
    fi

    #创建K8S相关的服务账号资源, 默认实现中完成了gCurrentServiceVersion变量的赋值。
    invokeExtendPointFunc "createServiceAccountYaml" "创建K8S相关的服务账号资源" "${l_valuesYaml}" "${l_key}" "${l_serviceName}"

    #创建K8S相关的Deployment/DaemonSet/statefulSet资源
    invokeExtendPointFunc "createDeploymentYaml" "创建Deployment/DaemonSet/statefulSet资源" "${l_valuesYaml}" "${l_key}" "${l_serviceName}"

    #创建K8S相关的水平扩展配置资源
    invokeExtendPointFunc "createHpaYaml" "创建K8S相关的水平扩展配置资源" "${l_valuesYaml}" "${l_key}" "${l_serviceName}"

  done
}

function installHelm_ex() {
  export gBuildScriptRootDir
  local l_systemType=$1
  local l_archType=$2
  installHelmTool "${gBuildScriptRootDir}" "${l_systemType}" "${l_archType}"
}

function addHelmRepo_ex(){
  export gChartRepoAliasName
  export gChartRepoName
  export gChartRepoAccount
  export gChartRepoPassword
  #调用${gChartRepoType}-helm-helper.sh文件中的方法。
  addHelmRepo "${gChartRepoAliasName}" "${gChartRepoName}" "${gChartRepoAccount}" "${gChartRepoPassword}"
}

function onBeforeHelmPackage_ex() {
  export gBuildPath
  export gCustomizedHelm

  local l_yamlList
  local l_ymalFile

  if [[ "${gCustomizedHelm}" == "false" && -d "${gBuildPath}/chart-templates" ]];then
    info "尝试将主模块目录下chart-templates子目录中的*.yaml文件复制到./templates目录中 ..."
    #为项目自定义部分特殊配置提供了扩展。
    l_yamlList=$(find "${gBuildPath}/chart-templates" -type f -name "*.yaml")
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
  export gChartRepoName
  export gChartRepoAliasName
  export gChartRepoAccount
  export gChartRepoPassword

  local l_chartFile=$1
  #调用${gChartRepoType}-helm-helper.sh文件中的方法。
  pushChartImage "${l_chartFile}" "${gChartRepoAliasName}" "${gChartRepoName}" \
    "${gChartRepoAccount}" "${gChartRepoPassword}"
}

function addParamsToValuesYaml_ex(){
  export gDefaultRetVal
  export gFileContentMap

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

  #关闭yaml-helper.sh文件中的gImmediatelySaveBack标志。
  disableSaveBackImmediately
  l_saveBackStatus="${gDefaultRetVal}"

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
    [[ "${gDefaultRetVal}" =~ ^(\-1) ]] && \
      error "删除${l_valuesYaml##*/}文件中${l_paramPath}.configurable参数失败"
    info "删除${l_valuesYaml##*/}文件中${l_paramPath}.configurable参数成功"
  fi

  #恢复gSaveBackImmediately的值。
  enableSaveBackImmediately "${l_saveBackStatus}"
}

function combineParamsToValuesYaml_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile

  local l_valuesYaml=$1
  local l_paramNameList=$2
  local l_chartName=$3

  local l_index
  local l_item
  local l_array
  local l_packageName
  local l_paramValue
  local l_i
  declare -A l_paramDefaultValueMap

  ((l_index = -1))
  info "根据chart打包项的名称，获取该chart镜像对应的部署配置节的序号(用于后续读取参数的初始化值) ..." "-n"
  #根据l_chartName获取打包名。
  getListIndexByPropertyName "${gCiCdYamlFile}" "package" "chartName" "${l_chartName}"
  if [[ ! "${gDefaultRetVal}" =~ ^(\-1) ]];then
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
      l_array=(${gDefaultRetVal})
      l_index="${l_array[0]}"
    fi
  fi

  if [ "${l_index}" -ge 0 ];then
    info "成功获取序号：${l_index}" "*"
    info "将参数的默认值读取到内存中 ..."
    ((l_i = 0))
    while true;do
      readParam "${gCiCdYamlFile}" "deploy[${l_index}].params[${l_i}]"
      [[ "${gDefaultRetVal}" == "null" ]] && break
      l_paramName=$(echo "${gDefaultRetVal}" | grep "^name:.*$")
      l_paramName="${l_paramName//name: /}"
      l_paramValue=$(echo "${gDefaultRetVal}" | grep "^value:.*$")
      l_paramValue="${l_paramValue//value: /}"
      # shellcheck disable=SC2034
      l_paramDefaultValueMap["${l_paramName//\.Values\./}"]="${l_paramValue}"
      if [ "${l_paramValue}" ];then
        info "加载参数默认值：${l_paramName//\.Values\./}=>${l_paramValue}"
      else
        warn "加载参数默认值：${l_paramName//\.Values\./}=>${l_paramValue}"
      fi
      ((l_i = l_i + 1))
    done
  else
    warn "获取序号失败" "*"
  fi

  # shellcheck disable=SC2206
  local l_paramNames=(${l_paramNameList//,/ })
  # shellcheck disable=SC2068
  for l_item in ${l_paramNames[@]};do
    readParam "${l_valuesYaml}" "${l_item}"
    #如果不存在，则插入之。
    if [ "${gDefaultRetVal}" == "null" ];then
      #尝试读取参数默认值。
      l_paramValue="${l_paramDefaultValueMap[${l_item}]}"
      insertParam "${l_valuesYaml}" "${l_item}" "${l_paramValue}"
      if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
        error "向${l_valuesYaml##*/}文件中插入${l_item}(=${l_paramValue})参数失败"
      else
        info "向${l_valuesYaml##*/}文件中插入${l_item}(=${l_paramValue})参数成功"
      fi
    fi
  done
}

function createConfigMapYamls_ex(){
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gBuildPath

  local l_valuesYaml=$1
  local l_configMapsPath=$2
  local l_serviceName=$3

  local l_i
  local l_j
  local l_configMapFile
  local l_fileList
  local l_fileCount
  local l_fileItem
  local l_content
  local l_lineContent
  local l_key
  local l_lineNum
  local l_tmpRowNum

  local l_paramNameList
  local l_tmpList
  local l_itemCount
  local l_items
  local l_configMapName

  local l_keyList
  local l_tmpRowNumList
  local l_tmpSpaceNum

  l_paramNameList=""
  ((l_i = 0))
  while true; do
    readParam "${l_valuesYaml}" "${l_configMapsPath}[${l_i}].name"
    [[ "${gDefaultRetVal}" == "null" ]] && break
    if [[  ! "${gDefaultRetVal}" ]];then
      warn "${l_valuesYaml}文件中${l_configMapsPath}[${l_i}].name参数为空"
      ((l_i = l_i + 1))
      continue
    fi
    l_configMapName="${gDefaultRetVal}"

    readParam "${l_valuesYaml}" "${l_configMapsPath}[${l_i}].files"
    [[ "${gDefaultRetVal}" == "null" ]] && break
    if [[  ! "${gDefaultRetVal}" ]];then
      warn "${l_valuesYaml}文件中${l_configMapsPath}[${l_i}].files参数为空"
      ((l_i = l_i + 1))
      continue
    fi

    stringToArray "${gDefaultRetVal}" "l_fileList" $','
    l_fileCount="${#l_fileList[@]}"

    l_configMapFile="${l_valuesYaml%/*}/templates/${l_serviceName}-configmap.yaml"
    cp -f "${gBuildScriptRootDir}/templates/chart/configmap-template.yaml" "${l_configMapFile}"

    updateParam "${l_configMapFile}" "metadata.name" "${l_configMapName}"
    [[ "${gDefaultRetVal}" =~ ^(\-1) ]] && \
      error "更新templates/chart/configmap-template.yaml文件中metadata.name参数失败"

    l_keyList=()
    l_tmpRowNumList=()
    # shellcheck disable=SC2068
    for ((l_j=0; l_j < l_fileCount; l_j++ ));do
      l_fileItem="${l_fileList[${l_j}]}"
      [[ "${l_fileItem}" =~ ^(\.\/) ]] && l_fileItem="${gBuildPath}${l_fileItem:1}"
      l_content=$(cat "${l_fileItem}")
      l_key="${l_fileItem##*/}"
      info "向${l_configMapFile##*/}文件中插入${l_fileItem##*/}文件内容..." "-n"
      #将l_key的原始值缓存起来。
      l_keyList["${l_j}"]="${l_key}"
      #必须将l_key中的”.“符号替换为其他符号，这里选择”_“符号。
      l_key="${l_key//./_}"
      insertParam "${l_configMapFile}" "data.${l_key}" "|\n${l_content}"
      [[ "${gDefaultRetVal}" =~ ^(\-1) ]] && error "插入失败"
      info "插入成功" "*"
      #获得写入的起始行号。
      # shellcheck disable=SC2206
      l_lineNum=(${gDefaultRetVal})
      ((l_tmpRowNum = l_lineNum[0] - 1))
      l_tmpRowNumList["${l_j}"]="${l_tmpRowNum}"

      #提取l_content中包含的.Values.开头的变量。
      # shellcheck disable=SC2002
      l_content=$(echo -e "${l_content}" | grep -oP "\{\{[ ]+\.Values(\.[a-zA-Z0-9_\-]+)+[ ]+\}\}" | sort | uniq -c)
      l_paramNameList="${l_paramNameList},${l_content}"
    done

    ((l_i = l_i + 1))
  done

  #直接更新文件内容前需要先清除内存中缓存的文件内容。
  #否则会导致内存中的旧内容覆盖最新更新的文件内容。
  clearCachedFileContent "${l_configMapFile}"

  # shellcheck disable=SC2145
  for (( l_i=0; l_i < ${#l_tmpRowNumList[@]}; l_i++));do
    l_tmpRowNum="${l_tmpRowNumList[${l_i}]}"
    #获取文件名原始值。
    l_key="${l_keyList[${l_i}]}"
    #读取目标行的前导空格数量
    l_tmpSpaceNum=$(sed -n "${l_tmpRowNum}p" "${l_configMapFile}" | grep -oP "^([ ]*)" | grep -oP " " | wc -l)
    l_lineContent="$(printf "%${l_tmpSpaceNum}s")"
    l_lineContent="${l_lineContent}${l_key}: |"
    info "更新${l_configMapFile##*/}文件中第${l_tmpRowNum}行的内容为：${l_lineContent}"
    #更新行的内容。
    sed -i "${l_tmpRowNum}c\\${l_lineContent}" "${l_configMapFile}"
  done

  gDefaultRetVal=""
  if [ "${l_paramNameList}" ];then
    l_paramNameList="${l_paramNameList:1}"
    l_content=$(echo -e "${l_paramNameList}" | grep -oP "\{\{[ ]+\.Values(\.[a-zA-Z0-9_\-]+)+[ ]+\}\}" | sort | uniq -c)
    stringToArray "${l_content}" "l_tmpList"
    l_itemCount="${#l_tmpList[@]}"

    l_paramNameList=""
    for ((l_i=0; l_i < l_itemCount; l_i++));do
      # shellcheck disable=SC2206
      l_items=(${l_tmpList[${l_i}]})
      l_paramNameList="${l_paramNameList},${l_items[2]:8}"
    done
    gDefaultRetVal="${l_paramNameList:1}"
  fi
}

function createGatewayRouteYamls_ex() {
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gLanguage

  local l_valuesYaml=$1
  local l_gatewayPath=$2
  local l_serviceName=$3

  local l_gatewayType
  local l_gatewayVersion
  local l_moduleName
  local l_templateFile
  local l_configFile
  local l_content

  readParam "${l_valuesYaml}" "${l_gatewayPath}.type"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && error "网关类型(${l_gatewayPath}.type)不能为空"
  l_gatewayType="${gDefaultRetVal}"

  #读取模板文件。
  l_templateFile="${gBuildScriptRootDir}/templates/chart/${gLanguage}/${l_gatewayType}-gateway-template.yaml"
  if [ ! -f "${l_templateFile}" ];then
    warn "${gLanguage}语言项目模板文件不存在：${l_templateFile}"
    l_templateFile="${gBuildScriptRootDir}/templates/chart/${l_gatewayType}-gateway-template.yaml"
    if [ -f "${l_templateFile}" ];then
      info "使用公共模板文件：${l_templateFile}"
    else
      error "模板文件不存在：${l_templateFile}"
    fi
  fi

  readParam "${l_valuesYaml}" "${l_gatewayPath}.version"
  [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && error "网关路由版本(${l_gatewayPath}.version)不能为空"
  #todo: 获取网关组件的版本号，该参数会被下面的模板使用，参数名称不能更改。
  # shellcheck disable=SC2034
  l_gatewayVersion="${gDefaultRetVal}"
  #todo：定义模板文件中使用的变量l_moduleName。
  l_moduleName="${l_gatewayPath%.*}"

  #定义网关路由配置文件。
  l_configFile="${l_valuesYaml%/*}/templates/${l_serviceName}-route.yaml"
  #读取类型匹配的模板文件。
  l_content=$(cat "${l_templateFile}")
  #替换模板中的变量。
  eval "l_content=\$(echo -e \"${l_content}\")"
  #将替换后的内容写入网关路由配置文件中。
  echo "${l_content}" > "${l_configFile}"

  #删除自动生成的ingress.yaml文件。
  rm -f "${l_valuesYaml%/*}/templates/ingress.yaml"
}

function createServiceYaml_ex() {
  export gBuildScriptRootDir
  export gCurrentChartName
  export gCurrentChartVersion
  export gLanguage

  local l_valuesYaml=$1
  local l_moduleName=$2
  local l_serviceName=$3

  local l_templateFile
  local l_configFile
  local l_content

  #读取Service模板文件。
  l_templateFile="${gBuildScriptRootDir}/templates/chart/${gLanguage}/service-template.yaml"
  if [ ! -f "${l_templateFile}" ];then
    warn "${gLanguage}语言项目模板文件不存在：${l_templateFile}"
    l_templateFile="${gBuildScriptRootDir}/templates/chart/service-template.yaml"
    if [ -f "${l_templateFile}" ];then
      info "使用公共模板文件：${l_templateFile}"
    else
      error "模板文件不存在：${l_templateFile}"
    fi
  fi

  #读取文件内容
  l_content=$(cat "${l_templateFile}")
  #替换模板中的变量。
  eval "l_content=\$(echo -e \"${l_content}\")"
  #设定目标配置文件
  l_configFile="${l_valuesYaml%/*}/templates/${l_serviceName}-service.yaml"
  #写目标配置文件中。
  echo "${l_content}" > "${l_configFile}"

  #删除自动生成的service.yaml文件。
  rm -f "${l_valuesYaml%/*}/templates/service.yaml"
}

function createServiceAccountYaml_ex() {
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gCurrentServiceVersion
  export gLanguage

  local l_valuesYaml=$1
  local l_moduleName=$2
  local l_serviceName=$3

  local l_templateFile
  local l_configFile
  local l_content
  local l_i

  l_templateFile="${gBuildScriptRootDir}/templates/chart/${gLanguage}/serviceaccount-template.yaml"
  if [ ! -f "${l_templateFile}" ];then
    warn "${gLanguage}语言项目模板文件不存在：${l_templateFile}"
    l_templateFile="${gBuildScriptRootDir}/templates/chart/serviceaccount-template.yaml"
    if [ -f "${l_templateFile}" ];then
      info "使用公共模板文件：${l_templateFile}"
    else
      error "模板文件不存在：${l_templateFile}"
    fi
  fi

  ((l_i = 0))
  while true; do
    #获取匹配模块的版本。
    readParam "${l_valuesYaml}" "${l_moduleName}.initContainers[${l_i}].name"
    if [ "${gDefaultRetVal}" == "null" ];then
      break
    elif [ "${gDefaultRetVal}" == "${l_serviceName}-business" ];then
       #获取模块的版本。
      readParam "${l_valuesYaml}" "${l_moduleName}.initContainers[${l_i}].tag"
      #todo: eval语句用的变量。
      gCurrentServiceVersion="${gDefaultRetVal}"
      break
    fi
    ((l_i = l_i + 1))
  done

  if [ ! "${gCurrentServiceVersion}" ];then
    ((l_i = 0))
    while true; do
      #获取匹配模块的版本。
      readParam "${l_valuesYaml}" "${l_moduleName}.containers[${l_i}].name"
      if [ "${gDefaultRetVal}" == "null" ];then
        break
      elif [ "${gDefaultRetVal}" == "${l_serviceName}" ];then
         #获取模块的版本。
        readParam "${l_valuesYaml}" "${l_moduleName}.containers[${l_i}].tag"
        #todo: eval语句用的变量。
        gCurrentServiceVersion="${gDefaultRetVal}"
        break
      fi
      ((l_i = l_i + 1))
    done
  fi

  if [ ! "${gCurrentServiceVersion}" ];then
    error "读取与服务名称${l_serviceName}匹配的${l_moduleName}.containers[?].tag参数失败"
  fi

  #读取模板文件内容。
  l_content=$(cat "${l_templateFile}")
  #替换模板中的变量。
  eval "l_content=\$(echo -e \"${l_content}\")"
  #设定目标配置文件
  l_configFile="${l_valuesYaml%/*}/templates/${l_serviceName}-serviceaccount.yaml"
  #将替换后的内容写入配置文件中。
  echo "${l_content}" > "${l_configFile}"

  #删除自动生成的ingress.yaml文件。
  rm -f "${l_valuesYaml%/*}/templates/serviceaccount.yaml"
}

function createDeploymentYaml_ex() {
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gLanguage

  local l_valuesYaml=$1
  local l_moduleName=$2
  local l_serviceName=$3

  local l_kindType
  local l_templateFile
  local l_configFile
  local l_content

  #读取匹配类型的模板文件。
  readParam "${l_valuesYaml}" "${l_moduleName}.kind"
  l_kindType="${gDefaultRetVal,,}"

  l_templateFile="${gBuildScriptRootDir}/templates/chart/${gLanguage}/${l_kindType}-template.yaml"
  if [ -f "${l_templateFile}" ];then
    info "为${l_kindType}类型的服务，使用${gLanguage}语言项目公共模板文件：${l_templateFile}"
  else
    warn "${gLanguage}语言项目模板文件不存在：${l_templateFile}"
    l_templateFile="${gBuildScriptRootDir}/templates/chart/${gLanguage}/deployment-template.yaml"
    if [ -f "${l_templateFile}" ];then
      info "为${l_kindType}类型的服务，使用${gLanguage}语言项目公共模板文件：${l_templateFile}"
    else
      l_templateFile="${gBuildScriptRootDir}/templates/chart/${l_kindType}-template.yaml"
      if [ -f "${l_templateFile}" ];then
        info "为${l_kindType}类型的服务，使用公共模板文件：${l_templateFile}"
      else
        l_templateFile="${gBuildScriptRootDir}/templates/chart/deployment-template.yaml"
        if [ -f "${l_templateFile}" ];then
          info "为${l_kindType}类型的服务，使用公共模板文件：${l_templateFile}"
        else
          error "无法为${l_kindType}类型的服务匹配到合适的模板文件}"
        fi
      fi
    fi
  fi

  #设定目标配置文件
  l_configFile="${l_valuesYaml%/*}/templates/${l_serviceName}-${l_kindType}.yaml"

  l_kindType="${l_kindType^}"
  #读取模板文件内容。
  l_content=$(cat "${l_templateFile}")
  #替换模板中的变量。
  eval "l_content=\$(echo -e \"${l_content}\")"
  #将替换后的内容写入配置文件中。
  echo "${l_content}" > "${l_configFile}"

  #删除自动生成的ingress.yaml文件。
  rm -f "${l_valuesYaml%/*}/templates/deployment.yaml"
}

function createHpaYaml_ex() {
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gLanguage

  local l_valuesYaml=$1
  local l_moduleName=$2
  local l_serviceName=$3

  local l_templateFile
  local l_configFile
  local l_content

  l_templateFile="${gBuildScriptRootDir}/templates/chart/${gLanguage}/hpa-template.yaml"
  if [ ! -f "${l_templateFile}" ];then
    warn "${gLanguage}语言项目模板文件不存在：${l_templateFile}"
    l_templateFile="${gBuildScriptRootDir}/templates/chart/hpa-template.yaml"
   if [ -f "${l_templateFile}" ];then
     info "使用公共模板文件：${l_templateFile}"
   else
     error "模板文件不存在：${l_templateFile}"
   fi
  fi

  #读取模板文件内容。
  l_content=$(cat "${l_templateFile}")
  #替换模板中的变量。
  eval "l_content=\$(echo -e \"${l_content}\")"
  #设定目标配置文件
  l_configFile="${l_valuesYaml%/*}/templates/${l_serviceName}-hpa.yaml"
  #将替换后的内容写入配置文件中。
  echo "${l_content}" > "${l_configFile}"

  #删除自动生成的hpa.yaml文件。
  rm -f "${l_valuesYaml%/*}/templates/hpa.yaml"
}

#chart阶段单镜像模式下（默认是双镜像模式）对ci-cd.yaml文件的调整
function handleBuildingSingleImageForChart_ex() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gBuildType
  export gServiceName

  local l_saveBackStatus
  local l_businessVersion
  local l_i
  local l_j
  local l_k
  local l_paramArray
  local l_paramItem
  local l_paramName
  local l_paramValue

  #关闭yaml-helper.sh文件中的gImmediatelySaveBack标志。
  disableSaveBackImmediately
  l_saveBackStatus="${gDefaultRetVal}"

  #读取业务镜像的版本号。
  readParam "${gCiCdYamlFile}" "globalParams.businessVersion"
  l_businessVersion="${gDefaultRetVal}"

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
          ((l_k = 0))
          while true; do
            readParam "${gCiCdYamlFile}" "chart[${l_i}].deployments[${l_j}].initContainers[${l_k}].name"
            [[ "${gDefaultRetVal}" == "null" ]] && break
            if [ "${gDefaultRetVal}" == "${gServiceName}-business" ];then
              l_param="chart[${l_i}].deployments[${l_j}].initContainers[${l_k}]"
              deleteParam "${gCiCdYamlFile}" "${l_param}"
              if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
                error "删除${gCiCdYamlFile##*/}文件中${l_param}参数失败"
              else
                info "成功删除${gCiCdYamlFile##*/}文件中${l_param}配置项"
              fi
              break
            fi
            ((l_k = l_k + 1))
          done
          ((l_k = 0))
          while true; do
            readParam "${gCiCdYamlFile}" "chart[${l_i}].deployments[${l_j}].containers[${l_k}].name"
            [[ "${gDefaultRetVal}" == "null" ]] && break
            if [ "${gDefaultRetVal}" == "${gServiceName}-base" ];then
              l_paramArray=("name|${gServiceName}" "repository|${gServiceName}" "tag|${l_businessVersion}")
              # shellcheck disable=SC2068
              for l_paramItem in ${l_paramArray[@]};do
                l_paramName="${l_paramItem%%|*}"
                l_paramValue="${l_paramItem#*|}"
                l_paramName="chart[${l_i}].deployments[${l_j}].containers[${l_k}].${l_paramName}"
                updateParam "${gCiCdYamlFile}" "${l_paramName}" "${l_paramValue}"
                if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
                  error "更新${gCiCdYamlFile##*/}文件中${l_paramName}参数失败"
                else
                  info "更新${gCiCdYamlFile##*/}文件中${l_paramName}参数值为：${l_paramValue}"
                fi
              done
              break
            fi
            ((l_k = l_k + 1))
          done
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
  local l_cicdYaml=$1

  local l_index
  local l_index1
  local l_index2

  local l_paramPath

  export gDefaultRetVal

  ((l_index = 0))
  while true; do
    #循环处理chart的每一项
    readParam "${l_cicdYaml}" "chart[${l_index}]"
    [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && break

    #循环处理chart[?].deployments的每一项
    ((l_index1 = 0))
    while true; do
      readParam "${l_cicdYaml}" "chart[${l_index}].deployments[${l_index1}]"
      [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && break

      #循环处理chart[?].deployments[?].containers的每一项的ports属性。
      ((l_index2 = 0))
      while true; do
        l_paramPath="chart[${l_index}].deployments[${l_index1}].containers[${l_index2}]"
        readParam "${l_cicdYaml}" "${l_paramPath}"
        [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]] && break

        info "检查并生成项目Service配置信息..."
        _createServiceConfig "${l_cicdYaml}" "${l_paramPath}"

        info "检查并处理项目开放了多个容器端口的情况..."
        _processMultiplePorts "${l_cicdYaml}" "${l_paramPath}"

        ((l_index2 = l_index2 + 1))
      done

      ((l_index1 = l_index1 + 1))
    done

    ((l_index = l_index + 1))
  done
}

function _createServiceConfig() {
  export gDefaultRetVal
  export gBuildScriptRootDir
  export gTempFileDir
  export gFileDataBlockMap

  local l_cicdYaml=$1
  local l_paramPath=$2

  local l_configTemplate
  local l_tmpFile
  local l_name
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

  readParam "${l_cicdYaml}" "${l_paramPath}.service"
  if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
    #读取ports配置节某一项的内容，并写入临时文件中。
    readParam "${l_cicdYaml}" "${l_paramPath}"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      warn "${l_paramPath}配置节是空的"
      return
    fi

    #将现有配置写入临时文件中。
    # shellcheck disable=SC2088
    l_tmpFile="${gTempFileDir}/${RANDOM}.tmp"
    registerTempFile "${l_tmpFile}"
    echo "service:" > "${l_tmpFile}"

    readParam "${l_cicdYaml}" "${l_paramPath}.name"
    l_name="${gDefaultRetVal}"

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
              updateParam "${l_tmpFile}" "service.${l_subPath}.name" "${l_name}"
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
            if [[ "${l_subPath}" == "nodePort" ]];then
              insertParam "${l_tmpFile}" "service.${l_subPath}.ports[${l_tmpIndex}].nodePort" "${l_nodePortList[${l_j}]}"
            fi
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

#**********************私有方法-结束***************************#

#加载chart阶段脚本库文件
loadExtendScriptFileForLanguage "chart"

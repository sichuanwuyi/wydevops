#!/usr/bin/env bash

function externalChartGenerator_default() {
  export gDefaultRetVal
  export gCurrentChartName
  export gCurrentChartVersion

  local l_generatorFile=$1
  local l_resourceType=$2
  local l_generatorName=$3
  local l_valuesYaml=$4
  local l_index=$5
  local l_configPath=$6

  local l_refExternalCharts
  local l_refExternalChart

  if [ "${l_resourceType}" != "ExternalChart" ];then
    #返回是否已处理了该资源
    gDefaultRetVal="false"
    return
  fi

  #处理引用的外部服务。
  readParam "${l_valuesYaml}" "${l_configPath}"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    # shellcheck disable=SC2206
    l_refExternalCharts=(${gDefaultRetVal//,/ })
    # shellcheck disable=SC2068
    for l_refExternalChart in ${l_refExternalCharts[@]};do
      #判断外部Chart是否是wydevops生成的。

      info "向${l_valuesYaml##*/}文件中插入外部Chart镜像中的deployments配置"
      _insertExternalChart "${l_valuesYaml}" "${gCurrentChartName}" "${gCurrentChartVersion}" \
        "${l_refExternalChart}" "${l_index}"
      l_index="${gDefaultRetVal}"
    done
  fi

  info "清除${l_valuesYaml##*/}文件中的${l_configPath}参数"
  deleteParam "${l_valuesYaml}" "${l_configPath}"

  gDefaultRetVal="true"
}

#***************************私有方法*******************************#

function _insertExternalChart() {
  export gDefaultRetVal
  export gChartRepoName
  export gChartRepoType
  export gChartRepoInstanceName
  export gTempFileDir
  export gChartRepoAccount
  export gChartRepoPassword

  local l_valuesYaml=$1
  local l_curChartName=$2
  local l_curChartVersion=$3
  local l_refExternalChart=$4
  local l_index=$5

  local l_chartName
  local l_chartVersion
  local l_externalValuesYaml
  local l_externalTemplateDir
  local l_currentTemplateDir

  local l_content
  local l_maxIndex
  local l_externalValuesYamlContent

  local l_fileList
  local l_file
  local l_externalFileContent
  local l_tmpContent
  local l_contentType

  local l_isOk
  local l_path

  #判断l_refExternalChart是否带有路径,如果没有路径，则从Chart仓库拉取外部Chart镜像
  if [[ ! "${l_refExternalChart}" =~ ^(.*)/(.*)$ ]];then

    [[ ! "${gChartRepoName}" ]] && \
      error "没有配置Chart镜像仓库，无法拉取${l_refExternalChart}镜像。请指定Chart镜像仓库或${l_refExternalChart}镜像文件所在的本地路径。"
    l_chartVersion="${l_refExternalChart##*-}"
    l_chartVersion="${l_chartVersion%.*}"
    l_chartName="${l_refExternalChart%-*}"
    #拉取指定的chart镜像到gBuildPath目录中。
    pullChartImage "${l_chartName}" "${l_chartVersion}" "${gChartRepoType}" "${gChartRepoName}" \
      "${gChartRepoInstanceName}" "${gTempFileDir}" "${gChartRepoAccount}" "${gChartRepoPassword}"
    l_refExternalChart="${gTempFileDir}/${l_refExternalChart}"
  else
    l_chartName="${l_refExternalChart##*/}"
    l_chartVersion="${l_chartName##*-}"
    l_chartVersion="${l_chartVersion%.*}"
    l_chartName="${l_chartName%-*}"
  fi

  gDefaultRetVal="${l_index}"
  if [ -f "${l_refExternalChart}" ];then
    info "解压外部Chart镜像文件..."
    tar -zxvf "${l_refExternalChart}" -C "${l_refExternalChart%/*}"
    l_externalValuesYaml="${l_refExternalChart%/*}/${l_chartName}/values.yaml"
    l_externalTemplateDir="${l_externalValuesYaml%/*}/templates"
    l_currentTemplateDir="${l_valuesYaml%/*}/templates"

    l_externalValuesYamlContent=$(cat "${l_externalValuesYaml}")

    l_isOk="false"
    #判断外部镜像是否是wydevops创建的。
    readParam "${l_externalValuesYaml}" "image.registry"
    if [ "${gDefaultRetVal}" != "null" ];then
      #外部Chart镜像的values.yaml文件存在"image.registry"参数
      readParam "${l_externalValuesYaml}" "gatewayRoute.host"
      if [ "${gDefaultRetVal}" != "null" ];then
        #并且存在gatewayRoute.host参数
        readParam "${l_externalValuesYaml}" "deployment0.name"
        if [ "${gDefaultRetVal}" != "null" ];then
          #并且存在deployment0.name参数，则判定该chart镜像是wydevops生成的
          info "调用专用于wydevops生成的Chart镜像的合并方法..."
          _combineExternalChartCreatedByWydevops "${l_valuesYaml}" "${l_curChartName}" "${l_curChartVersion}" "${l_index}" \
            "${l_externalValuesYaml}" "${l_externalTemplateDir}" "${l_currentTemplateDir}" "${l_externalValuesYamlContent}" \
            "${l_refExternalChart}"
          l_isOk="true"
        fi
      fi
    fi

    if [ "${l_isOk}" == "false" ];then
      #插入未知来源的外部Chart镜像。
      _insertUnknownExternalDeployment "${l_valuesYaml}" "${l_curChartName}" "${l_curChartVersion}" "${l_externalValuesYaml}" \
        "${l_externalTemplateDir}" "${l_currentTemplateDir}" "${l_externalValuesYamlContent}"
    fi

    info "删除外部Chart镜像文件和解压出的目录..."
    rm -f "${l_refExternalChart:?}"
    l_path="${l_refExternalChart%/*}"
    rm -rf "${l_path:?}/${l_chartName}"

  fi
  gDefaultRetVal="${l_index}"
}

#合并wydevops生成的Chart镜像
function _combineExternalChartCreatedByWydevops() {
  export gDefaultRetVal

  local l_valuesYaml=$1
  local l_curChartName=$2
  local l_curChartVersion=$3
  local l_index=$4
  local l_externalValuesYaml=$5
  local l_externalTemplateDir=$6
  local l_currentTemplateDir=$7
  local l_externalValuesYamlContent=$8
  local l_refExternalChart=$9

  local l_i
  local l_paramPaths
  local l_paramPath

  local l_fileList
  local l_file
  local l_externalFileContent
  local l_tmpContent
  local l_contentType

  ((l_i = 0))
  while true;do
    #检测外部镜像的values.yaml文件中是否存在配置：deployment${l_i}
    readRowRange "${l_externalValuesYaml}" "deployment${l_i}"
    #如果不存在，则退出。
    [[ "${gDefaultRetVal}" =~ ^(\-1) ]] && break

    #构造参数映射列表
    l_paramPaths=("params.deployment${l_i}|params.deployment${l_index}" \
        "deployment${l_i}|deployment${l_index}")

    # shellcheck disable=SC2068
    for l_paramPath in ${l_paramPaths[@]};do
      info "读取外部镜像${l_externalValuesYaml##*/}文件中的${l_paramPath%%|*}参数值..."
      readParam "${l_externalValuesYaml}" "${l_paramPath%%|*}"
      if [[ "${gDefaultRetVal}" == "null" && ! "${l_paramPath}" =~ ^(params\.) ]];then
        warn "外部Chart镜像的${l_externalValuesYaml##*/}文件中不存在${l_paramPath%%|*}参数"
        error "外部Chart镜像${l_refExternalChart##*/}不是wydevops生成的。"
      fi
      [[ ! "${gDefaultRetVal}" ]] && continue
      info "将读取的参数值赋给当前镜像${l_valuesYaml##*/}文件中的${l_paramPath#*|}参数"
      insertParam "${l_valuesYaml}" "${l_paramPath#*|}" "${gDefaultRetVal}"
    done

    l_fileList=$(find "${l_externalTemplateDir}" -maxdepth 1 -type f -name "*.yaml")
    # shellcheck disable=SC2068
    for l_file in ${l_fileList[@]};do
      info "调整外部镜像中${l_file##*/}文件的参数..."
      sed -i "s/\.deployment${l_i}\./\.deployment${l_index}\./g" "${l_file}"
      sed -i "s/\.deployment${l_i} /\.deployment${l_index} /g" "${l_file}"
    done

    ((l_i = l_i + 1))
    ((l_index = l_index + 1))
  done

  l_fileList=$(find "${l_externalTemplateDir}" -maxdepth 1 -type f -name "*.yaml")
  # shellcheck disable=SC2068
  for l_file in ${l_fileList[@]};do
    # shellcheck disable=SC2002
    l_externalFileContent=$(cat "${l_file}")

    l_tmpContent=$(echo -e "${l_externalFileContent}" | grep -m 1 -oP "^([ ]*)helm\.sh\/chart:(.*)$")
    if [ "${l_tmpContent}" ];then
      l_contentType="${l_tmpContent%%:*}"
      sed -i "s/${l_tmpContent//\//\\\/}/${l_contentType//\//\\\/}: ${l_curChartName}-${l_curChartVersion}/g" "${l_file}"
    fi

    l_tmpContent=$(echo -e "${l_externalFileContent}" | grep -m 1 -oP "^([ ]*)app.kubernetes.io\/version:(.*)$")
    if [ "${l_tmpContent}" ];then
      l_contentType="${l_tmpContent%%:*}"
      sed -i "s/${l_tmpContent//\//\\\/}/${l_contentType//\//\\\/}: ${l_curChartVersion}/g" "${l_file}"
    fi

    info "从外部镜像拷贝${l_file##*/}文件到当前镜像的templates目录中"
    cp -f "${l_file}" "${l_currentTemplateDir}/"

  done

  gDefaultRetVal="${l_index}"

}

#插入不知来源的chart镜像。
function _insertUnknownExternalDeployment() {
  export gDefaultRetVal

  local l_valuesYaml=$1
  local l_curChartName=$2
  local l_curChartVersion=$3
  local l_externalValuesYaml=$4
  local l_externalTemplateDir=$5
  local l_currentTemplateDir=$6
  local l_externalValuesYamlContent=$7

  local l_content
  local l_maxIndex

  local l_fileList
  local l_file
  local l_externalFileContent
  local l_tmpContent
  local l_contentType

  #查询当前Chart镜像values.yaml文件中所有deployment?的后缀数值最大是多少？
  # shellcheck disable=SC2002
  l_content=$(cat "${l_valuesYaml}" | grep -oP "^deployment[0-9]+:" | tail -n 1)
  (( l_maxIndex = -1))
  [[ "${l_content}" ]] && l_maxIndex=$(echo -e "${l_content}" | grep -oP "[0-9]+" )
  ((l_maxIndex = l_maxIndex + 1))

  #将外部Chart中的values.yaml文件内容整体复制到当前Chart镜像的values.yaml文件中deployment${l_maxIndex}下面。
  insertParam "${l_valuesYaml}" "deployment${l_maxIndex}" "${l_externalValuesYamlContent}"

  #读取外部Chart镜像中templates目录下的所有文件，并将文件内容中所有”.Values.“替换成”.Values.deployment${l_maxIndex}.“
  #替换完后全部复制到当前Chart镜像的templates目录下。
  l_fileList=$(find "${l_externalTemplateDir}" -maxdepth 1 -type f)
  # shellcheck disable=SC2068
  for l_file in ${l_fileList[@]};do
    [[ "${l_file}" =~ ^.*\.txt$ ]] && continue
    info "调整外部镜像中${l_file##*/}文件中的参数..."
    sed -i "s/\.Values\./\.Values\.deployment${l_maxIndex}\./g" "${l_file}"

    l_externalFileContent=$(cat "${l_file}")
    l_tmpContent=$(echo -e "${l_externalFileContent}" | grep -m 1 -oP "^([ ]*)helm\.sh\/chart:(.*)$")
    l_contentType="${l_tmpContent%%:*}"
    sed -i "s/${l_tmpContent//\//\\\/}/${l_contentType//\//\\\/}: ${l_curChartName}-${l_curChartVersion}/g" "${l_file}"

    l_tmpContent=$(echo -e "${l_externalFileContent}" | grep -m 1 -oP "^([ ]*)app.kubernetes.io\/version:(.*)$")
    l_contentType="${l_tmpContent%%:*}"
    sed -i "s/${l_tmpContent//\//\\\/}/${l_contentType//\//\\\/}: ${l_curChartVersion}/g" "${l_file}"

    info "将外部chart镜像中的${l_file##*/}文件复制到当前chart镜像的templates目录中..."
    cp -f "${l_file}" "${l_currentTemplateDir}/"
  done

  ((l_maxIndex = l_maxIndex + 1))
  gDefaultRetVal="${l_maxIndex}"
}


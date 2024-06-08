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
      info "向${l_valuesYaml##*/}文件中插入外部Chart镜像中的deployments配置"
      _insertExternalDeployment "${l_valuesYaml}" "${gCurrentChartName}" "${gCurrentChartVersion}" \
        "${l_refExternalChart}" "${l_index}"
      l_index="${gDefaultRetVal}"
    done
  fi

  info "清除${l_valuesYaml##*/}文件中的${l_configPath}参数"
  deleteParam "${l_valuesYaml}" "${l_configPath}"

  gDefaultRetVal="true"
}

#***************************私有方法*******************************#

function _insertExternalDeployment(){
  export gChartRepoName
  export gChartRepoType

  local l_valuesYaml=$1
  local l_curChartName=$2
  local l_curChartVersion=$3
  local l_refExternalChart=$4
  local l_index=$5

  local l_chartName
  local l_chartVersion
  local l_valuesYaml1
  local l_templateDir1
  local l_templateDir

  local l_paramPaths
  local l_paramPath
  local l_i

  local l_fileList
  local l_file
  local l_content
  local l_contentType
  local l_tmpContent

  #判断l_refExternalChart是否带有路径,如果没有路径，则从Chart仓库拉取外部Chart镜像
  if [[ ! "${l_refExternalChart}" =~ ^(.*)/(.*)$ ]];then

    [[ ! "${gChartRepoName}" ]] && \
      error "没有配置Chart镜像仓库，无法拉取${l_refExternalChart}镜像。请指定Chart镜像仓库或${l_refExternalChart}镜像文件所在的本地路径。"
    l_chartVersion="${l_refExternalChart##*-}"
    l_chartVersion="${l_chartVersion%.*}"
    l_chartName="${l_refExternalChart%-*}"
    #拉取指定的chart镜像到gBuildPath目录中。
    pullChartImage "${gChartRepoType}" "${l_chartName}" "${l_chartVersion}" "${gChartRepoInstanceName}" "${gTempFileDir}"
    l_refExternalChart="${gTempFileDir}/${l_refExternalChart}"
  else
    l_chartName="${l_refExternalChart##*/}"
    l_chartVersion="${l_chartName##*-}"
    l_chartVersion="${l_chartVersion%.*}"
    l_chartName="${l_chartName%-*}"
  fi

  if [ -f "${l_refExternalChart}" ];then
    info "解压外部Chart镜像文件..."
    tar -zxvf "${l_refExternalChart}" -C "${l_refExternalChart%/*}"
    l_valuesYaml1="${l_refExternalChart%/*}/${l_chartName}/values.yaml"
    l_templateDir1="${l_valuesYaml1%/*}/templates"
    l_templateDir="${l_valuesYaml%/*}/templates"

    ((l_i = 0))
    while true;do
      readRowRange "${l_valuesYaml1}" "deployment${l_i}"
      [[ "${gDefaultRetVal}" =~ ^(\-1) ]] && break

      l_paramPaths=("params.deployment${l_i}|params.deployment${l_index}" \
          "deployment${l_i}|deployment${l_index}")

      # shellcheck disable=SC2068
      for l_paramPath in ${l_paramPaths[@]};do
        info "读取外部镜像${l_valuesYaml1##*/}文件中的${l_paramPath%%|*}参数值..."
        readParam "${l_valuesYaml1}" "${l_paramPath%%|*}"
        if [ "${gDefaultRetVal}" == "null" ];then
          warn "外部Chart镜像的${l_valuesYaml1##*/}文件中不存在${l_paramPath%%|*}参数"
          error "外部Chart镜像${l_externalChartImage##*/}不是使用wydevops生成的。"
        fi
        [[ ! "${gDefaultRetVal}" ]] && continue
        info "将读取的参数值赋给当前镜像${l_valuesYaml##*/}文件中的${l_paramPath#*|}参数"
        insertParam "${l_valuesYaml}" "${l_paramPath#*|}" "${gDefaultRetVal}"
      done

      #从外部镜像中拷贝与deployment${l_i}参数相关的所有文件到当前镜像的templates目录中。
      l_fileList=$(find "${l_templateDir1}" -maxdepth 1 -type f -name "*.yaml")
      # shellcheck disable=SC2068
      for l_file in ${l_fileList[@]};do
        # shellcheck disable=SC2002
        l_content=$(cat "${l_file}")

        l_contentType=$(echo -e "${l_content}" | grep -oP "^(kind: ConfigMap)$")
        if [ "${l_contentType}" ];then
          info "从外部镜像拷贝${l_file##*/}文件到当前镜像的templates目录中"
          cp -f "${l_file}" "${l_templateDir}/"
          continue
        fi

        l_contentType=$(echo -e "${l_content}" | grep -oP "\.Values\.deployment${l_i}")
        [ ! "${l_contentType}" ] && continue

        l_contentType=$(echo -e "${l_content}" | grep -oP "^kind: (Deployment|Service|ServiceAccount|HorizontalPodAutoscaler)$")
        if [ "${l_contentType}" ];then
          info "调整外部镜像中${l_file##*/}文件的参数..."
          sed -i "s/\.deployment${l_i}/\.deployment${l_index}/g" "${l_file}"

          l_tmpContent=$(echo -e "${l_content}" | grep -m 1 -oP "^([ ]*)helm\.sh\/chart:(.*)$")
          l_contentType="${l_tmpContent%%:*}"
          sed -i "s/${l_tmpContent//\//\\\/}/${l_contentType//\//\\\/}: ${l_curChartName}-${l_curChartVersion}/g" "${l_file}"

          l_tmpContent=$(echo -e "${l_content}" | grep -m 1 -oP "^([ ]*)app.kubernetes.io\/version:(.*)$")
          l_contentType="${l_tmpContent%%:*}"
          sed -i "s/${l_tmpContent//\//\\\/}/${l_contentType//\//\\\/}: ${l_curChartVersion}/g" "${l_file}"

          info "从外部镜像拷贝${l_file##*/}文件到当前镜像的templates目录中"
          cp -f "${l_file}" "${l_templateDir}/"
        fi

      done
      ((l_i = l_i + 1))
      ((l_index = l_index + 1))
    done
  fi
  gDefaultRetVal="${l_index}"
}

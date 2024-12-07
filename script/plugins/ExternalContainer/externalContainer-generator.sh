#!/usr/bin/env bash

function externalContainerGenerator_default() {
  export gDefaultRetVal
  export gBuildPath

  local l_generatorFile=$1
  local l_resourceType=$2
  local l_generatorName=$3
  local l_valuesYaml=$4
  local l_index=$5
  local l_configPath=$6

  local l_externalChartImages
  local l_externalChartImage

  if [ "${l_resourceType}" != "ExternalContainer" ];then
    #返回是否已处理了该资源
    gDefaultRetVal="false"
    return
  fi

  #检查并插入应用的外部镜像中的容器。
  readParam "${l_valuesYaml}" "${l_configPath}"
  if [[ "${gDefaultRetVal}" && "${gDefaultRetVal}" != "null" ]];then
    # shellcheck disable=SC2206
    l_externalChartImages=(${gDefaultRetVal//,/ })
    # shellcheck disable=SC2068
    for l_externalChartImage in ${l_externalChartImages[@]};do
      [[ "${l_externalChartImage}" =~ ^(\./) ]] && l_externalChartImage="${gBuildPath}${l_externalChartImage:2}"
      info "正在处理引用的外部Chart镜像中的容器：${l_externalChartImage}"
      #将外部Chart镜像中values.yaml文件中的params.deployment0配置节复制到l_valuesYaml文件中。
      #并将外部chart镜像中deployment[0]的initialContainers和containers合并到当前chart的deployment0中。
      _combineExternalContainer "${l_valuesYaml}" "${l_externalChartImage}" "${l_index}"
    done
  fi

  gDefaultRetVal="true"
}

#*********************************私有方法************************************#


#将外部Chart镜像中values.yaml文件中的params.deployment0配置节复制到l_valuesYaml文件中。
#并将外部chart镜像中deployment[0]的initContainers和containers合并到当前chart的deployment0中。
#最后将ConfigMap资源文件复制到当前chart的templates目录中
function _combineExternalContainer() {
  export gDefaultRetVal
  export gTempFileDir
  export gChartRepoInstanceName
  export gChartRepoName
  export gChartRepoAccount
  export gChartRepoPassword
  export gChartRepoType

  local l_valuesYaml=$1
  local l_externalChartImage=$2
  local l_index=$3

  local l_chartName
  local l_chartVersion
  local l_valuesYaml1
  local l_paramPaths
  local l_paramPath
  local l_i

  local l_templatesDir
  local l_fileList
  local l_tmpFile
  local l_content
  local l_path

  #判断l_externalChartImage是否带有路径,如果没有路径，则从gChartRepoInstanceName仓库拉取外部Chart镜像
  if [[ ! "${l_externalChartImage}" =~ ^(.*)/(.*)$ ]];then

    [[ ! "${gChartRepoName}" ]] && \
      error "没有配置Chart镜像仓库，无法拉取${l_externalChartImage}镜像。请指定Chart镜像仓库或${l_externalChartImage}镜像文件所在的本地路径。"
    l_chartVersion="${l_externalChartImage##*-}"
    l_chartVersion="${l_chartVersion%.*}"
    l_chartName="${l_externalChartImage%-*}"
    #拉取指定的chart镜像到gBuildPath目录中。
    pullChartImage "${l_chartName}" "${l_chartVersion}" "${gChartRepoType}" "${gChartRepoName}" \
      "${gChartRepoInstanceName}" "${gTempFileDir}" "${gChartRepoAccount}" "${gChartRepoPassword}"
    l_externalChartImage="${gTempFileDir}/${l_externalChartImage}"
  else
    l_chartName="${l_externalChartImage##*/}"
    l_chartVersion="${l_chartName##*-}"
    l_chartVersion="${l_chartVersion%.*}"
    l_chartName="${l_chartName%-*}"
  fi

  gDefaultRetVal="${l_index}"

  if [ -f "${l_externalChartImage}" ];then
    info "解压外部Chart镜像文件..."
    tar -zxvf "${l_externalChartImage}" -C "${l_externalChartImage%/*}"
    l_valuesYaml1="${l_externalChartImage%/*}/${l_chartName}/values.yaml"
     
    #判断外部镜像是否是wydevops创建的。
    readParam "${l_valuesYaml1}" "image.registry"
    if [ "${gDefaultRetVal}" != "null" ];then
      #外部Chart镜像的values.yaml文件存在"image.registry"参数
      readParam "${l_valuesYaml1}" "gatewayRoute.host"
      if [ "${gDefaultRetVal}" != "null" ];then
        #并且存在gatewayRoute.host参数
        readParam "${l_valuesYaml1}" "deployment0.name"
        if [ "${gDefaultRetVal}" != "null" ];then
          #并且存在deployment0.name参数，则判定该chart镜像是wydevops生成的
          info "调用专用于wydevops生成的Chart镜像的合并方法..."
          _combineExternalContainerCreatedByWydevops "${l_valuesYaml}" "${l_externalChartImage}" "${l_index}" \
            "${l_valuesYaml1}" "${l_chartName}"
        fi
      fi
    fi

    info "删除外部Chart镜像文件和解压出的目录..."
    rm -f "${l_externalChartImage:?}"
    l_path="${l_externalChartImage%/*}"
    rm -rf "${l_path:?}/${l_chartName}"

  fi
}

function _combineExternalContainerCreatedByWydevops() {
  export gDefaultRetVal

  local l_valuesYaml=$1
  local l_externalChartImage=$2
  local l_index=$3
  local l_valuesYaml1=$4
  local l_chartName=$5

  local l_i
  local l_paramPaths
  local l_paramPath

  local l_templatesDir
  local l_fileList
  local l_tmpFile
  local l_content

  local l_array
  local l_paramPathCount
  local l_j
  local l_k
  local l_srcParamPath
  local l_targetParamPath
  local l_indexArray

  ((l_i = 0))
  while true;do
    readRowRange "${l_valuesYaml1}" "deployment${l_i}"
    [[ "${gDefaultRetVal}" =~ ^(\-1) ]] && break

    l_paramPaths=("gatewayRoute.host|gatewayRoute.host" \
      "params.deployment${l_i}|params.deployment${l_index}" \
      "deployment${l_i}.volumes|deployment${l_index}.volumes"
      "deployment${l_i}.initContainers|deployment${l_index}.initContainers" \
      "deployment${l_i}.containers|deployment${l_index}.containers")

    # shellcheck disable=SC2068
    for l_paramPath in ${l_paramPaths[@]};do
      #读取l_valuesYaml1文件中的参数，判断是否存在，不存在则报错。
      readParam "${l_valuesYaml1}" "${l_paramPath%%|*}"
      if [ "${gDefaultRetVal}" == "null" ];then
        warn "外部Chart镜像的${l_valuesYaml1##*/}文件中不存在${l_paramPath%%|*}参数"
        continue
      fi
      [[ ! "${gDefaultRetVal}" ]] && continue
      #合并到l_valuesYaml文件中。
      combine "${l_valuesYaml1}" "${l_valuesYaml}" "${l_paramPath%%|*}" "${l_paramPath#*|}" "true" "false"
    done

    #定义路由参数映射。
    l_paramPaths=("deployment${l_i}.ingressRoute.rules[0].paths|deployment${l_index}.ingressRoute.rules[0].paths" \
          "deployment${l_i}.apisixRoute.routes|deployment${l_index}.apisixRoute.routes")

    #依次获取目标路由参数的当前项数，并保存的l_indexArray数组中。
    l_paramPathCount=${#l_paramPaths[@]}
    for (( l_j = 0; l_j < l_paramPathCount; l_j++ ));do
      l_targetParamPath="${l_paramPaths[${l_j}]}"
      l_targetParamPath="${l_targetParamPath#*|}"
      getListIndexByPropertyName "${l_valuesYaml}" "${l_targetParamPath}" "" "" "true"
      # shellcheck disable=SC2206
      l_array=(${gDefaultRetVal})
      l_indexArray["${l_j}"]="${l_array[1]}"
    done

    #再次循环处理路由参数的读取和赋值。
    for (( l_j = 0; l_j < l_paramPathCount; l_j++ ));do
      ((l_k = 0))
      while true; do
        l_paramPath="${l_paramPaths[${l_j}]}"
        l_srcParamPath="${l_paramPath%%|*}[${l_k}]"
        #读取l_valuesYaml1文件中的参数，判断是否存在，不存在则报错。
        readParam "${l_valuesYaml1}" "${l_srcParamPath}"
        [[ "${gDefaultRetVal}" == "null" ]] && break

        l_targetParamPath="${l_paramPath#*|}[${l_indexArray[${l_j}]}]"
        #合并到l_valuesYaml文件中。
        insertParam "${l_valuesYaml}" "${l_targetParamPath}" "${gDefaultRetVal}"
        #累进l_indexArray[${l_j}]的值。
        ((l_indexArray["${l_j}"] = l_indexArray["${l_j}"] + 1 ))
        ((l_k = l_k + 1))
      done
    done

    ((l_i = l_i + 1))
    ((l_index = l_index + 1))
  done

  #将configMap文件复制到l_valuesYaml文件同名下的templates子目录中
  l_templatesDir="${l_externalChartImage%/*}/${l_chartName}/templates"
  l_fileList=$(find "${l_templatesDir}" -maxdepth 1 -type f -name "*.yaml")
  # shellcheck disable=SC2068
  for l_tmpFile in ${l_fileList[@]};do
    # shellcheck disable=SC2002
    l_content=$(cat "${l_tmpFile}" | grep -oP "^(kind: ConfigMap)$")
    if [ "${l_content}" ];then
      info "将${l_tmpFile##*/}文件复制到${l_valuesYaml%/*}目录中"
      cp -f "${l_tmpFile}" "${l_valuesYaml%/*}/templates"
    fi
  done

  gDefaultRetVal="${l_index}"

}
#!/usr/bin/env bash

#将外部Chart镜像中values.yaml文件中的params.deployment0配置节复制到l_valuesYaml文件中。
#并将外部chart镜像中deployment[0]的initContainers和containers合并到当前chart的deployment0中。
#最后将ConfigMap资源文件复制到当前chart的templates目录中
function onProcessExternalChart_default() {
  export gDefaultRetVal
  export gTempFileDir
  export gChartRepoInstanceName
  export gChartRepoName
  export gChartRepoAccount
  export gChartRepoPassword

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

  #判断l_externalChartImage是否带有路径,如果没有路径，则从gChartRepoInstanceName仓库拉取外部Chart镜像
  if [[ ! "${l_externalChartImage}" =~ ^(.*)/(.*)$ ]];then

    [[ ! "${gChartRepoName}" ]] && \
      error "没有配置Chart镜像仓库，无法拉取${l_externalChartImage}镜像。请指定Chart镜像仓库或${l_externalChartImage}镜像文件所在的本地路径。"
    l_chartVersion="${l_externalChartImage##*-}"
    l_chartVersion="${l_chartVersion%.*}"
    l_chartName="${l_externalChartImage%-*}"
    #拉取指定的chart镜像到gBuildPath目录中。
    pullChartImage "${l_chartName}" "${l_chartVersion}" "${gChartRepoInstanceName}" "${gTempFileDir}"
    l_externalChartImage="${gTempFileDir}/${l_externalChartImage}"
  else
    l_chartName="${l_externalChartImage##*/}"
    l_chartVersion="${l_chartName##*-}"
    l_chartVersion="${l_chartVersion%.*}"
    l_chartName="${l_chartName%-*}"
  fi

  if [ -f "${l_externalChartImage}" ];then
    info "解压外部Chart镜像文件..."
    tar -zxvf "${l_externalChartImage}" -C "${l_externalChartImage%/*}"
    l_valuesYaml1="${l_externalChartImage%/*}/${l_chartName}/values.yaml"

    ((l_i = 0))
    while true;do
      readRowRange "${l_valuesYaml1}" "deployment${l_i}"
      [[ "${gDefaultRetVal}" =~ ^(\-1) ]] && break

      l_paramPaths=("params.deployment${l_i}|params.deployment${l_index}" \
        "deployment${l_i}.volumes|deployment${l_index}.volumes"
        "deployment${l_i}.initContainers|deployment${l_index}.initContainers" \
        "deployment${l_i}.containers|deployment${l_index}.containers" \
        "deployment${l_i}.gatewayRoute.routes|deployment${l_index}.gatewayRoute.routes")

      # shellcheck disable=SC2068
      for l_paramPath in ${l_paramPaths[@]};do
        #读取l_valuesYaml1文件中的参数，判断是否存在，不存在则报错。
        readParam "${l_valuesYaml1}" "${l_paramPath%%|*}"
        if [ "${gDefaultRetVal}" == "null" ];then
          warn "外部Chart镜像的${l_valuesYaml1##*/}文件中不存在${l_paramPath%%|*}参数"
          error "外部Chart镜像${l_externalChartImage##*/}不是使用wydevops生成的。"
        fi
        [[ ! "${gDefaultRetVal}" ]] && continue
        #合并到l_valuesYaml文件中。
        combine "${l_valuesYaml1}" "${l_valuesYaml}" "${l_paramPath%%|*}" "${l_paramPath#*|}" "true" "false"
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

      ((l_i = l_i + 1))
    done
  fi
}

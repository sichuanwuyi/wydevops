#!/usr/bin/env bash

function configMapGenerator_default() {
  export gDefaultRetVal
  export gBuildPath
  export gFileContentMap

  local l_generatorFile=$1
  local l_resourceType=$2
  local l_generatorName=$3
  local l_valuesYaml=$4
  local l_deploymentIndex=$5
  local l_configPath=$6

  local l_templateFile
  local l_targetFile

  local l_configMapName
  local l_configMapFiles
  local l_configFile
  local l_configFileContent
  local l_result
  local l_fileKey

  l_templateFile="${l_generatorFile%/*}/${l_resourceType,}-${l_generatorName}-template.yaml"
  [[ ! -f "${l_templateFile}" ]] && error "目标模板文件不存在：${l_templateFile}"
  # shellcheck disable=SC2145
  info "加载${l_resourceType}模板文件：${l_templateFile##*/}"

  ((l_index = 0))
  while true;do
    readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.configMaps[${l_index}].files"
    [[ "${gDefaultRetVal}" == "null" ]] && break

    if [ ! "${gDefaultRetVal}" ];then
      ((l_index = l_index + 1))
      continue
    fi
    # shellcheck disable=SC2206
    l_configMapFiles=(${gDefaultRetVal//,/ })

    readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.configMaps[${l_index}].name"
    [[ ! "${gDefaultRetVal}" ]] && error "${l_valuesYaml##*/}文件中deployment${l_deploymentIndex}.configMaps[${l_index}].name参数值为空"

    l_configMapName="${gDefaultRetVal}"
    info "正在生成ConfigMap文件：${l_configMapName}"

    l_targetFile="${l_valuesYaml%/*}/templates/${l_configMapName}.yaml"
    cat "${l_templateFile}" > "${l_targetFile}"

    updateParam "${l_targetFile}" "metadata.name" "${l_configMapName}"

    # shellcheck disable=SC2068
    for l_configFile in ${l_configMapFiles[@]};do
      info "正在将${l_configFile##*/}文件写入ConfigMap配置文件中..."
      [[ "${l_configFile}" =~ ^(\./) ]] && l_configFile="${gBuildPath}/${l_configFile:2}"

      [[ ! -f "${l_configFile}" ]] && error "目标配置文件不存在：${l_configFile}"

      #将文件内容插入ConfigMap配置文件中。
      l_configFileContent=$(cat "${l_configFile}")
      l_fileKey="FILE_KEY_${RANDOM}"
      insertParam "${l_targetFile}" "data.${l_fileKey}" "|\n${l_configFileContent}"
      #将内容中的FILE_KEY更新为文件名称。
      l_configFileContent="${gFileContentMap[${l_targetFile}]}"
      l_configFile="${l_configFile##*/}"
      l_result=$(echo -e "${l_configFileContent}" | sed "s/${l_fileKey}/${l_configFile}/g")

      #补丁：替换文件中存在的“`”字符为空串。
      l_result=$(echo -e "${l_result}" | sed "s/\`//g")

      #修改后更新回内存
      gFileContentMap["${l_targetFile}"]="${l_result}"
      #同时回写到文件中
      l_result=$(echo -e "${l_result}" > "${l_targetFile}")
    done

    ((l_index = l_index + 1))
  done

  #返回是否已处理了该资源
  gDefaultRetVal="true"
}
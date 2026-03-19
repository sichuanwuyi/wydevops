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

  #最终确定采用的ApiVersion版本
  [[ -z "${t_apiVersion}" ]] && t_apiVersion="v1"
  info "plugin.common.k8s.api.version" "${l_resourceType}#${t_apiVersion}"

  l_templateFile="${l_generatorFile%/*}/${l_resourceType,}-${l_generatorName}-template.yaml"
  [[ ! -f "${l_templateFile}" ]] && error "configmap.generator.sh.template.file.not.exist" "${l_templateFile}"
  # shellcheck disable=SC2145
  info "configmap.generator.sh.load.template.file" "${l_resourceType}#${l_templateFile##*/}"

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
    [[ ! "${gDefaultRetVal}" ]] && error "configmap.generator.sh.param.empty" "${l_valuesYaml##*/}#${l_deploymentIndex}.configMaps[${l_index}].name"

    l_configMapName="${gDefaultRetVal}"
    info "configmap.generator.sh.generating.configmap" "${l_configMapName}"

    l_targetFile="${l_valuesYaml%/*}/templates/${l_configMapName}.yaml"
    #读取模板文件内容。
    l_content=$(cat "${l_templateFile}")
    #替换模板中的变量。
    eval "l_content=\$(echo -e \"${l_content}\")"
    #将替换后的内容写入配置文件中。
    echo "${l_content}" > "${l_targetFile}"

    updateParam "${l_targetFile}" "metadata.name" "${l_configMapName}"

    # shellcheck disable=SC2068
    for l_configFile in ${l_configMapFiles[@]};do
      info "configmap.generator.sh.writing.file" "${l_configFile##*/}"
      [[ "${l_configFile}" =~ ^(\./) ]] && l_configFile="${gBuildPath}/${l_configFile:2}"

      [[ ! -f "${l_configFile}" ]] && error "configmap.generator.sh.config.file.not.exist" "${l_configFile}"

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
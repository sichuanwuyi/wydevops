#!/usr/bin/env bash

function secretGenerator_default() {
  local l_resourceType=$2
  local l_generatorName=$3
  local l_valuesYaml=$4
  local l_deploymentIndex=$5

  local t_generatorName="${l_generatorName//_/-}"
  local l_targetFile
  local l_secretName

  #最终确定采用的ApiVersion版本
  [[ -z "${t_apiVersion}" ]] && t_apiVersion="v1"
  info "plugin.common.k8s.api.version" "${l_resourceType}#${t_apiVersion}"

  # 生成Java项目中数据源的Secret
  commonGenerator_default "Secret" "${@}"
  l_targetFile="${gDefaultRetVal#*|}"

  #将生成的Chart镜像推送到gChartRepoName仓库中。
  invokeExtendPointFunc "readDSCredentialParams" "secret.generator.sh.read.ds.credential.params" "" \
    "${l_valuesYaml}" "${l_deploymentIndex}"
  if [ "${gDefaultRetVal}" ];then
    #更新l_targetFile文件中data属性的值为gDefaultRetVal。
    updateParam "${l_targetFile}" "data" "${gDefaultRetVal}"

    l_secretName="${l_targetFile##*/}"
    l_secretName="${l_secretName//\.yaml/}"
    invokeExtendPointFunc "insertEnvParamsToValuesYaml" "secret.generator.sh.set.envfrom.params" "" \
      "${l_valuesYaml}" "${l_deploymentIndex}" "${l_secretName}"
  fi
}

function secretGenerator_docker-config() {
  export gDefaultRetVal
  export gDockerRepoName
  export gDockerRepoAccount
  export gDockerRepoPassword

  local l_resourceType=$2
  local l_valuesYaml=$4
  local l_deploymentIndex=$5

  local l_server
  local l_email
  local l_auth

  local l_jsonData
  local l_deploymentName

  #模板中需要的变量以“t_”开头
  local t_dockerConfigJson

  #最终确定采用的ApiVersion版本
  [[ -z "${t_apiVersion}" ]] && t_apiVersion="v1"
  info "plugin.common.k8s.api.version" "${l_resourceType}#${t_apiVersion}"

  l_server="http://${gDockerRepoName}"
  l_email="11372349@qq.com"
  l_auth=$(echo -n "${gDockerRepoAccount}:${gDockerRepoPassword}" | base64 --wrap=0)
  l_auth="${l_auth//Cg==/}"

  l_jsonData="{\"auths\":{\"${l_server}\":{\"username\":\"${gDockerRepoAccount}\",\"password\":\"${gDockerRepoPassword}\",\"email\":\"${l_email}\",\"auth\":\"${l_auth}\"}}}"
  # shellcheck disable=SC2034
  t_dockerConfigJson=$(echo -n "${l_jsonData}" | base64 --wrap=0)

  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.name"
  l_deploymentName="${gDefaultRetVal}"

  #此处检查l_valuesYaml文件中deployment${l_deploymentIndex}.imagePullSecrets[0].name的值。
  readParam "${l_valuesYaml}" "deployment${l_deploymentIndex}.imagePullSecrets[0].name"
  #如果name的值为空串，则更新为${l_deploymentName}-secret。
  [[ ! "${gDefaultRetVal}" ]] && updateParam "${l_valuesYaml}" \
    "deployment${l_deploymentIndex}.imagePullSecrets[0].name" "${l_deploymentName}-secret"
  #如果name属性不存在，则插入该属性并设置其值为${l_deploymentName}-secret。
  [[ "${gDefaultRetVal}" == "null" ]] && insertParam "${l_valuesYaml}" \
    "deployment${l_deploymentIndex}.imagePullSecrets[0].name" "${l_deploymentName}-secret"

  commonGenerator_default "Secret" "${@}"
}
#!/usr/bin/env bash

function secretGenerator_default() {
  export gDefaultRetVal
  export gDockerRepoName
  export gDockerRepoAccount
  export gDockerRepoPassword

  local l_valuesYaml=$4
  local l_deploymentIndex=$5

  local l_server
  local l_email
  local l_auth

  local l_jsonData
  local l_deploymentName

  #模板中需要的变量以“t_”开头
  local t_dockerConfigJson

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
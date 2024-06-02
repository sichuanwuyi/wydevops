#!/usr/bin/env bash

#*********************************************************************#
#注意：文件名称不能修改，调用脚本根据gChartRepoType参数选择匹配的helm-help脚本
#本脚本中推送是通过调用nexus提供的Restful Api接口完成的，没有使用nexus-push插件
#*********************************************************************#

function addHelmRepo() {
  local l_repoAliasName=$1
  local l_repoHostAndPort=$2
  local l_account=$3
  local l_password=$4

  local l_content

  info "先尝试清除本地缓存中已经存在的${l_repoAliasName}仓库..." "-n"
  l_content=$(helm repo remove "${l_repoAliasName}" 2>&1)
  info "清除成功" "*"

  info "再向本地缓存中添加${l_repoAliasName}仓库信息..." "-n"
  #如果指定了Chart仓库，则需要先登录Chart仓库，为后续Chart镜像推送做准备。
  l_content=$(helm repo add "${l_repoAliasName}" "http://${l_repoHostAndPort}/repository/${l_repoAliasName}/" --username "${l_account}" --password "${l_password}" 2>&1)
  l_content=$(echo "${l_content}" | grep -ioP "^.*(Error|failed).*$")
  if [ "${l_content}" ];then
    error "添加失败" "*"
  else
    info "添加成功" "*"
  fi

}

function pushChartImage() {
  local l_chartFile=$1
  local l_repoInstanceName=$2
  local l_repoHostAndPort=$3
  local l_account=$4
  local l_password=$5

  local l_tmpFile
  local l_imageName
  local l_imageVersion
  local l_result
  local l_id
  local l_errorLog

  l_tmpFile="${l_chartFile##*/}"
  l_imageName="${l_tmpFile%-*}"
  l_imageVersion="${l_chartFile##*-}"
  l_imageVersion="${l_imageVersion%.*}"

  info "在chart仓库中查找现存的${l_imageName}(${l_imageVersion})镜像..."
  echo "curl -X 'GET' -H 'accept: application/json' http://${l_repoHostAndPort}/service/rest/v1/search?repository=${l_repoInstanceName}&name=${l_imageName}&version=${l_imageVersion}"
  l_result=$(curl -X 'GET' -H 'accept: application/json' \
    "http://${l_repoHostAndPort}/service/rest/v1/search?repository=${l_repoInstanceName}&name=${l_imageName}&version=${l_imageVersion}" 2>&1)
  l_result=$(echo -e "${l_result}" | grep -m 1 -oP "^([ ]*)\"id\" : (.*)$")
  if [ "${l_result}" ];then
    l_id="${l_result#*:}"
    l_id="${l_id%\"*}"
    l_id="${l_id/\"/}"
    l_id="${l_id// /}"
    info "找到了目标镜像，开始清除..."
    echo "curl -X 'DELETE' -H 'accept: application/json' http://${l_repoHostAndPort}/service/rest/v1/components/${l_id}"
    l_result=$(curl -X 'DELETE' -H 'accept: application/json' "http://${l_repoHostAndPort}/service/rest/v1/components/${l_id}" 2>&1)
    info "目标镜像清除成功"
  else
    warn "目标镜像不存在"
  fi

  l_tmpFile="chart-push-${RANDOM}.tmp"
  registerTempFile "${l_tmpFile}"

  info "开始推送chart镜像到仓库中..."
  curl -v -F file=@"${l_chartFile}" -u "${l_account}":"${l_password}" \
    "http://${l_repoHostAndPort}/service/rest/v1/components?repository=${l_repoInstanceName}" 2>&1 | tee "${l_tmpFile}"
  l_result=$(cat "${l_tmpFile}")
  l_errorLog=$(echo -e "${l_result}" | grep -ioP "^(.*)(Error|Failed)(.*)$")
  if [ "${l_errorLog}" ];then
    error "chart镜像推送失败：\n${l_result}"
  else
    info "chart镜像推送成功"
  fi

  unregisterTempFile "${l_tmpFile}"
}

function pullChartImage() {
  local l_chartName=$1
  local l_chartVersion=$2
  local l_repoAliasName=$3
  local l_destination=$4

  local l_errorLog

  if [ ! -d "${l_destination}" ];then
    mkdir -p "${l_destination}"
  fi

  #更新本地库
  echo "helm repo update"
  helm repo update

  #拉取Chart镜像
  echo "helm pull ${l_repoAliasName}/${l_chartName} --destination ${l_destination} --version ${l_chartVersion}"
  l_errorLog=$(helm pull "${l_repoAliasName}/${l_chartName}" --destination "${l_destination}" --version "${l_chartVersion}" 2>&1)
  l_errorLog=$(echo -e "${l_errorLog}" | grep -ioP "^(.*)(Error|failed)(.*)$")
  if [ "${l_errorLog}" ];then
    error "从${l_repoAliasName}镜像仓库拉取Chart镜像失败:${l_errorLog}"
  fi
}
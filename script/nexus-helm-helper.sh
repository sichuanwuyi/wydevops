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
  local l_repoAliasName=$2
  local l_repoHostAndPort=$3
  local l_account=$4
  local l_password=$5

  curl -v -F file=@"${l_chartFile}" -u "${l_account}":"${l_password}" \
    http://"${l_repoHostAndPort}"/service/rest/v1/components?repository="${l_repoAliasName}"
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
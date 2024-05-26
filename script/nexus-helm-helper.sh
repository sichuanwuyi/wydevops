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

  #如果指定了Chart仓库，则需要先登录Chart仓库，为后续Chart镜像推送做准备。
  l_content=$(helm repo add "${l_repoAliasName}" "http://${l_repoHostAndPort}/repository/${l_repoAliasName}/" --username "${l_account}" --password "${l_password}" 2>&1)
  l_content=$(echo "${l_content}" | grep -ioP "^.*(Error|failed).*$")
  if [ "${l_content}" ];then
   l_content=$(echo "${l_content}" | grep -oP 'already exists')
   if [ ! "${l_content}" ];then
     error "执行命令(helm repo add ${l_repoAliasName} http://${l_account}:${l_password}@${l_repoHostAndPort}/repository/${l_repoAliasName}/)失败"
   else
     info "成功执行命令(helm repo add ${l_repoAliasName} http://${l_account}:${l_password}@${l_repoHostAndPort}/repository/${l_repoAliasName}/)"
   fi
  fi
}

function pushChartImage() {
  local l_chartFile=$1
  local l_repoAliasName=$2
  local l_repoHostAndPort=$3
  local l_account=$4
  local l_password=$5

  curl -v -F file=@"${l_chartFile}" -u "${l_account}":"${l_password}" http://"${l_repoHostAndPort}"/service/rest/v1/components?repository="${l_repoAliasName}"
}
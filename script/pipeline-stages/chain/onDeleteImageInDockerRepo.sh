#!/usr/bin/env bash

function onDeleteImageInDockerRepo_nexus() {
  export gDefaultRetVal
  export gDockerRepoType
  export gDockerRepoName
  export gDockerRepoInstanceName
  export gDockerRepoWebPort

  local l_image=$1

  local l_imageName
  local l_imageVersion
  local l_result
  local l_id

  if [ "${gDockerRepoType}" != "nexus" ];then
    gDefaultRetVal="false|"
    return
  fi

  l_imageName="${l_image%:*}"
  l_imageVersion="${l_image##*:}"

  info "在docker仓库中查找现存的${l_imageName}:${l_imageVersion}镜像..."
  echo "curl -X 'GET' -H 'accept: application/json' http://${gDockerRepoName%%:*}:${gDockerRepoWebPort}/service/rest/v1/search?repository=${gDockerRepoInstanceName}&name=${l_imageName}&version=${l_imageVersion}"
  l_result=$(curl -X 'GET' -H 'accept: application/json' \
    "http://${gDockerRepoName%%:*}:${gDockerRepoWebPort}/service/rest/v1/search?repository=${gDockerRepoInstanceName}&name=${l_imageName}&version=${l_imageVersion}" 2>&1)
  l_result=$(echo -e "${l_result}" | grep -m 1 -oP "^([ ]*)\"id\" : (.*)$")
  if [ "${l_result}" ];then
    l_id="${l_result#*:}"
    l_id="${l_id%\"*}"
    l_id="${l_id/\"/}"
    l_id="${l_id// /}"
    info "找到了目标镜像，开始清除..."
    echo "curl -X 'DELETE' -H 'accept: application/json' http://${gDockerRepoName%%:*}:${gDockerRepoWebPort}/service/rest/v1/components/${l_id}"
    l_result=$(curl -X 'DELETE' -H 'accept: application/json' "http://${gDockerRepoName%%:*}:${gDockerRepoWebPort}/service/rest/v1/components/${l_id}" 2>&1)
    info "目标镜像清除成功"
  else
    warn "目标镜像不存在"
  fi

}
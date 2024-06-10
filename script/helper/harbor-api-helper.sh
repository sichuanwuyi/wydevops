#!/usr/bin/env bash

#在指定的项目中是否存在目标镜像。
function existRepositoryInHarborProject() {
  export gDefaultRetVal

  local l_dockerRepoHostAndPort=$1
  local l_projectName=$2
  local l_imageFullName=$3
  local l_imageVersion=$4

  local l_imageName
  local l_result
  local l_errorLog

  l_imageName="${l_imageFullName##*/}"

  gDefaultRetVal="false"

  l_result=$(curl -X 'GET' -H 'accept: application/json' \
    "http://${l_dockerRepoHostAndPort}/api/v2.0/projects/${l_projectName}/repositories/${l_imageName}/artifacts/${l_imageVersion}?page=1&page_size=10&with_tag=true&with_label=false&with_scan_overview=false&with_sbom_overview=false&with_accessory=false&with_signature=false&with_immutable_status=false" 2>&1)
  l_errorLog=$(echo -e "${l_result}" | grep -oP "errors")
  [[ ! "${l_errorLog}" ]] && gDefaultRetVal="true"
}

function deleteRepositoryInHarborProject() {
  export gDefaultRetVal

  local l_dockerRepoHostAndPort=$1
  local l_projectName=$2
  local l_imageFullName=$3
  local l_imageVersion=$4
  local l_dockerRepoAccount=$5
  local l_dockerRepoPassword=$6

  local l_imageName
  local l_result
  local l_errorLog

  l_imageName="${l_imageFullName##*/}"

  gDefaultRetVal="false"

  l_result=$(curl -X 'DELETE' -H 'accept: application/json' -u "${l_dockerRepoAccount}:${l_dockerRepoPassword}" \
    "http://${l_dockerRepoHostAndPort}/api/v2.0/projects/${l_projectName}/repositories/${l_imageName}/artifacts/${l_imageVersion}" 2>&1)
  l_errorLog=$(echo -e "${l_result}" | grep -oP "errors")
  [[ "${l_errorLog}" ]] && error "删除仓库中现有的同名同版本的镜像失败: ${l_result}"

  gDefaultRetVal="true"

}

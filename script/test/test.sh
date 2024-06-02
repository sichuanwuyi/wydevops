#!/usr/bin/env bash

# shellcheck disable=SC2164
_selfRootDir=$(cd "$(dirname "$0")"; pwd)

_selfRootDir="${_selfRootDir//test/}"

#2.导入yaml函数库文件、向外发送通知的库文件。
# shellcheck disable=SC1090
source "${_selfRootDir}yaml-helper.sh"

export gDefaultRetVal
export gEnableCache="true"

#定义测试文件名称。
tmpFile="${_selfRootDir}test/test.yaml"
tmpFile1="${_selfRootDir}test/ci-cd.yaml"

function readAndWriteKVPair() {
  local testName=$1
  local nameValues=$2
  local paramArray
  local paramItem
  local paramName
  local paramValue

  warn "${testName} 测试开始...."

  # shellcheck disable=SC2206
  paramArray=(${nameValues})
  # shellcheck disable=SC2068
  for paramItem in ${paramArray[@]};do
    paramName="${paramItem%%|*}"
    paramValue="${paramItem#*|}"
    info "执行插入方法：insertParam ${tmpFile##*/} ${paramName} ${paramValue} ..." "-n"
    insertParam "${tmpFile}" "${paramName}" "${paramValue}"
    if [[ "${gDefaultRetVal}" =~ ^(-1) ]];then
      error "失败" "*"
    else
      info "成功:${gDefaultRetVal}" "*"
      info "执行读取方法：readParam ${tmpFile##*/} ${paramName} ..." "-n"
      readParam "${tmpFile}" "${paramName}"
      if [ "${gDefaultRetVal}" != "${paramValue}" ];then
        error "读取验证失败(返回值与预期值不等)：${gDefaultRetVal} != ${paramValue}"
      else
        info "读取验证成功: ${gDefaultRetVal}" "*"
      fi
    fi
  done

}

function readAndWriteList() {
  local testName=$1

  local l_item="name: aaa
value: 123"
  local paramName="list[0]"

  warn "${testName} 测试开始...."

  info "列表项测试用例：\n${l_item}"

  info "插入列表项：insertParam ${tmpFile##*/} ${paramName} \${测试用例}..." "-n"
  insertParam "${tmpFile}" "${paramName}" "${l_item}"
  if [[ "${gDefaultRetVal}" =~ ^(-1) ]];then
    error "失败" "*"
  else
    info "成功:${gDefaultRetVal}" "*"
    info "执行读取方法：readParam ${tmpFile##*/} ${paramName}.name ..." "-n"
    readParam "${tmpFile}" "${paramName}.name"
    if [ "${gDefaultRetVal}" != "aaa" ];then
      error "读取验证失败(返回值与预期值不等)：${gDefaultRetVal} != aaa"
    else
      info "读取验证成功: ${gDefaultRetVal}" "*"
    fi
  fi

  local l_paramValue="test_name"
  info "更新第一个列表项的name属性值为${l_paramValue}"
  info "更新列表项：updateParam ${tmpFile##*/} ${paramName}.name ${l_paramValue}..." "-n"
  updateParam "${tmpFile}" "${paramName}.name" "${l_paramValue}"
  if [[ "${gDefaultRetVal}" =~ ^(-1) ]];then
    error "失败" "*"
  else
    info "成功:${gDefaultRetVal}" "*"
    info "执行读取方法：readParam ${tmpFile##*/} ${paramName}.name ..." "-n"
    readParam "${tmpFile}" "${paramName}.name"
    if [ "${gDefaultRetVal}" != "test_name" ];then
      error "读取验证失败(返回值与预期值不等)：${gDefaultRetVal} != ${paramValue}"
    else
      info "读取验证成功: ${gDefaultRetVal}" "*"
    fi
  fi

}

#确保文件不存在
rm -f "${tmpFile}"

#readAndWriteKVPair "简单键值对读写" "test|AAA test.test1|BBB test.test2|CCC test.test1.test3|DDD"
#readAndWriteKVPair "简单KV键值对列表类读写" "test.test1.test3[0].name|DDD test.test1.test3[0]| test.test1.test3[0].name|kkk test.test1.test3[0].value|vvvv"
#
#readAndWriteList "列表项读写"

#helm uninstall devops-test -n develop --kubeconfig /e/tmt/test/deploy/kube-config
#helm uninstall devops-test1 -n develop --kubeconfig /e/tmt/test/deploy/kube-config
#helm uninstall atom-hardware-manager -n develop --kubeconfig /e/tmt/test/deploy/kube-config

info "开始清除docker仓库中现有的同名同版本的镜像..."
l_result=$(curl -X 'GET' -H 'accept: application/json' \
  "http://192.168.31.214:8081/service/rest/v1/search?repository=registry.docker.home&name=devops-test1&version=1.0.1" 2>&1)
echo "-------${l_result}---"
l_result=$(echo -e "${l_result}" | grep -m 1 -oP "^([ ]*)\"id\" : (.*)$")
if [ "${l_result}" ];then
  l_id="${l_result#*:}"
  l_id="${l_id%\"*}"
  l_id="${l_id/\"/}"
  l_id="${l_id// /}"

#  l_result=$(curl -X 'DELETE' -H 'accept: application/json' \
#    "http://${gDockerRepoName%%:*}:${gDockerRepoWebPort}/service/rest/v1/components/${l_id}" 2>&1)
  info "目标镜像清除成功:${l_id}"
else
  warn "目标镜像不存在"
fi
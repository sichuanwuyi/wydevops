#!/usr/bin/env bash

# shellcheck disable=SC2164
_selfRootDir=$(cd "$(dirname "$0")"; pwd)

_selfRootDir="${_selfRootDir//test/}"

#2.导入yaml函数库文件、向外发送通知的库文件。
# shellcheck disable=SC1090
source "${_selfRootDir}/helper/yaml-helper.sh"

export gDefaultRetVal

#定义测试文件名称。
tmpFile="./ci-cd.yaml"
tmpFile1="./ci-cd1.yaml"

deleteParam "${tmpFile1}" "params.items"
combine "${tmpFile}" "${tmpFile1}" "params.items" "params.items" "true"
echo "---1----gDefaultRetVal-----|${gDefaultRetVal}|"

#fileContent=$(cat "${tmpFile}")

#readParam "${tmpFile}" "image.nodes[1]"
#updateParam "${tmpFile}" "image.registry" "docker.io"
#echo "-------gDefaultRetVal-----${gDefaultRetVal}"
#
#deleteParam "${tmpFile}" "server.info"
#echo "-------gDefaultRetVal-----${gDefaultRetVal}"
#
#readParam "${tmpFile}" "image.nodes[2]"
#echo "-------gDefaultRetVal-----${gDefaultRetVal}"
#
#updateParam "${tmpFile}" "image.nodes[1]"  "192.168.1.111"
#echo "-------gDefaultRetVal-----${gDefaultRetVal}"
#
#deleteParam "${tmpFile}" "image.nodes[3]"
#echo "-------gDefaultRetVal-----${gDefaultRetVal}"
#
#insertParam "${tmpFile}" "image.nodes[5]"  "192.168.1.133"
#echo "-------gDefaultRetVal-----${gDefaultRetVal}"
#
#insertParam "${tmpFile}" "server.nodes[1]"  "ip: 192.168.1.100\nport: 9999"
#echo "-------gDefaultRetVal-----${gDefaultRetVal}"
#
#updateParam "${tmpFile}" "server.nodes[2]"  "ip: 192.168.1.100\nport: AAAA"
#echo "-------gDefaultRetVal-----${gDefaultRetVal}"
#
#insertParam "${tmpFile}" "server.nodes[3]"  "ip: 192.168.1.100\nport: 8888"
#echo "-------gDefaultRetVal-----${gDefaultRetVal}"
#
##insertParam "${tmpFile}" "server.info" "|\nappName: dddd\nappVersion: 1.0.0\nappType: web"
#
#insertParam "${tmpFile}" "server.info[0]" "appName: dddd\nappVersion: 1.0.0\nappType: web"

#tmpFile1="./ci-cd-config.yaml"
#tmpFile2="./_ci-cd-template.yaml"
#
#combine "${tmpFile1}" "${tmpFile2}" "" "" "true" "true"
#!/usr/bin/env bash

# shellcheck disable=SC2164
_selfRootDir=$(cd "$(dirname "$0")"; pwd)

_selfRootDir="${_selfRootDir//test/}"

#2.导入yaml函数库文件、向外发送通知的库文件。
# shellcheck disable=SC1090
source "${_selfRootDir}/helper/yaml-helper.sh"

export gDefaultRetVal

#定义测试文件名称。
tmpFile="${_selfRootDir}test/my-test.yaml"

insertParam "${tmpFile}" "test.content" "This is a test"
echo "----gDefaultRetVal=${gDefaultRetVal}---"
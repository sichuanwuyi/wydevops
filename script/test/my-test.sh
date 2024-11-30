#!/usr/bin/env bash

# shellcheck disable=SC2164
_selfRootDir=$(cd "$(dirname "$0")"; pwd)

_selfRootDir="${_selfRootDir//test/}"

#2.导入yaml函数库文件、向外发送通知的库文件。
# shellcheck disable=SC1090
source "${_selfRootDir}/helper/yaml-helper.sh"

export gDefaultRetVal

#定义测试文件名称。
tmpFile="/d/react/react-next-app/react-next-app-demo/nextjs-dashboard/ci-cd.yaml"

#readParam "${tmpFile}" "chart[0].deployments[0].name"
#readParam "${tmpFile}" "destination" "" 467 470 14 0 false 0 true

updateParam "${tmpFile}" "chart[0].deployments[0].name" "- a: 1\n  b: 2\n- c: 3\n  d: 4"
updateParam "${tmpFile}" "chart[0].deployments[0].name[0]" "a"
updateParam "${tmpFile}" "chart[0].deployments[0].name[1]" "b"

echo "----gDefaultRetVal=${gDefaultRetVal}---"
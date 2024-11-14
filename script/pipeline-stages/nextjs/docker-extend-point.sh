#!/usr/bin/env bash

function _onBeforeCreatingDockerImage_ex() {
  export gBuildPath
  export gDockerBuildDir

  local l_dockerfile=$3
  local l_rowNumber
  local l_content
  local l_distDir

  #默认项目静态资源存放在public目录下。
  #从next.config.ts文件中读取distDir参数的值,默认值为distDir。
  l_distDir=".next"
  # shellcheck disable=SC2002
  l_content=$(cat "${gBuildPath}/next.config.ts" | grep -noP "^(.*):[ ]*NextConfig[ ]*=[ ]*\{[ ]*$")
  if [ "${l_content}" ];then
    l_rowNumber=${l_content%%:*}
    l_content=$(awk "NR==${l_rowNumber},NR==-1" "${gBuildPath}/next.config.ts" | grep -m 1 -oP "^[ ]*distDir:.*$")
    if [ "${l_content}" ];then
      l_content="${l_content##*:}"
      l_content=$(echo -e "${l_content}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      l_content="${l_content%,*}"
      l_content="${l_content//\'/}"
      l_content="${l_content//\"/}"
      l_distDir="${l_content}"
    fi
  fi

  if [[ "${l_dockerfile}" =~ ^(.*)_base$ ]];then
    cp -f "${gBuildPath}"/.env* "${gDockerBuildDir}/"
    cp -f "${gBuildPath}/pnpm-lock.yaml" "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.ts "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.js "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.json "${gDockerBuildDir}/"
  elif [[ "${l_dockerfile}" =~ ^(.*)_business$ ]];then
    cp -rf "${gBuildPath}/public" "${gDockerBuildDir}/"
    cp -rf "${gBuildPath}/${l_distDir}" "${gDockerBuildDir}/"
  else
    cp -rf "${gBuildPath}/public" "${gDockerBuildDir}/"
    cp -rf "${gBuildPath}/${l_distDir}" "${gDockerBuildDir}/"
    cp -f "${gBuildPath}"/.env* "${gDockerBuildDir}/"
    cp -f "${gBuildPath}/pnpm-lock.yaml" "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.ts "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.js "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.json "${gDockerBuildDir}/"
  fi
}
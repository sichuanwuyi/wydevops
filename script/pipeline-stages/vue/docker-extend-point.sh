#!/usr/bin/env bash

function _onAfterInitialingGlobalParamsForDockerStage_ex() {
  export gDefaultRetVal
  export gDockerFileTemplateParamMap

  local l_publicPath

  #获取vue项目vue.config.js文件中distDir参数的值。
  getParamValueInJsonConfigFile "${gBuildPath}/vue.config.js" "^(.*)=[ ]*defineConfig\([ ]*\{[ ]*$" "publicPath" "" "false"
  l_publicPath="${gDefaultRetVal}"
  if [[ "${l_publicPath}" ]];then
    [[ "${l_publicPath}" == "/" ]] && l_publicPath=""
    [[ ! ("${l_publicPath}" =~ ^/(.*)$) ]] && l_publicPath="/${l_publicPath}"
  fi
  gDockerFileTemplateParamMap["_PUBLIC-PATH_"]="${l_publicPath}"

}

function _onBeforeCreatingDockerImage_ex() {
  export gBuildPath
  export gDockerBuildDir
  export gDefaultRetVal
  export gWorkDirInDocker
  export gExposePorts

  local l_dockerfile=$3

  local l_flag
  # shellcheck disable=SC2002
  l_flag=$(grep -oE "^(.*)--from=(.*)$" "${l_dockerfile}")
  if [ "${l_flag}" ];then
    cp -rf "${gBuildPath}/src" "${gDockerBuildDir}/"
    cp -rf "${gBuildPath}/public" "${gDockerBuildDir}/"
    cp -f "${gBuildPath}/pnpm-lock.yaml" "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.js "${gDockerBuildDir}/"
    cp "${gBuildPath}"/*.json "${gDockerBuildDir}/"
  else
    cp -rf "${gBuildPath}/dist" "${gDockerBuildDir}/dist"
  fi

  echo "
server {
    listen       ${gExposePorts};
    server_name  localhost;

    #charset koi8-r;
    access_log  /var/log/nginx/host.access.log  main;
    error_log  /var/log/nginx/error.log  error;

    location / {
        root   ${gWorkDirInDocker};
        index  index.html index.htm;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   ${gWorkDirInDocker};
    }
}" > "${gDockerBuildDir}/default.conf"

}
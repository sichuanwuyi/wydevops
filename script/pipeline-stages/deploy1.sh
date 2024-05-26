#!/usr/bin/env bash

function deployClusterNodes() {
  export gChartRepoAliasName
  export gChartAppName
  export gChartVersion
  export gDockerRepoName
  export gChartRepoName
  export gDevGatewayHosts
  export gDevNamespace
  export gCustomizedSetParams

  local l_namespaceArray
  local l_namespace
  local l_errorLog
  local l_size
  local l_devGatewayHosts
  local l_devGatewayHost
  local i

  echo "helm repo add ${gChartRepoAliasName} http://${gChartRepoName} || true"
  helm repo add "${gChartRepoAliasName}" "http://${gChartRepoName}" || true

  # shellcheck disable=SC2206
  l_devGatewayHosts=(${gDevGatewayHosts//,/ })

  # shellcheck disable=SC2206
  l_namespaceArray=(${gDevNamespace//,/ })
  l_size="${#l_namespaceArray[@]}"
  for ((i=0; i<l_size; i++)) do
    l_namespace=${l_namespaceArray[${i}]}
    l_devGatewayHost=${l_devGatewayHosts[${i}]}

    echo "将应用发布到${l_namespace}命名空间中..."
    #调用自定义Set参数扩展点
    onCustomizedSetParams_ex "${l_namespace}"

    #先卸载现有的服务，再安装新版的服务。
    # shellcheck disable=SC2029
    echo "--- helm uninstall ${gChartAppName} -n ${l_namespace}"
    helm uninstall "${gChartAppName}" -n "${l_namespace}" || true

    if [ "${l_devGatewayHost}" ];then
      echo "---helm repo update && helm install ${gChartAppName} ${gChartRepoAliasName}/${gChartAppName} --version ${gChartVersion} --set devGatewayHosts=${l_devGatewayHost} --set registry.hostname=${gDockerRepoName} ${gCustomizedSetParams} -n ${l_namespace} --create-namespace | tee deploy.tmp "
      helm repo update 2>&1 && helm install "${gChartAppName}" "${gChartRepoAliasName}/${gChartAppName}" --version "${gChartVersion}" --set devGatewayHosts="${l_devGatewayHost}" --set registry.hostname="${gDockerRepoName}" ${gCustomizedSetParams} -n "${l_namespace}" --create-namespace 2>&1 | tee deploy.tmp
    else
      echo "---helm repo update && helm install ${gChartAppName} ${gChartRepoAliasName}/${gChartAppName} --version ${gChartVersion} --set registry.hostname=${gDockerRepoName} ${gCustomizedSetParams} -n ${l_namespace} --create-namespace | tee deploy.tmp "
      helm repo update 2>&1 && helm install "${gChartAppName}" "${gChartRepoAliasName}/${gChartAppName}" --version "${gChartVersion}" --set registry.hostname="${gDockerRepoName}" ${gCustomizedSetParams} -n "${l_namespace}" --create-namespace 2>&1 | tee deploy.tmp
    fi

    # shellcheck disable=SC2002
    l_errorLog=$(cat "deploy.tmp" | grep -oP "^.*(Error|failed).*$")
    if [ ! "${l_errorLog}" ];then
      progressNotify "应用${gChartAppName}:${gChartVersion}已成功发布到开发集群${l_namespace}命名空间中"
    else
      progressNotify "应用${gChartAppName}:${gChartVersion}发布失败：${l_errorLog}"
    fi

  done

  rm -f "deploy.tmp" || true
}

function loadConfigFromInfoYamlForDeploy() {
  local l_pageYamlFile=$1

  export gCiCdYamlFileName
  export gChartAppName
  export gChartVersion
  export gNamespace

  export gChartRepoAliasName="chartmuseum"

  local l_value

  if [ ! "${gChartAppName}" ];then
    l_value=$(readContentFromYamlFile "${l_pageYamlFile}" "packages[0].chartName" "readRow")
    if [ "${l_value}" != "null" ];then
      gChartAppName=$(readPropertyValue "${l_value}" "chartName")
      #为发布管理平台通知接口准备的参数gServiceName。
      gChartAppName="${gChartAppName}"
      if [ ! "${gChartAppName}" ];then
        echo "${l_pageYamlFile##*/}文件中未定义参数：packages[0].chartName"
        exit 1
      fi
    fi
  fi

  if [ ! "${gChartVersion}" ];then
    l_value=$(readContentFromYamlFile "${l_pageYamlFile}" "packages[0].chartVersion" "readRow")
    if [ "${l_value}" != "null" ];then
      gChartVersion=$(readPropertyValue "${l_value}" "chartVersion")
      if [ ! "${gChartVersion}" ];then
        echo "${l_pageYamlFile##*/}文件中未定义参数：packages[0].chartVersion"
        exit 1
      fi
    fi
  fi

  if [ ! "${gNamespace}" ];then
    l_value=$(readContentFromYamlFile "${l_pageYamlFile}" "packages[0].namespace" "readRow")
    if [ "${l_value}" != "null" ];then
      gNamespace=$(readPropertyValue "${l_value}" "namespace")
      if [ ! "${gNamespace}" ];then
        echo "${l_pageYamlFile##*/}文件中未定义参数：packages[0].namespace"
        exit 1
      fi
    fi
  fi
}

#-------------------加载扩展点脚本文件-------------------#

export gPipelineScriptsDir
export gLanguage

#项目自定义的Set参数
export gCustomizedSetParams=""

#导入扩展点脚本
# shellcheck disable=SC1090

source "${gPipelineScriptsDir}/${gLanguage}/deploy-extend-point.sh"

#--------------------初始化全局参数----------------------------#
export gChartBuildDir
export gPageYamlFile="${gChartBuildDir}/package.yaml"

echo "--- gPageYamlFile=${gChartBuildDir}/package.yaml"
##从gChartBuildDir目录下的package.yaml文件中读取Deploy构建需要的参数
loadConfigFromInfoYamlForDeploy "${gPageYamlFile}"

#-------------------部署主流程--------------------------#

#发布到集群节点上。
deployClusterNodes
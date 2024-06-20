#!/usr/bin/env bash

export gBuildScriptRootDir
export gBuildPath

##echo "shell-deploy----------${PWD}--------${gBuildScriptRootDir}"
##
##cp -rf script/pipeline-stages "${gBuildScriptRootDir}/"
##cp -rf script/templates "${gBuildScriptRootDir}/"
##cp -f script/*.sh "${gBuildScriptRootDir}/"
#
##在jenkins代理节点中安装helm和helm cm-push
#archType="arm64"
#archInfo=$(arch | grep "x86")
#if [ "${archInfo}" ];then
#  archType="amd64"
#fi
#
#echo "-------system arch type is ${archType}-------------"
#
#if [ ! -f "/usr/bin/helm" ];then
#  echo "-------  cp -f ${gBuildScriptRootDir}/tools/${archType}/helm /usr/bin/"
#  cp -f "${gBuildScriptRootDir}/tools/${archType}/helm" "/usr/bin/"
#  echo "-------  chmod +x /usr/bin/helm"
#  chmod +x /usr/bin/helm
#fi
#
#if [ ! -d "/root/.local/share/helm/plugins/helm-push" ];then
#  mkdir -p "/root/.local/share/helm/plugins" || true
#  echo "-------  cp -rf ${gBuildScriptRootDir}/tools/${archType}/helm-push /root/.local/share/helm/plugins/helm-push"
#  cp -rf "${gBuildScriptRootDir}/tools/${archType}/helm-push" "/root/.local/share/helm/plugins/"
#  echo "-------  chmod +x /root/.local/share/helm/plugins/helm-push/bin/helm-cm-push"
#  chmod +x /root/.local/share/helm/plugins/helm-push/bin/helm-cm-push
#fi
#
#if [ ! -f "/usr/bin/kubectl" ];then
#  echo "-------  cp -f ${gBuildScriptRootDir}/tools/${archType}/kubectl /usr/bin/"
#  cp -f "${gBuildScriptRootDir}/tools/${archType}/kubectl" "/usr/bin/"
#  echo "-------  chmod +x /usr/bin/kubectl"
#  chmod +x /usr/bin/kubectl
#fi
#
##---------复制~/.kube/config-------------#
## shellcheck disable=SC2088
#rm -rf "/root/.kube" || true
## shellcheck disable=SC2088
#mkdir -p "/root/.kube" || true
## shellcheck disable=SC2088
#kubeConfig="/root/.kube/config"
#echo "-------  cp -f ${gBuildScriptRootDir}/tools/config ${kubeConfig}"
#cp -f "${gBuildScriptRootDir}/tools/config" "${kubeConfig}"

#-------------注册域名：rancher.atomdata.com--------#
# shellcheck disable=SC2002
#hostName=$(cat "/etc/hosts" | grep "rancher.atomdata.com")
#if [ ! "${hostName}" ];then
#  # shellcheck disable=SC2028
#  echo "echo -e \n${DEPLOY_TARGET_NODES}  rancher.atomdata.com >> /etc/hosts"
#  echo -e "\n${DEPLOY_TARGET_NODES}  rancher.atomdata.com" >> "/etc/hosts"
#fi

echo "wydevops部署成功"


#!/usr/bin/env bash

function sendNotify_ex() {
  export gDefaultRetVal
  export gEnableNotify

  if [ "${gEnableNotify}" != "true" ];then
    return
  fi

  export gHelmBuildDir
  export gServiceCode
  export gExternalNotifyUrl

  local l_content
  local l_tmpFile
  local l_errorContent
  local l_errorFlag
  local l_maxTryCount=3
  local l_i

  if [ ! "${gExternalNotifyUrl}" ];then
    warn "common.notify.extend.point.external.notify.url.is.empty"
    return
  fi

  # shellcheck disable=SC2124
  l_content="${@}"
  if [ ! "${l_content}" ];then
    error "common.notify.extend.point.notify.content.cannot.be.empty"
  fi

  invokeExtendPointFunc "useNotifyTemplate" "common.notify.extend.point.loading.notify.template" "" "${l_content}"

  local l_tmpFile="${gHelmBuildDir}/notify-${RANDOM}.json"
  registerTempFile "${l_tmpFile}"
  echo "${gDefaultRetVal}" > "${l_tmpFile}"

  info "common.notify.extend.point.dingtalk.content.as.follows" "DingTalk"
  cat "${l_tmpFile}"

  for (( l_i = 0; l_i < l_maxTryCount; l_i++ )); do
    info "common.notify.extend.point.trying.to.send.notify.message" "${l_i}" "-n"
    l_errorContent=$(curl -s -X POST -H "Content-Type:application/json" --data "@${l_tmpFile}" "${gExternalNotifyUrl}" 2>&1)
    # shellcheck disable=SC2181
    if [ "$?" -eq 0 ];then
      info "common.notify.extend.point.send.external.notify.success" "" "*"
      break
    fi
    warn "common.notify.extend.point.send.external.notify.failed" "${l_errorContent}" "*"
  done


  #删除临时文件
  unregisterTempFile "${l_tmpFile}"

  unset l_content
  unset l_tmpFile
  unset l_errorFlag
  unset l_maxTryCount
  unset l_i
}

#加载通知消息模板文件
function useNotifyTemplate_ex() {
  export gDefaultRetVal
  export gPipelineScriptsDir
  export gLanguage
  export gServiceName
  export gProjectTemplateDirName

  local l_info=$1

  local l_serviceCode
  local l_level
  local l_message
  local l_template

  l_serviceCode="${gServiceName}"
  #获取自定义消息级别
  l_level="${l_info%%|*}"
  #获得通知文本内容
  l_message="${l_info#*|}"
  l_message="${l_message//\"/\\\"}"

  if [ -f "${gPipelineScriptsDir}/${gProjectTemplateDirName}/config/${gLanguage}/_notify-templates.json" ];then
    l_template=$(cat "${gPipelineScriptsDir}/${gProjectTemplateDirName}/config/${gLanguage}/_notify-templates.json")
  fi

  if [[ ! "${l_template}" && -f "${gPipelineScriptsDir}/${gProjectTemplateDirName}/config/common/_notify-templates.json" ]];then
    l_template=$(cat "${gPipelineScriptsDir}/${gProjectTemplateDirName}/config/common/_notify-templates.json")
  fi


  if [[ ! "${l_template}" ]];then
    gDefaultRetVal="{
  \"serviceCode\": \"${l_serviceCode}\",
  \"level\": \"${l_level}\",
  \"msg\": \"${l_message}\"
}"
  else
    eval "gDefaultRetVal=${l_template}"
  fi
}

#加载语言级脚本扩展文件
loadExtendScriptFileForLanguage "notify"
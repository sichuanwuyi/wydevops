function onPushDockerImage_harbor() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  local l_image=$2
  local l_archType=$3
  local l_repoName=$4

  if [ "${l_dockerRepoType}" != "harbor" ];then
    gDefaultRetVal="false|false"
    return
  fi

  #完成docker镜像推送
  pushImage "${l_image}" "${l_archType}" "${l_repoName}"

  #返回: 否找到了匹配的调用链方法|是否推送成功
  gDefaultRetVal="true|true"
}

function onPushDockerImage_nexus() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  local l_image=$2
  local l_archType=$3
  local l_repoName=$4

  if [ "${l_dockerRepoType}" != "nexus" ];then
    gDefaultRetVal="false|false"
    return
  fi

  #完成docker镜像推送
  pushImage "${l_image}" "${l_archType}" "${l_repoName}"

  #返回: 否找到了匹配的调用链方法|是否推送成功
  gDefaultRetVal="true|true"
}

function onPushDockerImage_registry() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  local l_image=$2
  local l_archType=$3
  local l_repoName=$4

  if [ "${l_dockerRepoType}" != "registry" ];then
    gDefaultRetVal="false|false"
    return
  fi

  #完成docker镜像推送
  pushImage "${l_image}" "${l_archType}" "${l_repoName}"

  #返回: 否找到了匹配的调用链方法|是否推送成功
  gDefaultRetVal="true|true"
}

function onPushDockerImage_aws-ecr() {
  export gDefaultRetVal

  local l_dockerRepoType=$1
  local l_image=$2
  local l_archType=$3
  local l_repoName=$4
  local l_instanceName=$5

  if [ "${l_dockerRepoType}" != "aws-ecr" ];then
    gDefaultRetVal="false|false"
    return
  fi

  if [[ ! ("${l_repoName}" =~ ^(${l_instanceName}).*$) ]];then
    l_repoName="${l_repoName}/${l_instanceName}"
  fi

  #完成docker镜像推送
  pushImage "${l_image}" "${l_archType}" "${l_repoName}"

  #返回: 否找到了匹配的调用链方法|是否推送成功
  gDefaultRetVal="true|true"
}
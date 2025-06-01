#!/usr/bin/env bash

function generateDockerRunShellFile() {
  export gDefaultRetVal
  export gCiCdYamlFile
  export gBuildType
  export gBuildPath
  export gTempFileDir

  local l_index=$1
  local l_chartName=$2
  local l_chartVersion=$3
  local l_images=$4
  local l_remoteDir=$5
  local l_repoName=$6
  local l_account=$7
  local l_password=$8

  local l_array
  local l_port
  local l_exposePorts
  local l_mainImage
  local l_workDirInContainer

  #获取需要暴露的端口号。
  readParam "${gCiCdYamlFile}" "docker.exposePorts"
  # shellcheck disable=SC2206
  l_array=(${gDefaultRetVal//,/ })
  # shellcheck disable=SC2068
  for l_port in ${l_array[@]};do
    l_exposePorts="${l_exposePorts} -p ${l_port}:${l_port}"
  done

  #读取第一个镜像。
  l_mainImage=${l_images%%,*}
  #删除镜像名称中可能存在的_base后缀(docker发布模式只能使用single模式构建的镜像)。
  l_mainImage="${l_mainImage//-base:/:}"

  #获取配置文件挂载路径。
  readParam "${gCiCdYamlFile}" "docker.workDir"
  l_workDirInContainer="${gDefaultRetVal}"

  #在gBuildPath路径中输出docker-run.sh文件。
  if [ "${l_repoName}" ];then
  echo "#!/usr/bin/env bash
  # shellcheck disable=SC2027
  echo \"echo ${l_password} | docker login ${l_repoName} -u ${l_account} --password-stdin\"
  echo \"${l_password}\" | docker login \"${l_repoName}\" -u \"${l_account}\" --password-stdin
  echo \"docker rm -f ${l_chartName}\"
  docker rm -f \"${l_chartName}\"
  echo \"docker run -d ${l_exposePorts:1} -v ${l_remoteDir}/config:${l_workDirInContainer}/config --name ${l_chartName} ${l_repoName}/${l_mainImage}\"
  docker run -d ${l_exposePorts:1} -v ${l_remoteDir}/config:${l_workDirInContainer}/config --name ${l_chartName} ${l_repoName}/${l_mainImage}" > "${gBuildPath}/docker-run.sh"
  else
  echo "#!/usr/bin/env bash
  echo \"docker rm -f ${l_chartName}\"
  docker rm -f \"${l_chartName}\"
  echo \"docker run -d ${l_exposePorts:1} -v ${l_remoteDir}/config:${l_workDirInContainer}/config --name ${l_chartName} ${l_mainImage}\"
  docker run -d ${l_exposePorts:1} -v ${l_remoteDir}/config:${l_workDirInContainer}/config --name ${l_chartName} ${l_mainImage}" > "${gBuildPath}/docker-run.sh"
  fi
}

generateDockerRunShellFile "${@}"
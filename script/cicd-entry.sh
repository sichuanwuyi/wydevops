#!/usr/bin/env bash

function standardCICD(){
  export gBuildStages
  export gPipelineScriptsDir
  export gLanguage
  export gValidBuildStages

  local l_targetScript
  local l_stages
  local l_stage

  if [[ ! "${gBuildStages}" || "${gBuildStages}" =~ ^(.*)all(.*)$ ]];then
    #如果gBuildStages=all
    l_stages=("build" "docker" "chart" "package" "deploy")
  else
    # shellcheck disable=SC2206
    l_stages=(${gBuildStages//,/ })
  fi

  warn "当前有效阶段(gValidBuildStages)为：${gValidBuildStages}"

  # shellcheck disable=SC2068
  for l_stage in ${l_stages[@]}
  do
    info "开始检测${l_stage}阶段的处理脚本:"
    #如果来自配置文件中参数validBuildStages的值为空，或其值包含l_stage，则：
    if [[ ! "${gValidBuildStages}" || "${gValidBuildStages}" =~ ^(.*)${l_stage}.*$ ]];then

      info "优先尝试调用语言级阶段脚本文件/${gLanguage}/${l_stage}.sh..."
      l_targetScript="${gPipelineScriptsDir}/${gLanguage}/${l_stage}.sh"
      if [ ! -f "${l_targetScript}" ];then
        info "--->${gLanguage}语言级脚本文件不存在，调用公共阶段脚本文件:${l_stage}.sh"
        l_targetScript="${gPipelineScriptsDir}/${l_stage}.sh"
      else
        info "--->已检测到${gLanguage}语言级阶段脚本文件:${gLanguage}/${l_stage}.sh"
      fi

      #更新当前构建阶段参数
      gCurrentStage="${l_stage}"

      case ${l_stage} in
        build)
          partLog "第三部分 项目编译阶段"
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        docker)
          partLog "第四部分 项目docker镜像打包与推送阶段"
          info "执行Docker镜像打包阶段..."
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        chart)
          partLog "第五部分 项目chart镜像打包与推送阶段"
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        package)
          partLog "第六部分 标准离线安装包打包阶段"
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        deploy)
          partLog "第七部分 项目部署阶段"
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        *)
          error "不存在的执行阶段参数：${l_stage}"
          ;;
      esac

    else
      warn "根据项目配置参数validBuildStages，跳过${l_stage}阶段继续执行下一个阶段"
    fi

    #清空执行结果信息
    gCurrentStageResult=""
  done
  exit 0
}

#------------------------------执行流程------------------------------#

partLog "第二部分 CI/CD流程调度与执行"

#定义全局参数：当前构建阶段
export gCurrentStage
#当前阶段执行结果
export gCurrentStageResult

#开始执行流程
standardCICD

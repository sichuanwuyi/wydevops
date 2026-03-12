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

  warn "cicd.entry.sh.valid.stages" "${gValidBuildStages}"

  # shellcheck disable=SC2068
  for l_stage in ${l_stages[@]}
  do
    info "cicd.entry.sh.detecting.stage.script" "${l_stage}"
    #如果来自配置文件中参数validBuildStages的值为空，或其值包含l_stage，则：
    if [[ ! "${gValidBuildStages}" || "${gValidBuildStages}" =~ ^(.*)${l_stage}.*$ ]];then

      info "cicd.entry.sh.try.language.script" "${gLanguage}" "${l_stage}"
      l_targetScript="${gPipelineScriptsDir}/${gLanguage}/${l_stage}.sh"
      if [ ! -f "${l_targetScript}" ];then
        info "cicd.entry.sh.language.script.not.exists" "${gLanguage}" "${l_stage}"
        l_targetScript="${gPipelineScriptsDir}/${l_stage}.sh"
      else
        info "cicd.entry.sh.language.script.found" "${gLanguage}" "${l_stage}"
      fi

      #更新当前构建阶段参数
      gCurrentStage="${l_stage}"

      case ${l_stage} in
        build)
          partLog "cicd.entry.sh.part3.build.stage"
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        docker)
          partLog "cicd.entry.sh.part4.docker.stage"
          info "cicd.entry.sh.executing.docker.stage"
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        chart)
          partLog "cicd.entry.sh.part5.chart.stage"
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        package)
          partLog "cicd.entry.sh.part5.package.stage"
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        deploy)
          partLog "cicd.entry.sh.part7.deploy.stage"
          # shellcheck disable=SC1090
          source "${l_targetScript}"
          ;;
        *)
          error "cicd.entry.sh.nonexistent.stage.parameter" "${l_stage}"
          ;;
      esac

    else
      warn "cicd.entry.sh.skip.stage" "${l_stage}"
    fi

    #清空执行结果信息
    gCurrentStageResult=""
  done

}

#------------------------------执行流程------------------------------#

partLog "cicd.entry.sh.part2.cicd.dispatch"

#定义全局参数：当前构建阶段
export gCurrentStage
#当前阶段执行结果
export gCurrentStageResult

#开始执行流程
standardCICD

#!/usr/bin/env bash

# 脚本编码约定：
# 1. 全局变量名称以小写字母g开头，定义在函数外部，并以export关键字修饰之。
# 2. 函数内部跨子函数共享的变量名称必须以下划线"_"开头,子函数内部使用export关键字修饰之。
# 3. 函数内部私有的变量名称必须以"l_"开头,并使用local关键字修饰之。这类变量逻辑上在子函数内禁止访问。
# 4. 函数内部定义的私有变量集中在函数入口处集中定义，在函数末尾集中取消(unset)。
# 5. 本文件中以下划线"_"开头的函数为内部私有函数。

function partLog() {
  #需要输出的信息
  local l_info=$1
  #l_info中的占位符参数值
  local l_infoParams=$2
  #内容输出文件名称
  local l_outFileName=$3

  part "${l_info}" "${l_infoParams}" "${l_outFileName}" "32"
}

#扩展点日志
function extendLog() {
  export gLogI18NRetVal
  export gWorkMode

  #扩展点函数方法名
  local l_funcName=$1
  #扩展点名称
  local l_info=$2
  #扩展点名称中的占位参数值
  local l_infoParams=$3
  #是否是开始标识
  local l_startFlag=$4
  #内容输出文件名称
  local l_outFileName=$5

  local l_start
  local l_end

  #使用国际化资源替换l_info
  convertI18NText "${l_info}" "${l_infoParams}"
  if [ "${l_startFlag}" == "true" ];then
    l_info="\n--->> ${gLogI18NRetVal}(${l_funcName}) <<---"
  else
    l_info="<<--- ${gLogI18NRetVal}(${l_funcName}) --->>\n"
  fi

  if [[ ! "${gWorkMode}" || "${gWorkMode}" == "local" ]];then
    l_start="\e[32m"
    l_end="\e[0m"
  fi

  log "${l_start}${l_info}${l_end}" "info" "${l_outFileName}"
}

#调用log函数输出信息
function info() {
  export gMessagePropertiesMap
  export gLogI18NRetVal
  export gWorkMode

  #需要输出的信息
  local l_info=$1
  #l_info中的占位符参数值
  local l_infoParams=$2
  #echo语句的可选项。
  local l_options=$3
  #内容输出文件名称
  local l_outFileName=$4

  local l_start
  local l_end
  local l_infoPrefix

  #使用国际化资源替换l_info
  convertI18NText "${l_info}" "${l_infoParams}"
  l_info="${gLogI18NRetVal}"

  l_infoPrefix="${gMessagePropertiesMap["log.helper.info"]}"

  if [[ ! "${gWorkMode}" || "${gWorkMode}" == "local" ]];then
    l_start="\e[32m"
    l_end="\e[0m"
  fi

  if [ "${l_options}" ];then
    if [[ "${l_options}" =~ ^(\-) ]];then
      log "${l_start}${l_infoPrefix}${l_info}${l_end}" "info" "${l_options}" "${l_outFileName}"
    else
      log "${l_start}${l_info}${l_end}" "info" "" "${l_outFileName}"
    fi
  else
    log "${l_start}${l_infoPrefix}${l_info}${l_end}" "info" "" "${l_outFileName}"
  fi
}

function error() {
  export gTempFileRegTables
  export gMessagePropertiesMap
  export gLogI18NRetVal
  export gWorkMode

  #需要输出的信息
  local l_info=$1
  #l_info中的占位符参数值
  local l_infoParams=$2
  #echo语句的可选项。
  local l_options=$3
  #内容输出文件名称
  local l_outFileName=$4

  local l_tempFile

  local l_start
  local l_end
  local l_tmpInfo
  local l_infoPrefix

  #使用国际化资源替换l_info
  convertI18NText "${l_info}" "${l_infoParams}"
  l_tmpInfo="${gLogI18NRetVal}"

  l_infoPrefix="${gMessagePropertiesMap["log.helper.error"]}"

  if [[ ! "${gWorkMode}" || "${gWorkMode}" == "local" ]];then
    l_start="\e[5;31m"
    l_end="\e[0m"
  fi


  if [ "${l_options}" ];then
    if [[ "${l_options}" =~ ^(\-) ]];then
      log "${l_start}${l_infoPrefix}${l_tmpInfo}${l_end}" "error" "${l_options}" "${l_outFileName}"
    else
      log "${l_start}${l_tmpInfo}${l_end}" "error" "" "${l_outFileName}"
    fi
  else
    log "${l_start}${l_infoPrefix}${l_tmpInfo}${l_end}" "error" "" "${l_outFileName}"
  fi

  #清除注册的临时文件。
  # shellcheck disable=SC2068
  for l_tempFile in ${gTempFileRegTables[@]};do
    info "log.helper.hint.delete.tmp.file.before.exit", "${l_tempFile##*/}"
    rm -f "${l_tempFile}"
  done

  if type -t "invokeExtendPointFunc" > /dev/null; then
    #调用外部接口发送通知消息
    invokeExtendPointFunc "sendNotifyBeforeExit" "log.helper.send.notify.before.exit" "" "ERROR|${l_tmpInfo}"
  fi
  exit 1
}

function registerTempFile(){
  export gTempFileRegTables
  local l_tmpFile=$1
  local l_content

  if [ ! "${l_replaceOnExist}" ];then
    l_replaceOnExist="true"
  fi

  l_content="${gTempFileRegTables[${l_tmpFile##*/}]}"
  #如果是同名不同路径的文件，则需要根据l_replaceOnExist参数处理。
  if [[ "${l_content}" ]];then
    [[ "${l_content}" == "${l_tmpFile}" ]] && return
    rm -f "${l_content}"
    # shellcheck disable=SC2184
    unset gFileContentMap["${l_tmpFile}"]
  fi

  #info "log.helper.register.tmp.file" "${l_tmpFile##*/}"
  gTempFileRegTables["${l_tmpFile##*/}"]="${l_tmpFile}"
}

function unregisterTempFile(){
  export gTempFileRegTables
  local l_tmpFile=$1
  if [ -f "${l_tmpFile}" ];then
    #info "log.helper.delete.tmp.file" "${l_tmpFile##*/}"
    rm -f "${l_tmpFile}"
    # shellcheck disable=SC2184
    unset gTempFileRegTables["${l_tmpFile##*/}"]
    # shellcheck disable=SC2184
    unset gFileContentMap["${l_tmpFile}"]
  fi
}

#调用log函数输出调试信息
function debug() {
  export gMessagePropertiesMap
  export gLogI18NRetVal
  export gWorkMode

  #需要输出的信息
  local l_info=$1
  #l_info中的占位符参数值
  local l_infoParams=$2
  #echo语句的可选项。
  local l_options=$3
  #内容输出文件名称
  local l_outFileName=$4

  local l_start
  local l_end
  local l_infoPrefix

  #使用国际化资源替换l_info
  convertI18NText "${l_info}" "${l_infoParams}"
  l_info="${gLogI18NRetVal}"

  l_infoPrefix="${gMessagePropertiesMap["log.helper.debug"]}"

  if [[ ! "${gWorkMode}" || "${gWorkMode}" == "local" ]];then
    l_start="\e[33m"
    l_end="\e[0m"
  fi

  if [ "${l_options}" ];then
    if [[ "${l_options}" =~ ^(\-) ]];then
      log "${l_start}${l_infoPrefix}${l_info}${l_end} " "debug" "${l_options}" "${l_outFileName}"
    else
      log "${l_start}${l_info}${l_end}" "debug" "" "${l_outFileName}"
    fi
  else
    log "${l_start}${l_infoPrefix}${l_info}${l_end}" "debug" "" "${l_outFileName}"
  fi
}

function warn() {
  export gMessagePropertiesMap
  export gLogI18NRetVal
  export gWorkMode

  #需要输出的信息
  local l_info=$1
  #l_info中的占位符参数值
  local l_infoParams=$2
  #echo语句的可选项。
  local l_options=$3
  #内容输出文件名称
  local l_outFileName=$4

  local l_start
  local l_end
  local l_infoPrefix

  #使用国际化资源替换l_info
  convertI18NText "${l_info}" "${l_infoParams}"
  l_info="${gLogI18NRetVal}"

  l_infoPrefix="${gMessagePropertiesMap["log.helper.warn"]}"

  if [[ ! "${gWorkMode}" || "${gWorkMode}" == "local" ]];then
    l_start="\e[33m"
    l_end="\e[0m"
  fi

  if [ "${l_options}" ];then
    if [[ "${l_options}" =~ ^(\-) ]];then
      log "${l_start}${l_infoPrefix}${l_info}${l_end}" "warn" "${l_options}" "${l_outFileName}"
    else
      log "${l_start}${l_info}${l_end}" "warn" "" "${l_outFileName}"
    fi
  else
    log "${l_start}${l_infoPrefix}${l_info}${l_end}" "warn" "" "${l_outFileName}"
  fi
}

#输出提示信息或调试信息到指定的目标输出文件中
#如果不是调试信息，则：
#   首先输出到控制台。
#   如果指定了输出文件称，则还需要输出到目标文件中。
#如果是调试信息，则：
#   如果未指定输出文件名称，则首先输出到控制台。
#      如果gDebugMode==true,则默认设置输出文件名称为debug.txt，并把调试信息追加写入到输出文件中。
#   如果设置了输出文件名称，则将调试信息追加写入输出文件中。
function log() {
  #引用全局变量
  export gDebugMode

  #需要输出的信息
  local l_info=$1
  #信息类型：debug、info、warn、error
  local l_type=$2
  #echo语句的可选项。
  local l_options=$3
  #内容输出文件名称
  local l_outFileName=$4

  local l_outFile

  #如果l_type!=debug, 或者gDebugMode=true, 则直接在控制台输出l_info。
  if [ "${l_type}" != "debug" ] || [ "${gDebugMode}" == "true" ];then
     if [ "${l_options}" ];then
       echo -e "${l_options}" "${l_info}"
     else
       echo -e "${l_info}"
     fi
  fi

  if [ ! "${l_outFileName}" ];then
    #如果gDebugMode=true,并且l_type=debug,,则初始化l_outFileName变量。
    if [ "${l_type}" == "debug" ] && [ "${gDebugMode}" == "true" ];then
      l_outFileName="debug.txt"
    fi
  else
    #防止外部输出的文件名称中包含路径信息。
    l_outFileName="${l_outFileName##*/}"
  fi

  #向文件中输出l_info信息。
  if [ "${l_outFileName}" ]; then
    if [ "${gDebugOutDir}" ];then
      l_outFile="${gDebugOutDir}/${l_outFileName}"
    else
      l_outFile="./${l_outFileName}"
    fi

    if [ "${l_options}" ];then
      echo -e "${l_options}" "${l_info}" >> "${l_outFile}"
    else
      echo -e "${l_info}" >> "${l_outFile}"
    fi
  fi
}

function part() {
  export gLogI18NRetVal
  export gWorkMode

  #需要输出的信息
  local l_info=$1
  #l_info中的占位符参数值
  local l_infoParams=$2
  #内容输出文件名称
  local l_outFileName=$3
  #字体的颜色
  local l_color=$4

  local l_lineLen
  local l_infoLen
  local l_infoLen1
  local l_lineFlag
  local l_startNum
  local l_content
  local l_head
  local l_tail

  #使用国际化资源替换l_info
  convertI18NText "${l_info}" "${l_infoParams}"
  l_info="${gLogI18NRetVal}"

  l_lineLen="100"
  #得到l_info的显示长度
  l_infoLen1=$(_getStringLen "${l_info}")

  #构造起始和结尾字符串
  l_lineFlag=$(seq -s "*" "${l_lineLen}")
  l_lineFlag="${l_lineFlag//[0-9]/}"

  #计算l_info显示行的“*”起始显示数量。
  ((l_startNum = l_lineLen - l_infoLen1))
  ((l_startNum = l_startNum / 2))
  #构造l_info显示行的起始显示字符串
  l_head=$(seq -s "*" "${l_startNum}")
  l_head="${l_head//[0-9]/}"

  #计算l_info显示行后缀显示“*”的数量。
  ((l_startNum = l_lineLen - l_startNum - l_infoLen1 + 1))
  #构造l_info显示行的后缀显示字符串
  l_tail=$(seq -s "*" "${l_startNum}")
  l_tail="${l_tail//[0-9]/}"

  #定义Part的显示格式
  local l_content="\n${l_lineFlag}\n${l_head}${l_info}${l_tail}\n${l_lineFlag}\n"
  if [[ ! "${gWorkMode}" || "${gWorkMode}" == "local" ]];then
    l_content="\n\e[${l_color}m${l_lineFlag}\n${l_head}${l_info}${l_tail}\n${l_lineFlag}\e[0m\n"
  fi

  #输出信息
  log "${l_content}" "info" "${l_outFileName}"
}

function convertI18NText(){
  export gMessagePropertiesMap
  export gLogI18NRetVal

  local l_message=$1
  local l_msgParams=$2

  local l_index
  local l_param_val
  local l_tmpInfo
  local l_params
  local l_param_count

  #使用国际化资源替换l_info
  l_tmpInfo="${gMessagePropertiesMap[${l_message}]}"
  if [ "${l_tmpInfo}" ];then
    l_message="${l_tmpInfo}"
  fi

  if [ "${l_msgParams}" ];then
    #将l_options参数中按#字符分割为数组。
    IFS='#' read -r -a l_params <<< "${l_msgParams}"
    l_param_count=${#l_params[@]}
  else
    l_params=()
    l_param_count=0
  fi

  l_index=0
  while [[ "$l_message" == *"{${l_index}}"* ]]
  do
    if [ "${l_index}" -lt "${l_param_count}" ];then
      l_param_val="${l_params[${l_index}]}"
    else
      l_param_val="?"
    fi
    # 将 {index} 替换为实际的参数值
    # shellcheck disable=SC1083
    l_message="${l_message//\{$l_index\}/$l_param_val}"
    ((l_index++))
  done

  gLogI18NRetVal="${l_message}"

}

#*******************私有函数********************

#计算字符串的显示字节长度。
function _getStringLen() {
  #需要输出的信息
  local l_info=$1

  local l_infoLen
  local l_infoLen1
  local l_tmpLen

  l_infoLen=${#l_info}
  # shellcheck disable=SC2000
  l_infoLen1=$(echo "${l_info}" | wc -c)

  ((l_tmpLen = l_infoLen1 - l_infoLen))
  if [ "${l_tmpLen}" -eq 1 ];then
    #字符串不包含中文，则直接返回字符串的长度。
    echo "${l_infoLen}"
  else
    #得到字符串中非中文字符的长度。
    ((l_infoLen1 = (3 * l_infoLen - l_infoLen1 + 1) / 2 ))
    #得到字符串的显示长度。
    ((l_infoLen = l_infoLen * 2 - l_infoLen1))
    echo "${l_infoLen}"
  fi
}

function loadMessageProperties(){
  export gMessagePropertiesMap
  export _selfRootDir

  local l_file_path
  local l_language
  local l_matchedFile="true"

  if [ "${#gMessagePropertiesMap[@]}" -ne 0 ]; then
    #已经加载过了就直接返回。
    return
  fi

  if [ -z "$LOG_LANGUAGE" ];then
    #define language in log as en-US
    export LOG_LANGUAGE="en-US"
  fi

  l_language=${LOG_LANGUAGE}
  l_file_path="${_selfRootDir}/i18n/message_${l_language}.properties"
  if [ ! -f "${l_file_path}" ]; then
    l_matchedFile="false"
    if [[ "${l_language}" =~ ^zh ]];then
      l_language="zh"
    else
      l_language="en"
    fi
    l_file_path="${_selfRootDir}/i18n/message_${l_language}.properties"
  fi

  if [ -f "${l_file_path}" ]; then
    while IFS='=' read -r key value || [ -n "${key}" ]; do
      # 忽略空行和注释
      if [[ -n "${key}" && ! "${key}" =~ ^\s*# ]]; then
        if [ "${key}" ];then
          gMessagePropertiesMap["${key}"]="${value}"
        fi
      fi
    done < "${l_file_path}"

    if [ "${l_matchedFile}" == "false" ];then
      warn "log.helper.no.message.properties.file" "${LOG_LANGUAGE}"
      warn "log.helper.use.default.message.properties.file" "${l_language}#message_${l_language}.properties"
    else
      warn "log.helper.use.target.message.properties.file" "${l_language}#message_${l_language}.properties"
    fi
  fi

}

#i18n国际化资源Map。
declare -A gMessagePropertiesMap
export gMessagePropertiesMap

#构建脚本所在的根目录
export _selfRootDir

#convertI18NText方法的返回值变量。
export gLogI18NRetVal

#引入工作模式全局变量,jenkins模式下输出的日志不设置颜色。
export gWorkMode
# 申明全局调试模式指示变量，用于debug函数内控制信息的显示
export gDebugMode
# 申明默认调试文件输出目录
export gDebugOutDir
#引入的全局临时文件目录
export gTempFileDir
#引入yaml-helper.yaml文件中的文件内存缓存变量
#在删除文件时需要同步清除缓存中的内容。
export gFileContentMap

#加载国际化资源
loadMessageProperties

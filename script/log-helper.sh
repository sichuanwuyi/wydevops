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
  #内容输出文件名称
  local l_outFileName=$2

  part "${l_info}" "${l_outFileName}" "32"
}

#扩展点日志
function extendLog() {
  #需要输出的信息
  local l_info=$1
  #内容输出文件名称
  local l_outFileName=$2

  log "\e[32m${l_info}\e[0m" "info" "${l_outFileName}"
}

#调用log函数输出信息
function info() {
  #需要输出的信息
  local l_info=$1
  #echo语句的可选项。
  local l_options=$2
  #内容输出文件名称
  local l_outFileName=$3

  if [ "${l_options}" ];then
    if [[ "${l_options}" =~ ^(\-) ]];then
      log "\e[32m【信息】${l_info}\e[0m" "info" "${l_options}" "${l_outFileName}"
    else
      log "\e[32m${l_info}\e[0m" "info" "" "${l_outFileName}"
    fi
  else
    log "\e[32m【信息】${l_info}\e[0m" "info" "" "${l_outFileName}"
  fi
}

function error() {
  #需要输出的信息
  local l_info=$1
  #echo语句的可选项。
  local l_options=$2
  #内容输出文件名称
  local l_outFileName=$3

  local l_tempFile

  if [ "${l_options}" ];then
    if [[ "${l_options}" =~ ^(\-) ]];then
      log "\e[5;31m【错误】${l_info}\e[0m" "error" "${l_options}" "${l_outFileName}"
    else
      log "\e[5;31m${l_info}\e[0m" "error" "" "${l_outFileName}"
    fi
  else
    log "\e[5;31m【错误】${l_info}\e[0m" "error" "" "${l_outFileName}"
  fi

  #清除注册的临时文件。
  # shellcheck disable=SC2068
  for l_tempFile in ${gTempFileRegTables[@]};do
    rm -f "${l_tempFile}"
  done

  if type -t "invokeExtendPointFunc" > /dev/null; then
    #调用外部接口发送通知消息
    invokeExtendPointFunc "sendNotify" "调用通知接口发送执行异常结果" "ERROR|${l_info}"
  fi
  exit 1
}

function registerTempFile(){
  export gTempFileRegTables
  local l_tmpFile=$1
  gTempFileRegTables["${l_tmpFile##*/}"]="${l_tmpFile}"
}

function unregisterTempFile(){
  export gTempFileRegTables
  local l_tmpFile=$1
  if [ "${l_tmpFile}" ];then
    rm -f "${l_tmpFile}"
    unset gTempFileRegTables["${l_tmpFile##*/}"]
  fi
}

#调用log函数输出调试信息
function debug() {
  #需要输出的信息
  local l_info=$1
  #echo语句的可选项。
  local l_options=$2
  #内容输出文件名称
  local l_outFileName=$3

  if [ "${l_options}" ];then
    if [[ "${l_options}" =~ ^(\-) ]];then
      log "\e[33m【调试】\e[0m ${l_info}" "debug" "${l_options}" "${l_outFileName}"
    else
      log "\e[33m\e[0m${l_info}" "debug" "" "${l_outFileName}"
    fi
  else
    log "\e[33m【调试】\e[0m${l_info}" "debug" "" "${l_outFileName}"
  fi
}

function warn() {
  #需要输出的信息
  local l_info=$1
  #echo语句的可选项。
  local l_options=$2
  #内容输出文件名称
  local l_outFileName=$3

  if [ "${l_options}" ];then
    if [[ "${l_options}" =~ ^(\-) ]];then
      log "\e[33m【警告】${l_info}\e[0m" "warn" "${l_options}" "${l_outFileName}"
    else
      log "\e[33m${l_info}\e[0m" "warn" "" "${l_outFileName}"
    fi
  else
    log "\e[33m【警告】${l_info}\e[0m" "warn" "" "${l_outFileName}"
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
  #需要输出的信息
  local l_info=$1
  #信息类型：debug、info、warn、error
  local l_type=$2
  #echo语句的可选项。
  local l_options=$3
  #内容输出文件名称
  local l_outFileName=$4

  local l_outFile

  #引用全局变量
  export gDebugMode

  #如果l_type!=debug, 或者gDebugMode=true, 则直接在控制台输出l_info。
  if [ "${l_type}" != "debug" ] || [ "${gDebugMode}" == "true" ];then
     echo -e "${l_options}" "${l_info}"
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
    echo -e "${l_options}" "${l_info}" >> "${l_outFile}"
  fi
}

function part() {
  #需要输出的信息
  local l_info=$1
  #内容输出文件名称
  local l_outFileName=$2
  #字体的颜色
  local l_color=$3

  local l_lineLen
  local l_infoLen
  local l_infoLen1
  local l_lineFlag
  local l_startNum
  local l_content
  local l_head
  local l_tail

  l_lineLen="50"
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
  local l_content="\n\e[${l_color}m${l_lineFlag}\n${l_head}${l_info}${l_tail}\n${l_lineFlag}\e[0m\n"

  #输出信息
  log "${l_content}" "info" "${l_outFileName}"
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

# 申明全局调试模式指示变量，用于debug函数内控制信息的显示
export gDebugMode
# 申明默认调试文件输出目录
export gDebugOutDir
#引入的全局临时文件目录
export gTempFileDir

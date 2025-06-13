#!/usr/bin/env bash

# 脚本编码约定：
# 1. 全局变量名称以小写字母g开头，定义在函数外部，并以export关键字修饰之。
# 2. 定义在函数外部并以下划线开头的全局变量，禁止在其他脚本文件中引用，使用完毕后必须及时unset。
# 3. 函数内部跨子函数共享的变量名称必须以下划线"_"开头,子函数内部使用export关键字修饰之。
# 4. 函数内部私有的变量名称必须以"l_"开头,并使用local关键字修饰之。这类变量逻辑上在子函数内禁止访问。
# 5. 函数内部定义的私有变量在离开作用域前必须使用unset语句取消变量的定义。
# 6. 本文件中以下划线"_"开头的函数为内部私有函数。

#-------------------------------------公共方法-------------------------------------------#

#从Yaml文件中读取指定的参数的值
#支持使用点分符的多级路径，并支持数组类型的参数路径。
# 例如: a.b[1].c
function readParam() {
  #读取文件中的参数。
  if [ "${gEnableCache}" == "true" ];then
    _readOrWriteYamlFile "read" "${@}"
  else
    __readOrWriteYamlFile "read" "${@}"
  fi
}

#在给定的参数定义块中读取指定参数名（不能带路径）的值
function readParamInList() {

  local l_paramDefineBlock=$1
  local l_itemIndex=$2
  local l_paramName=$3

  local l_tmpSpaceNum
  local l_lineCount

  local l_paramLines
  local l_tmpLineArray
  local l_lineContent
  local l_paramValue

  #获取参数定义块的前导空格数量。
  l_tmpSpaceNum=$(awk 'match($0,/^[ ]*- /) {print RLENGTH-2; exit}' <<< "${l_paramDefineBlock}")
  l_lineCount=$(awk -v spaces="${l_tmpSpaceNum}" '
      BEGIN {
          # 处理零空格情况
          pattern = (spaces > 0) ? sprintf("^[ ]{%d}- ", spaces) : "^- "
      }
      $0 ~ pattern { count++ }
      END { print count+0 }' <<< "${l_paramDefineBlock}")

  gDefaultRetVal=""
  if [[ "${l_lineCount}" -gt 0 && "${l_paramName}" ]];then
    #从l_paramDefineBlock中提前l_paramName参数定义所在的所有行内容。
    _getParamLines "${l_paramDefineBlock}" "${l_paramName}" "${l_tmpSpaceNum}"
    l_paramLines="${gDefaultRetVal}"
    gDefaultRetVal=""
    # 将多行内容转换为数组
    mapfile -t l_tmpLineArray <<< "${l_paramLines}"
    l_lineContent="${l_tmpLineArray[${l_itemIndex}]}"
    #读取冒号后面的内容。
    l_paramValue="${l_lineContent#*:}"
    #去掉左右空格
    l_paramValue="${l_paramValue#"${l_paramValue%%[^[:space:]]*}"}"
    l_paramValue="${l_paramValue%"${l_paramValue##*[^[:space:]]}"}"
    #设置返回值。
    gDefaultRetVal="${l_paramValue}"
  fi

}

#更新Yaml文件中指定参数的值
function updateParam() {
  #更新文件中的参数。
  if [ "${gEnableCache}" == "true" ];then
    _readOrWriteYamlFile "update" "${@}"
  else
    __readOrWriteYamlFile "update" "${@}"
  fi
}

#向Yaml文件中插入指定的参数
function insertParam() {
  #向文件中插入参数。
  if [ "${gEnableCache}" == "true" ];then
    _readOrWriteYamlFile "insert" "${@}"
  else
    __readOrWriteYamlFile "insert" "${@}"
  fi
}

function deleteParam(){
  #删除文件中的参数。
  if [ "${gEnableCache}" == "true" ];then
    _readOrWriteYamlFile "delete" "${@}"
  else
    __readOrWriteYamlFile "delete" "${@}"
  fi
}

#读取指定参数路径的值所在的起始行号和截至行号。
#返回值为"-1 -1",表示指定参数路径没有下层参数行
function readRowRange(){
  if [ "${gEnableCache}" == "true" ];then
    _readOrWriteYamlFile "rowRange" "${@}"
  else
    __readOrWriteYamlFile "rowRange" "${@}"
  fi
}

function enableSaveBackImmediately(){
  export gDefaultRetVal
  export gFileContentMap
  export gSaveBackImmediately

  local l_saveBackStatus=$1
  local l_clearCache=$2

  local l_yamlFile
  local l_fileContent

  if [ ! "${l_saveBackStatus}" ];then
    l_saveBackStatus="true"
  fi

  if [ ! "${l_clearCache}" ];then
    l_clearCache="false"
  fi

  # shellcheck disable=SC2068
  for l_yamlFile in ${!gFileContentMap[@]};do
    l_fileContent="${gFileContentMap[${l_yamlFile}]}"
    if [ -f "${l_yamlFile}" ];then
      echo -e "${l_fileContent}" > "${l_yamlFile}"
    fi
    if [[ "${l_clearCache}" == "true" ]];then
      unset gFileContentMap["${l_yamlFile}"]
    fi
  done
  gSaveBackImmediately="${l_saveBackStatus}"
}

function disableSaveBackImmediately(){
  export gDefaultRetVal
  export gSaveBackImmediately

  gDefaultRetVal="${gSaveBackImmediately}"
  gSaveBackImmediately="false"
}

function clearCachedFileContent(){
  export gFileContentMap

  local l_targetYamlFile=$1
  local l_yamlFile
  local l_content

  if [ "${l_targetYamlFile}" ];then
    #先写回文件再删除
    l_content="${gFileContentMap[${l_targetYamlFile}]}"
    [[ "${l_content}" ]] && echo -e "${l_content}" > "${l_targetYamlFile}"
    unset gFileContentMap["${l_targetYamlFile}"]
  else
    # shellcheck disable=SC2068
    for l_yamlFile in ${!gFileContentMap[@]};do
      #先写回文件再删除
      l_content="${gFileContentMap[${l_yamlFile}]}"
      [[ "${l_content}" ]] && echo -e "${l_content}" > "${l_yamlFile}"
      unset gFileContentMap["${l_yamlFile}"]
    done
  fi

}

function clearFileDataBlockMap(){
  export gFileDataBlockMap
  local l_yamlFileName=$1
  local l_key
  # shellcheck disable=SC2068
  for l_key in ${!gFileDataBlockMap[@]};do
    if [[ ! "${l_yamlFileName}" || ${l_key} =~ ^(${l_yamlFileName}) ]];then
      unset gFileDataBlockMap["${l_key}"]
    fi
  done
}

function getAllParamPathAndValue() {
  export gDefaultRetVal
  local l_yamlFile=$1
  local l_paramPath=$2
  # 关联数组引用
  local l_resultMapName=$3
  # 顺序数组引用
  local l_paramKeys=$4
  local l_paramPathPrefix=$5


  readParam "${l_yamlFile}" "${l_paramPath}"
  [ "${gDefaultRetVal}" == "null" ] && error "${l_yamlFile##*/}文件中不存在${l_paramPath}参数"

  _getAllParamPathAndValueByParentPath "${l_yamlFile}" "${l_paramPath}" "${l_resultMapName}" \
    "${l_paramKeys}" "${gDefaultRetVal}" "${l_paramPathPrefix}"

}

function getListTypeByContent() {
  export gDefaultRetVal

  local l_content=$1
  local l_tmpSpaceNum
  local l_lineCount
  local l_itemCount

  _deleteInvalidLines "${l_content}"
  l_content="${gDefaultRetVal}"

  #以下awk命令已验证通过
  l_tmpSpaceNum=$(awk 'match($0,/^ */){print RLENGTH; exit}' <<< "${l_content}")
  l_itemCount=$(grep -Ec "^[ ]{${l_tmpSpaceNum}}-" <<< "${l_content}")
  l_lineCount=$(grep -Ec "^[ ]*[a-zA-Z_\-]+" <<< "${l_content}")
  gDefaultRetVal="list"
  if [ "${l_lineCount}" -eq "${l_itemCount}" ];then
    l_itemCount=$(grep -Ec "^( *)- ( *$| +! *$| +[a-zA-Z_]+.*:.*)" <<< "${l_content}")
    if [ "${l_lineCount}" -ne "${l_itemCount}" ];then
      gDefaultRetVal="array"
    fi
  fi
}

function getListIndexByPropertyNameQuickly() {
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_paramName=$3
  local l_paramValue=$4
  local l_returnItemCount=$5
  #提前读取的新参数定义块
  local l_paramDefineBlock=$6
  #最后读取的列表项序号
  local l_itemIndex=$7
  #参数值查询字典文件
  local l_paramQueryDicFile=$8
  #参数值查询字典配置节的前缀（即名称）
  local l_paramQueryDicPrefix=$9

  local l_tmpSpaceNum
  local l_lineCount
  local l_paramLines
  local l_tmpLineArray
  local l_lineContent


  local l_i
  local l_index

  local l_curParamValue

  if [ ! "${l_paramDefineBlock}" ];then
    readParam "${l_yamlFile}" "${l_paramPath}"
    if [[ ! "${gDefaultRetVal}" || "${gDefaultRetVal}" == "null" ]];then
      gDefaultRetVal="-1"
      return
    fi
    l_paramDefineBlock="${gDefaultRetVal}"
  fi

  if [ ! "${l_itemIndex}" ];then
    ((l_itemIndex = -1))
  fi

  if [ ! "${l_paramQueryDicFile}" ];then
    l_paramQueryDicFile="${l_yamlFile}"
  fi

  if [ ! "${l_paramQueryDicPrefix}" ];then
    l_paramQueryDicPrefix="globalParams"
  fi

  l_tmpSpaceNum=$(awk 'match($0,/^[ ]*- /){print RLENGTH-2; exit}' <<< "${l_paramDefineBlock}")
  l_lineCount=$(grep -cE "^[ ]{${l_tmpSpaceNum}}\-" <<< "${l_paramDefineBlock}")

  ((l_index = -1))
  if [[ "${l_lineCount}" -gt 0 && "${l_paramName}" ]];then
    #从l_paramDefineBlock中提前l_paramName参数定义所在的所有行内容。
    _getParamLines "${l_paramDefineBlock}" "${l_paramName}" "${l_tmpSpaceNum}"
    l_paramLines="${gDefaultRetVal}"
    gDefaultRetVal=""
    # 将多行内容转换为数组
    mapfile -t l_tmpLineArray <<< "${l_paramLines}"

    #遍历数组，查找指定参数值的数组序号。
    #先从l_itemIndex开始递增查找
    ((l_i = l_itemIndex + 1))
    while true; do
      l_lineContent="${l_tmpLineArray[${l_i}]}"
      if [ ! "${l_lineContent}" ];then
        break
      fi

      #读取冒号后面的内容，并进行变量替换。
      _getParamValue "${l_lineContent}" "${l_paramValue}" "${l_paramQueryDicFile}" "${l_paramQueryDicPrefix}"
      l_curParamValue="${gDefaultRetVal}"

      if [[ "${l_curParamValue}" == "${l_paramValue}" ]];then
        ((l_index = l_i))
        break;
      fi

      ((l_i = l_i + 1))
    done

    #如果没有找到，则从l_itemIndex开始递减查找。
    if [[ "${l_index}" -eq -1 && "${l_itemIndex}" -gt 0 ]];then
      ((l_i = l_itemIndex - 1))
      while [ "${l_i}"  -ge 0 ]; do
        l_lineContent="${l_tmpLineArray[${l_i}]}"
        if [ ! "${l_lineContent}" ];then
          break
        fi

        #读取冒号后面的内容，并进行变量替换。
        _getParamValue "${l_lineContent}" "${l_paramValue}" "${l_paramQueryDicFile}" "${l_paramQueryDicPrefix}"
        l_curParamValue="${gDefaultRetVal}"

        if [[ "${l_curParamValue}" == "${l_paramValue}" ]];then
          ((l_index = l_i))
          break;
        fi
        ((l_i = l_i - 1))

      done
    fi
  fi

  if [[ "${l_returnItemCount}" && "${l_returnItemCount}" == "true" ]];then
    gDefaultRetVal="${l_index} ${l_lineCount}"
  else
    gDefaultRetVal="${l_index}"
  fi
}

function getListSize(){
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_paramPath=$2

  local l_lineCount

  readParam "${l_yamlFile}" "${l_paramPath}"
  if [ "${gDefaultRetVal}" == "null" ];then
    gDefaultRetVal="0"
    return
  fi

  l_lineCount=$(grep -cE '^ *-' <<< "${gDefaultRetVal}")
  gDefaultRetVal="${l_lineCount}"
}

#将l_srcYamlFile文件中的配置合并到l_targetYamlFile文件中。
#如果l_targetYamlFile文件中不存在相同路径的参数，则输出告警信息或报错退出。
function combine(){
  export gDefaultRetVal

  local l_srcYamlFile=$1
  local l_targetYamlFile=$2
  local l_srcParamPath=$3
  local l_targetParamPath=$4
  local l_allowInsertNewListItem=$5
  local l_exitOnFailure=$6
  #当列表项中存在特殊的"- !"项时，l_cascadeDelete为true表示：需要将这项也同时赋值到目标文件中
  local l_cascadeDelete=$7

  local l_srcContent
  local l_saveBackStatus

  if [ ! "${l_allowInsertNewListItem}" ];then
    l_allowInsertNewListItem="true"
  fi

  if [ ! "${l_exitOnFailure}" ];then
    l_exitOnFailure="false"
  fi

  if [ ! "${l_reserveDeleteItem}" ];then
    l_reserveDeleteItem="false"
  fi

  disableSaveBackImmediately
  l_saveBackStatus="${gDefaultRetVal}"

  if [ "${l_srcParamPath}" ];then
    #读取整个参数的数据块内容。
    readParam "${l_srcYamlFile}" "${l_srcParamPath}"
    if [ "${gDefaultRetVal}" == "null" ];then
      error "${l_srcYamlFile}文件中不存在${l_srcParamPath}参数"
    else
      l_srcContent="${gDefaultRetVal}"
    fi
  else
    #读取整个文件的内容。
    l_srcContent=$(< "${l_srcYamlFile}")
  fi

  info "合并${l_srcYamlFile}文件与${l_targetYamlFile}文件中的参数---开始"

  #给定参数路径及其参数下属数据块内容，更新目标文件l_targetYamlFile的内容。
  _combine "${l_srcContent}" "${l_srcParamPath}" "${l_targetYamlFile}" "${l_srcParamPath}" "${l_allowInsertNewListItem}" \
    "${l_exitOnFailure}" "${l_cascadeDelete}"

  info "合并${l_srcYamlFile}文件与${l_targetYamlFile}文件中的参数---结束"

  #恢复gSaveBackImmediately的原始值。
  enableSaveBackImmediately "${l_saveBackStatus}"

  #将内存中的l_targetYamlFile文件内容写入文件中。
  l_srcContent="${gFileContentMap[${l_targetYamlFile}]}"
  if [[ "${l_srcContent}" ]];then
    info "将${l_targetYamlFile##*/}文件的内容回写到文件中"
    echo -e "${l_srcContent}" > "${l_targetYamlFile}"
  fi

  gDefaultRetVal="true"
}

function showCachedParamPathStatus() {
  export gFileDataBlockMap

  local l_fileName=$1
  local l_item

  # shellcheck disable=SC2068
  for l_item in ${!gFileDataBlockMap[@]};do
    if [[ ! "${l_fileName}" || ${l_item} =~ ^(${l_fileName//\./\\\.}) ]];then
      info "${l_item} => ${gFileDataBlockMap[${l_item}]}"
    fi
  done
}

#获取字符串前导空格数量
function getPrefixSpaceNum() {
  _getPrefixSpaceNum "${@}"
}

#将字符串按换行符转换为字符串数组。
function stringToArray() {
  local l_content=$1
  local l_arrayName=$2
  #行隔离符，默认为'\n'
  local l_lineSplitChar=$3

  local l_arrayLen
  local l_line
  local l_ifs

  if [ ! "${l_lineSplitChar}" ];then
    #先将空格替换为l_replaceStr。
    l_lineSplitChar=$'\n'
  fi

  l_content=$(echo -e "${l_content}")

  l_ifs=${IFS}
  IFS=${l_lineSplitChar} read -rd '' -a "${l_arrayName}" <<<"${l_content}"
  IFS=${l_ifs}

  l_arrayLen=$(eval "echo -e \${#${l_arrayName}[@]}")
  if [ "${l_arrayLen}" -ge 1 ];then
    ((l_arrayLen = l_arrayLen - 1))
    #删除最后一行的换行符
    l_line=$(eval "echo -e \"\${${l_arrayName}[${l_arrayLen}]}\"")
    l_line=$(echo -e "${l_line}" | tr -d '\n')
    l_line="${l_line//\$/\\\$}"
    l_line="${l_line//\"/\\\"}"
    eval "${l_arrayName}[${l_arrayLen}]=\"${l_line}\""
  fi
}

#-------------------------------------私有方法-------------------------------------------#

function _readOrWriteYamlFile() {
  export gDefaultRetVal
  export gFileDataBlockMap

  local l_params
  local l_paramsLen
  local l_mode
  local l_yamlFile

  #以"_"开头的变量会在子函数内使用。
  local l_paramPath
  local l_tmpParamPath
  local l_curParamPath
  local l_cacheSize
  local l_cachedParamKey
  local l_paramArray

  local _deletedParamPath
  local _cachedParamKeys

  l_params=("${@}")
  l_paramsLen=${#l_params[@]}
  if [ "${l_paramsLen}" -lt 3 ];then
    error "_readOrWriteYamlFile方法调用参数不足：最少需要3个参数。"
  fi

  l_mode="${l_params[0]}"
  l_yamlFile="${l_params[1]}"
  l_paramPath="${l_params[2]}"

  if [[ "${l_paramPath}" =~ ^(.*)\.(.*)$ ]];then
    ((_addParamPathCount = 0))
    #读取缓存数据的条数。
    l_cacheSize="${#gFileDataBlockMap[@]}"
    #如果条数大于0，则尝试检索路径匹配的缓存数据。
    if [ "${l_cacheSize}" -gt 0 ];then
      #按参数路径回退查找匹配的缓存数据。
      _cachedParams=""
      l_curParamPath="${l_paramPath}"
      while [ "${l_curParamPath}" ]; do

        if [[ "${l_curParamPath}" =~ ^(.*)\[[0-9]+\]$ ]];then
          l_curParamPath="${l_curParamPath%[*}"
        elif [[ "${l_curParamPath}" =~ ^(.*)\.(.*)$ ]];then
          l_curParamPath="${l_curParamPath%.*}"
        else
          l_curParamPath=""
          continue
        fi

        #替换参数中的"["、"]"字符。
        l_tmpParamPath="${l_curParamPath//\[/#}"
        l_tmpParamPath="${l_tmpParamPath//\]/#}"
        #获取l_cachedParamKey参数。
        l_cachedParamKey="${l_yamlFile}#${l_tmpParamPath}"
        #读取缓存数据
        _cachedParams="${gFileDataBlockMap[${l_cachedParamKey}]}"
        if [ "${_cachedParams}" ];then
          #echo "命中---${l_cachedParamKey}=>${_cachedParams}--"
          _deletedParamPath="${l_curParamPath}"
          break
        fi
      done

      if [ "${_cachedParams}" ];then
        #debug "载入缓存中匹配的参数:${l_cachedParamKey}=>${_cachedParams}"
        l_tmpParamPath="${l_paramPath:${#l_curParamPath}}"
        l_tmpParamPath="${l_tmpParamPath:1}"
        # shellcheck disable=SC2206
        l_paramArray=(${_cachedParams//,/ })
        #解析缓存的读取参数。
        l_params[2]="${l_tmpParamPath}"
        [[ "${l_paramsLen}" -lt 4 ]] && l_params[3]=""
        l_params[4]="${l_paramArray[0]}"
        l_params[5]="${l_paramArray[1]}"
        l_params[6]="${l_paramArray[2]}"
        l_params[7]="${l_paramArray[3]}"
        _cachedParams=""
      fi
    fi

    _cachedParamKeys=""
    # shellcheck disable=SC2145
    __readOrWriteYamlFile "${l_params[@]}"

    #根据操作模式的不同，对缓存的参数进行更新或调整。
    case ${l_mode} in
       "read"|"rowRange")
         #不需要处理
         ;;
       "update"|"insert")
         if [[ "${gDefaultRetVal}" =~ ^(\-1) && "${_cachedParamKeys}" ]];then
           #清除更新过程中受到影响的参数路径和文件内容缓存。
           # shellcheck disable=SC2206
           l_paramArray=(${_cachedParamKeys})
           # shellcheck disable=SC2068
           for l_cachedParamKey in ${l_paramArray[@]};do
             unset gFileDataBlockMap["${l_cachedParamKey}"]
           done
           #清除文件内容缓存。
           clearCachedFileContent "${l_yamlFile}"
           return
         fi
         #更新模式下：对缓存数据进行更新调整
         _adjustCachedParamsAfterUpdate "${l_yamlFile}" "${l_paramPath}" "${gDefaultRetVal}"
         ;;
       "delete")
         if [[  ! "${gDefaultRetVal}" =~ ^(\-1) ]];then
           #删除模式下：对缓存数据进行删除调整
           _adjustCachedParamsAfterDelete "${l_yamlFile}" "${l_paramPath}" "${gDefaultRetVal}"
         fi
         ;;
     esac
  else
    # shellcheck disable=SC2145
    __readOrWriteYamlFile "${@}"
  fi
}

function __readOrWriteYamlFile() {
  export gDefaultRetVal
  export gFileContentMap
  export gFileDataBlockMap
  export gSaveBackImmediately
  #保存已被处理过的参数路径。
  export _deletedParamPath

  #---------------参数初始化开始-----------------------#

  #模式：read、rowRange、update、insert、delete
  local l_mode=$1
  local l_yamlFile=$2
  local l_paramPath=$3
  local l_paramValue=$4
  #数据块的起始行号
  local l_dataBlockStartRowNum=$5
  #数据块的截止行号
  local l_dataBlockEndRowNum=$6
  #数据块内部前导空格数量。
  local l_dataBlockPrefixSpaceNum=$7
  #上一层参数的数组项序号。
  local l_lastArrayIndex=$8
  #l_mode=read时，返回数据是否保持原始格式：true——不删除前导空格；false——删除前导空格。
  local l_keepOriginalFormat=$9
  #累计已经新增的总行数。
  # shellcheck disable=SC2034
  local l_addTotalLineCount=${10}
  #l_isDataBlock=true时：
  #l_dataBlockStartRowNum——数据块的起始行号（含）。
  #l_dataBlockEndRowNum——数据块的截止行号（含）。
  #l_dataBlockPrefixSpaceNum——数据块的前导空格数量
  #l_isDataBlock=false时：
  #l_dataBlockStartRowNum——是父级参数所在的行号。
  #l_dataBlockEndRowNum——等于l_dataBlockStartRowNum。
  #l_dataBlockPrefixSpaceNum——l_dataBlockStartRowNum行的前导空格数量
  # shellcheck disable=SC2034
  local l_isDataBlock=${11}

  local l_pathArray
  local l_curParamPath
  local l_curParamName
  local l_curItemIndex

  local l_content
  local l_tmpSpaceNum
  #查找参数的正则匹配字符串
  local l_paramMatchRegex

  local l_array
  local l_curParamRowNum
  local l_curParamPrefixSpaceNum
  #当前参数所在行是否有列表项前缀符"-"
  local l_curParamHasListItemPrefix

  local l_blockStartRowNum
  local l_blockEndRowNum
  local l_blockPrefixSpaceNum
  local l_itemCount
  #最后一次增加的列表项数量
  local l_lastAddItemCount
  #增加列表项的同时删除的文件行数。
  local l_lastDelLineCount

  #l_yamlFile文件内容变量。
  #会在子函数中使用。
  local _yamlFileContent

  if [ ! "${l_paramPath}" ];then
    error "__readOrWriteYamlFile方法传入参数l_paramPath不能为空"
  fi

  #将l_paramPath参数转成数组。
  # shellcheck disable=SC2206
  l_pathArray=(${l_paramPath//./ })
  #获得第一个参数路径的名称。
  l_curParamPath="${l_pathArray[0]}"
  #获取“[”字符前面部分的参数
  l_curParamName="${l_curParamPath%%[*}"
  #获取参数路径的数组下标值。
  ((l_curItemIndex=-1))
  if [[ "${l_curParamPath}" =~ ^(.*)\[(.*)$ ]];then
    #获取存在的数组下标值。
    l_curItemIndex="${l_curParamPath##*[}"
    l_curItemIndex="${l_curItemIndex%]*}"
  fi

  if [ "${gEnableCache}" == "true" ];then
    _deletedParamPath="${_deletedParamPath}.${l_curParamPath}"
    [[ "${_deletedParamPath}" =~ ^(\./) ]] && _deletedParamPath="${_deletedParamPath:2}"
  fi

  if [ ! -f "${l_yamlFile}" ];then
    #不是插入模式则报错退出。
    if [[ "${l_mode}" != "insert" ]];then
      error "目标文件${l_yamlFile}不存在"
    else
      #文件不存在且是插入模式，则直接创建文件。
      touch "${l_yamlFile}"
    fi
  fi

  #内存缓存校验
  if [ -z "${_yamlFileContent}" ]; then
    #尝试从文件内容Map中获取到当前文件内容的内存缓存。
    _yamlFileContent="${gFileContentMap[${l_yamlFile}]}"
  fi

  if [ -z "${_yamlFileContent}" ];then
    #初始化文件内容在内存中的缓存。
    _yamlFileContent=$(<"${l_yamlFile}")
    gFileContentMap["${l_yamlFile}"]="${_yamlFileContent}"
    info "读取${l_yamlFile##*/}文件内容并缓存到内存中"
  fi

  #如果数据块截止行号无效，则从文件中读取数据块的起止行号。
  if [[ ! "${l_dataBlockEndRowNum}" || "${l_dataBlockEndRowNum}" -le 0 ]];then
    ((l_dataBlockStartRowNum = 1))
    ((l_dataBlockEndRowNum = 1))
    ((l_dataBlockPrefixSpaceNum=0))
    if [ "${_yamlFileContent}" ];then
      #文件存在且不是空的，则读取第一个有效行。
      l_content=$(awk 'match($0,/^ *[[:alnum:]_-]+/) {print NR ":" substr($0,RSTART,RLENGTH); exit}' <<< "${_yamlFileContent}")
      if [ "${l_content}" ];then
        #文件中存在有效行，则设置l_dataBlockStartRowNum的值。
        l_dataBlockStartRowNum=${l_content%%:*}
        #获取数据块的默认前导空格数量。
        [[ "$l_content" =~ ^[[:space:]]* ]] && l_dataBlockPrefixSpaceNum=${#BASH_REMATCH[0]}
        #直接截取指定行号之后的内容
        l_content=$(sed -n "${l_dataBlockStartRowNum},\$p" <<< "${_yamlFileContent}")
        #获取最后一个有效键名及其所在行号。
        l_content=$(awk 'match($0,/^ *[[:alnum:]_-]+/){line=NR ":" substr($0,RSTART,RLENGTH)} END{print line}' <<< "${l_content}")
        #获取行号
        l_dataBlockEndRowNum="${l_content%%:*}"
        ((l_dataBlockEndRowNum = l_dataBlockStartRowNum + l_dataBlockEndRowNum - 1))
      fi
    fi
  fi

  if [ ! "${l_keepOriginalFormat}" ];then
    l_keepOriginalFormat="false"
  fi

  if [ ! "${l_lastArrayIndex}" ];then
    l_lastArrayIndex="-1"
  fi

  if [ ! "${l_addTotalLineCount}" ];then
    ((l_addTotalLineCount = 0))
  fi

  if [ ! "${l_isDataBlock}" ];then
    l_isDataBlock="true"
  fi

  #---------------参数初始化结束-----------------------#

  #1. 在数据块范围内查找l_curParamName参数的位置

  #确定参数匹配正则字符串。
  if [ "${l_isDataBlock}" == "true" ];then
    if [ "${l_lastArrayIndex}" -ge 0 ];then
      #是列表项的情况：目标参数可能存在列表项的第一行，也可能在后续行中，因此正则式有两种情况。
      ((l_tmpSpaceNum = l_dataBlockPrefixSpaceNum + 2))
      l_paramMatchRegex="^(([ ]{${l_dataBlockPrefixSpaceNum}}- ${l_curParamName}:)|([ ]{${l_tmpSpaceNum}}${l_curParamName}:))"
    else
      #不是列表项的情况：正则式只有一种。
      l_paramMatchRegex="^([ ]{${l_dataBlockPrefixSpaceNum}}${l_curParamName}:)"
    fi
    #目标参数定位查询：获取文件中指定范围内层级最浅的第一个符合条件的l_curParamName参数所在行号和前导空格数量
    _getRowNumAndPrefixSpaceNum "${l_yamlFile}" "${l_paramMatchRegex}" "${l_dataBlockStartRowNum}" "${l_dataBlockEndRowNum}"
  else
    #直接设置目标参数定位查询的结果值。
    gDefaultRetVal="-1 -1 false"
  fi

  # shellcheck disable=SC2206
  l_array=(${gDefaultRetVal})
  #数据块中目标参数所在行号
  l_curParamRowNum="${l_array[0]}"

  if [ "${l_curParamRowNum}" -eq -1 ];then
    #目标参数没有找到，则根据操作模式进行不同的处理。
    case "${l_mode}" in
      "read")
        #读取模式下返回null表示读取失败。
        gDefaultRetVal="null"
        return
        ;;
      "update")
        #更新模式下返回-1表示更新失败。
        #返回格式：更新的起始行号、截至行号、数组或列表的总项数、更新内容过程中新增的总行数、更新过程中中删除的总行数。
        gDefaultRetVal="-1 -1 -1 0 0"
        return
        ;;
      "delete")
        #返回错误信息格式：${删除的起始行号(含)} ${删除的截至行号(含)} ${实际删除的行数} ${删除的目标列表项序号} ${删除前列表项总数}
        gDefaultRetVal="-1 -1 0"
        return
        ;;
      "rowRange")
        #行范围读取模式下返回-1，表示读参数行范围失败。
        #返回格式：起始行号、截至行号
        gDefaultRetVal="-1 -1"
        return
        ;;
      "insert")
        #插入模式下：自动创建缺失的参数路径，不创建缺失的列表项。
        _insertParamDirectly "${l_yamlFile}" "${l_curParamName}" "${l_dataBlockStartRowNum}" "${l_dataBlockEndRowNum}" \
          "${l_dataBlockPrefixSpaceNum}" "${l_isDataBlock}"
        # shellcheck disable=SC2206
        l_array=(${gDefaultRetVal})
        l_curParamRowNum="${l_array[0]}"
        l_curParamPrefixSpaceNum="${l_array[1]}"
        l_curParamHasListItemPrefix="${l_array[2]}"
        #因插入了新的行，因此要增大数据范围
        # shellcheck disable=SC2004
        ((l_dataBlockEndRowNum = l_dataBlockEndRowNum + ${l_array[3]}))
        #累计新增的行数。
        # shellcheck disable=SC2004
        ((l_addTotalLineCount = l_addTotalLineCount + ${l_array[3]}))
        ;;
      *)
        error "不存在的操作模式：${l_mode}"
        ;;
      esac
  else
    #目标参数行的前导空格数量。
    l_curParamPrefixSpaceNum="${l_array[1]}"
    #目标参数行是否存在列表项前缀符"-"
    l_curParamHasListItemPrefix="${l_array[2]}"
  fi

  ((l_itemCount = 0))
  ((l_lastAddLineCount = 0))

  #获取参数下属数据块的起止行号, 会自动创建缺失的列表项。
  _getDataBlockRowNum "${l_mode}" "${l_yamlFile}" "${l_curParamRowNum}" "${l_dataBlockEndRowNum}" "${l_curItemIndex}" \
    "${l_curParamPrefixSpaceNum}" "${l_curParamHasListItemPrefix}"
  #echo "===2===${l_curParamName}===|${l_curParamRowNum} ${l_dataBlockEndRowNum} ${l_curItemIndex} ${l_curParamPrefixSpaceNum} ${l_curParamHasListItemPrefix}|====${gDefaultRetVal}========"
  #_getDataBlockRowNum返回数据格式：
  #{数据块的起始行号} {数据块的截止行号} {数据块的前导空格数} {现有列表项总数} {执行过程中新增的列表项数} {执行过程中删除的文件行数}
  # shellcheck disable=SC2206
  l_array=(${gDefaultRetVal})
  #l_curParamRowNum参数下属的数据块起始行号
  l_blockStartRowNum="${l_array[0]}"
  #l_curParamRowNum参数下属的数据块截止行号
  l_blockEndRowNum="${l_array[1]}"
  if [[ "${l_curItemIndex}" -ge 0 && "${l_curItemIndex}" -ge "${l_array[3]}" ]];then
    #处理指定序号的列表项不存在的情况
    case "${l_mode}" in
      "read"|"rowRange")
        #返回错误信息格式。
        [[ "${l_mode}" == "read" ]] && gDefaultRetVal="null"
        #rowRange模式，返回起止行号
        [[ "${l_mode}" == "rowRange" ]] && gDefaultRetVal="-1 -1"
        return
        ;;
      "update")
        gDefaultRetVal="-1 -1 ${l_itemCount} 0 0"
        return
        ;;
      "insert")
        if [ "${l_curItemIndex}" -gt "${l_array[3]}" ];then
          warn "${l_mode}模式下，将在数组或列表的尾部追加多个新项"
        fi
        ;;
      "delete")
        #返回错误信息格式：${删除的起始行号(含)} ${删除的截至行号(含)} ${实际删除的行数} ${删除的目标列表项序号} ${删除前列表项总数}
        gDefaultRetVal="-1 -1 0 ${l_curItemIndex} ${l_array[3]}"
        return
        ;;
      *)
        error "不存在的操作模式：${l_mode}"
        return
        ;;
    esac
  elif [[ "${l_blockStartRowNum}" -ge 1 && "${l_blockStartRowNum}" -gt "${l_curParamRowNum}" ]];then
    #l_curParamRowNum参数下属的数据块截止行号
    l_blockPrefixSpaceNum="${l_array[2]}"
    l_isDataBlock="true"
    if [[ "${l_curItemIndex}" -ge 0 ]];then
      l_itemCount="${l_array[3]}"
      #获得新增的列表项数量。
      ((l_lastAddItemCount = l_array[4]))
      #获得新增列表项的同时删除的文件行数。
      ((l_lastDelLineCount = l_array[5]))
      #累计增加的新行数
      ((l_addTotalLineCount = l_addTotalLineCount + l_lastAddItemCount - l_lastDelLineCount))
    fi
  else
    #此时说明l_curParamRowNum参数没有下属数据块(新插入的属性)。
    ((l_blockStartRowNum = l_curParamRowNum))
    ((l_blockEndRowNum = l_blockStartRowNum))
    ((l_blockPrefixSpaceNum = l_curParamPrefixSpaceNum))
    l_isDataBlock="false"
  fi

  #还存在下级参数，并且是数据块或插入模式，则继续递归处理。
  if [[ "${l_paramPath}" =~ ^(.*)\.(.*)$ && ( "${l_isDataBlock}" == "true" || "${l_mode}" == "insert" ) ]];then
    #即使l_blockStartRowNum和l_blockEndRowNum仍然指向的是参数行，但是l_blockPrefixSpaceNum参数需要加2.
    #[[ "${l_isDataBlock}" == "false" ]] && ((l_blockPrefixSpaceNum = l_blockPrefixSpaceNum + 2))
    if [[ "${gEnableCache}" && "${l_isDataBlock}" == "true" ]];then
      #缓存参数路径上的状态数据。
      l_cachedParamKey="${l_yamlFile}#${_deletedParamPath}"
      _cachedParamKeys="${_cachedParamKeys} ${l_cachedParamKey}"
      l_cachedParamKey="${l_cachedParamKey//\[/#}"
      l_cachedParamKey="${l_cachedParamKey//\]/#}"
      gFileDataBlockMap["${l_cachedParamKey}"]="${l_blockStartRowNum} ${l_blockEndRowNum} ${l_blockPrefixSpaceNum} ${l_curItemIndex}"
    fi

    #更新Map缓存中的值。
    gFileContentMap["${l_yamlFile}"]="${_yamlFileContent}"

    #删除第一个参数。
    l_paramPath="${l_paramPath#*.}"

    #继续递归处理。
    __readOrWriteYamlFile "${l_mode}" "${l_yamlFile}" "${l_paramPath}" "${l_paramValue}" \
      "${l_blockStartRowNum}" "${l_blockEndRowNum}" "${l_blockPrefixSpaceNum}" "${l_curItemIndex}" \
      "${l_keepOriginalFormat}" "${l_addTotalLineCount}" "${l_isDataBlock}"
    return
  fi

  #则根据操作模式进行不同的返回处理。
  case "${l_mode}" in
    "read"|"rowRange")
      if [[ "${l_paramPath}" =~ ^(.*)\.(.*)$ ]];then
        #返回错误信息格式。
        [[ "${l_mode}" == "read" ]] && gDefaultRetVal="null"
        #rowRange模式，返回起止行号
        [[ "${l_mode}" == "rowRange" ]] && gDefaultRetVal="-1 -1"
        return
      fi

      if [ "${l_mode}" == "rowRange" ];then
        gDefaultRetVal="${l_blockStartRowNum} ${l_blockEndRowNum}"
        return
      fi

      #读取l_rowNum行与l_endRowNum行间的内容。
      _readDataBlock "${l_yamlFile}" "${l_blockStartRowNum}" "${l_blockEndRowNum}" "${l_curItemIndex}" "${l_isDataBlock}"

      if [ "${gDefaultRetVal}" != "null" ];then
        #获取并调整读取的数据块内容，并返回之。
        _getReadContent "${l_yamlFile}" "${l_curParamName}" "${l_curParamRowNum}" "${gDefaultRetVal}" "${l_curItemIndex}" \
          "${l_keepOriginalFormat}" "${l_isDataBlock}"
      fi
      ;;
    "update"|"insert")
      if [[ "${l_paramPath}" =~ ^(.*)\.(.*)$ ]];then
        #返回格式：更新的起始行号、截至行号、数组或列表的总项数、更新内容过程中新增的总行数、更新过程中中删除的总行数。
        gDefaultRetVal="-1 -1 ${l_itemCount} 0 0"
        return
      fi
      _updateParam "${l_yamlFile}" "${l_curParamRowNum}" "${l_blockStartRowNum}" "${l_blockEndRowNum}" "${l_curItemIndex}" \
        "${l_paramValue}" "${l_itemCount}"
      if [[ ! ("${gDefaultRetVal}" =~ ^(\-1)) ]];then
        #更新内存中的文件内容。
        gFileContentMap["${l_yamlFile}"]="${_yamlFileContent}"
        if [[ "${gSaveBackImmediately}" == "true" ]];then
          #将内存中的文件内容一次性回写到文件中
          echo -e "${_yamlFileContent}" > "${l_yamlFile}"
        fi

        #如果l_addTotalLineCount大于0，则要在返回的新增行数参数(l_array[3])中加上l_addTotalLineCount的数量。
        if [[ "${l_addTotalLineCount}" -gt 0 ]];then
          #如果最后一次新增的列表项数量大于0。则先要减去1避免重复计算内容占据的第一行。
          [[ "${l_lastAddItemCount}" -gt 0 ]] && ((l_addTotalLineCount = l_addTotalLineCount - 1))
          # shellcheck disable=SC2206
          l_array=(${gDefaultRetVal})
          ((l_array[3] = l_array[3] + l_addTotalLineCount))
          # shellcheck disable=SC2124
          gDefaultRetVal="${l_array[@]}"
        fi
      else
        #执行失败后，清除这个缓存,避免部分更新的情况，以便下次重新从文件中读取原始内容。
        unset gFileContentMap["${l_yamlFile}"]
      fi
      ;;
    "delete")
      if [[ "${l_paramPath}" =~ ^(.*)\.(.*)$ ]];then
        #返回错误信息格式：${删除的起始行号(含)} ${删除的截至行号(含)} ${实际删除的行数} ${删除的目标列表项序号} ${删除前列表项总数}
        gDefaultRetVal="-1 -1 0 ${l_curItemIndex} ${l_itemCount}"
        return
      fi

      if [ "${l_curItemIndex}" -ge 0 ];then
        #删除指定参数
        _deleteParam "${l_yamlFile}" "${l_blockStartRowNum}" "${l_blockEndRowNum}" "${l_curItemIndex}"
      else
        #删除指定参数
        _deleteParam "${l_yamlFile}" "${l_curParamRowNum}" "${l_blockEndRowNum}" "${l_curItemIndex}"
      fi

      if [[ ! "${gDefaultRetVal}" =~ ^(\-1) ]];then
        #更新内存中的文件内容。
        gFileContentMap["${l_yamlFile}"]="${_yamlFileContent}"
        if [[ "${gSaveBackImmediately}" == "true" ]];then
          #将内存中的文件内容一次性回写到文件中
          echo -e "${_yamlFileContent}" > "${l_yamlFile}"
        fi
      fi
      gDefaultRetVal="${gDefaultRetVal} ${l_curItemIndex} ${l_itemCount}"
      ;;
    *)
      error "不存在的操作模式：${l_mode}"
      ;;
  esac

}

#不检查是否已经存在，直接插入指定的参数
function _insertParamDirectly(){
  export gDefaultRetVal
  export gFileContentMap
  export _yamlFileContent

  #目标yaml文件
  local l_yamlFile=$1
  #要插入的参数名称
  local l_paramName=$2
  #数据块的起始行行号
  local l_blockStartRowNum=$3
  #数据块的截至行行号
  local l_blockEndRowNum=$4
  #数据块的前缀空格数量。
  local l_blockPrefixSpaceNum=$5
  #是否是数据块。
  local l_isDataBlock=$6

  local l_lineContent
  local l_content
  local l_hasListItemPrefix
  local l_tmpSpaceStr
  local l_tmpContent
  local l_maxRowNum
  local l_flag
  local l_tmpRowNum
  local l_tmpRowNum1
  local l_tmpSpaceNum
  local l_addTotalLineCount

  #如果文件内容是空的，则直接插入参数。
  if [ -z "${_yamlFileContent}" ];then
    _yamlFileContent="${l_paramName}:"
    #返回插入参数所在行行号、参数所在行的前导空格数量、参数所在行是否有列表项前缀符"-"。
    gDefaultRetVal="1 0 false 0"
    return
  fi

  l_hasListItemPrefix="false"

  #读取l_blockStartRowNum行上的数据
  #l_content=$(sed -n "${l_blockStartRowNum}p" "${l_yamlFile}")
  l_content=$(sed -n "${l_blockStartRowNum}p" <<< "${_yamlFileContent}")
  #保留l_blockStartRowNum行原始内容到l_lineContent变量中。
  l_lineContent="${l_content}"
  if [[ "${l_content}" && "${l_content}" =~ ^([ ]*)\- ]];then
    l_tmpSpaceStr="${l_content%%-*}"
    l_blockPrefixSpaceNum="${#l_tmpSpaceStr}"
    if [[ "${l_content}" =~ ^([ ]*)\-([ ]*)$ ]];then
      #是空的列表项的情况，则直接在l_blockStartRowNum行上插入参数。
      l_content="${l_tmpSpaceStr}- ${l_paramName}:"
      l_flag="c"
      l_tmpRowNum="${l_blockStartRowNum}"
      l_hasListItemPrefix="true"
    else
      [[ "${l_isDataBlock}" == "true" ]] && ((l_blockPrefixSpaceNum = l_blockPrefixSpaceNum + 2 ))
      #是列表项，但不是空的，则需要在l_blockStartRowNum行的最后一个兄弟行的下一行插入新的兄弟行参数。
      l_content="${l_tmpSpaceStr}  ${l_paramName}:"
      l_flag="a"
      #先暂时设置为l_blockEndRowNum
      l_tmpRowNum="${l_blockEndRowNum}"
    fi
  else
    #不是列表项且不是数据块的情况（而是父级参数所在行的情况），前导空格需要加2.
    [[ "${l_isDataBlock}" == "false" ]] && ((l_blockPrefixSpaceNum = l_blockPrefixSpaceNum + 2))
    #构造前导空格串
    l_tmpSpaceStr=$(printf "%${l_blockPrefixSpaceNum}s")
    #构造新行数据内容。
    l_tmpContent="${l_tmpSpaceStr}${l_paramName}:"

    if [ ! "${l_content}" ];then
      #如果l_blockStartRowNum行上的数据是空的，则直接在l_blockStartRowNum行插入新参数。
      l_flag="c"
      l_tmpRowNum="${l_blockStartRowNum}"
    else
      #如果l_blockStartRowNum行上存在数据，则在l_blockStartRowNum行的最后一个兄弟行的下一行插入新参数。
      l_flag="a"
      #如果l_blockStartRowNum行存在值域，则需要清空。
      if [[ "${l_isDataBlock}" == "false" && "${l_content}" =~ ^([ ]*)([a-zA-Z_\-]+)([a-zA-Z0-9_\-]+):(.*)$ ]];then
        l_content="${l_content%%:*}:"
        _yamlFileContent=$(sed "${l_blockStartRowNum}c\\${l_content}" <<< "${_yamlFileContent}")
        #更新l_blockStartRowNum行的原始内容。
        l_lineContent="${l_content}"
      fi
      #先暂时设置为l_blockEndRowNum
      l_tmpRowNum="${l_blockEndRowNum}"
      l_content="${l_tmpContent}"
    fi
  fi

  ((l_addTotalLineCount = 0))
  if [[ "${l_flag}" == "a" ]];then
    ((l_addTotalLineCount = 1))

    if [ "${l_blockPrefixSpaceNum}" -gt 0 ];then
      if [[ "${l_blockStartRowNum}" -lt "${l_blockEndRowNum}" ]];then
        #查找l_blockStartRowNum行的最后一个兄弟行的行号。
        ((l_tmpRowNum1 = l_blockStartRowNum + 1))

        l_tmpContent=$(sed -n "${l_tmpRowNum1},${l_blockEndRowNum}p" <<< "${_yamlFileContent}")

        if [ "${l_tmpContent}" ];then
          #查找l_tmpContent中l_tmpRowNum1行后面的第一个父级行。
          ((l_tmpSpaceNum = l_blockPrefixSpaceNum - 2))
          l_tmpContent=$(grep -m 1 -noE "^[ ]{0,${l_tmpSpaceNum}}[[:alnum:]_-]+" <<< "${l_tmpContent}")
          if [ "${l_tmpContent}" ];then
            l_tmpRowNum1="${l_tmpContent%%:*}"
            ((l_tmpRowNum = l_blockStartRowNum + 1 + l_tmpRowNum1 - 2))
          fi
        fi
      fi
    fi

    l_lineContent=$(sed -n "${l_tmpRowNum}p" <<< "${_yamlFileContent}")

    l_content="${l_lineContent}\n${l_content}"
    ((l_blockStartRowNum = l_tmpRowNum + 1))
  fi

  _yamlFileContent=$(sed "${l_tmpRowNum}c\\${l_content}" <<< "${_yamlFileContent}")
  #格式化一次，使l_content中的换行符起效。
  _yamlFileContent=$(echo -e "${_yamlFileContent}")

  #返回插入参数所在行行号、参数所在行的前导空格数量、参数所在行是否有列表项前缀符"-"。
  gDefaultRetVal="${l_blockStartRowNum} ${l_blockPrefixSpaceNum} ${l_hasListItemPrefix} ${l_addTotalLineCount}"

}

function _deleteParam() {
  export gDefaultRetVal
  export gFileContentMap
  export _yamlFileContent

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_endRowNum=$3
  local l_arrayIndex=$4

  local l_rowData
  local l_array
  local l_arrayLen
  local l_i
  local l_newRowData

  #读取l_startRowNum行的数据。
  #l_rowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
  l_rowData=$(sed -n "${l_startRowNum}p" <<< "${_yamlFileContent}")
  #处理删除数组项操作。
  if [[ "${l_startRowNum}" -eq "${l_endRowNum}" && "${l_rowData}" =~ ^(.*)(:[ ]+)\[.*\]([ ]*)$ ]];then
    l_newRowData="${l_rowData#*:}"
    l_newRowData="${l_newRowData#*[}"
    l_newRowData="${l_newRowData%]*}"
    # shellcheck disable=SC2206
    l_array=(${l_newRowData//,/ })
    l_arrayLen="${#l_array[@]}"
    l_newRowData=""
    if [ "${l_arrayIndex}" -lt "${l_arrayLen}" ];then
      for ((l_i=0; l_i < l_arrayLen; l_i++));do
        [[ "${l_i}" -ne "${l_arrayIndex}" ]] && l_newRowData="${l_newRowData},${l_array[${l_i}]}"
      done
      if [ "${l_newRowData}" ];then
        l_newRowData="${l_newRowData:1}"
      fi
      l_newRowData="${l_rowData%%:*}: [${l_newRowData}]"
      #更新文件内容。
      #sed -i "${l_startRowNum}c \\${l_newRowData}" "${l_yamlFile}"
      _yamlFileContent=$(sed "${l_startRowNum}c\\${l_newRowData}" <<< "${_yamlFileContent}")
      gDefaultRetVal="${l_startRowNum} ${l_startRowNum} 0 ${l_arrayIndex} ${l_arrayLen}"
    else
      #直接返回失败。
      gDefaultRetVal="-1 -1 0 ${l_arrayIndex} ${l_arrayLen}"
    fi
  else
    #在文件指定的起始行（包含）位置删除内容
    _deleteContentInFile "${@}"
    gDefaultRetVal="${gDefaultRetVal} ${l_arrayIndex} ${l_arrayLen}"
  fi

}

#使用新的内容替换yaml文件中指定的起始行和截至行的内容
function _updateParam() {
  export gDefaultRetVal
  local l_arrayIndex=$5
  #结合新值和旧值，判断修改的方式。
  if [ "${l_arrayIndex}" -lt 0 ];then
    #不是数组项或列表项
    _updateNotListOrArrayParam "${@}"
  else
    #是数组项或列表项
    _updateListOrArrayParam "${@}"
  fi
}

#更新非数组项或非列表项参数
function _updateNotListOrArrayParam() {
  export gDefaultRetVal

  local l_yamlFile=$1
  #参数名称所在行
  local l_startRowNum=$2
  #参数数据块起始行号
  local l_blockStartRowNum=$3
  #参数数据块截至行号
  local l_blockEndRowNum=$4
  local l_arrayIndex=$5
  local l_newContent=$6

  local l_array
  local l_deletedRowNum

  ((l_deletedRowNum = 0))
  #直接用新内容替换从(l_startRowNum + 1)行到l_blockEndRowNum行间的所有内容：
  #1.如果新内容是简单值（新内容中不包含”:“），则将新内容更新到l_startRowNum行上。
  if [ ! "${l_newContent}" ];then
    #删除原有的数据块
    if [ "${l_blockStartRowNum}" -gt "${l_startRowNum}" ];then
      ((l_blockStartRowNum = l_startRowNum + 1))
      _deleteContentInFile "${l_yamlFile}" "${l_blockStartRowNum}" "${l_blockEndRowNum}" "${l_arrayIndex}"
      # shellcheck disable=SC2206
      l_array=(${gDefaultRetVal})
      ((l_deletedRowNum = l_array[2]))
    fi
    _updateSingleRowValue "${l_yamlFile}" "${l_startRowNum}" ""
    gDefaultRetVal="${gDefaultRetVal} 0 ${l_deletedRowNum}"
  else
    #整理一下格式，使能换行符
    l_newContent=$(echo -e "${l_newContent}")
    #计算l_newContent的行数(会删除末尾的空行)。
    l_newLineCount=$(grep -cE "^([ ]*).*$" <<< "${l_newContent}")
    if [[ ! ("${l_newContent}" =~ ^([ ]*)(\-)) && "${l_newLineCount}" -eq 1 ]];then
      #删除原有的数据块
      if [  "${l_blockStartRowNum}" -gt "${l_startRowNum}" ];then
        ((l_blockStartRowNum = l_startRowNum + 1))
        _deleteContentInFile "${l_yamlFile}" "${l_blockStartRowNum}" "${l_blockEndRowNum}" "${l_arrayIndex}"
        # shellcheck disable=SC2206
        l_array=(${gDefaultRetVal})
        ((l_deletedRowNum = l_array[2]))
      fi
      #如果新值只有一行，则调用新增单行值的更新函数。
      _updateSingleRowValue "${l_yamlFile}" "${l_startRowNum}" "${l_newContent}"
      gDefaultRetVal="${gDefaultRetVal} 0 ${l_deletedRowNum}"
    else
      #2.直接删除(l_startRowNum + 1)行到l_blockEndRowNum行间的内容。
      #(l_startRowNum + 1)并不一定等于l_blockStartRowNum行，这两行间如果存在注释行就不相等。
      #删除时应从(l_startRowNum + 1)行开始删除。
      if [  "${l_blockStartRowNum}" -gt "${l_startRowNum}" ];then
        ((l_blockStartRowNum = l_startRowNum + 1))
        _deleteContentInFile "${l_yamlFile}" "${l_blockStartRowNum}" "${l_blockEndRowNum}" "${l_arrayIndex}"
        # shellcheck disable=SC2206
        l_array=(${gDefaultRetVal})
        ((l_deletedRowNum = l_array[2]))
      fi
      #3.如果新内容是多行数据，则先过滤掉可能的以空格和/或”|“开头的第一行，将剩下的内容插入到l_startRowNum行的下一行。
      _updateMultipleRowValue "${l_yamlFile}" "${l_startRowNum}" "${l_newContent}" "${l_newLineCount}"
      [[ "${l_newContent}" =~ ^([ ]*)\| ]] && ((l_newLineCount = l_newLineCount - 1))
      gDefaultRetVal="${gDefaultRetVal} ${l_newLineCount} ${l_deletedRowNum}"
    fi
  fi

}

#更新数组项或列表项参数
function _updateListOrArrayParam() {
  export _yamlFileContent

  local l_yamlFile=$1
  #参数名称所在行
  local l_startRowNum=$2
  local l_arrayIndex=$5
  local l_newContent=$6

  local l_startRowData

  #先读取l_startRowNum行的数据，判断是列表还是数组？
  #如果l_startRowNum行能匹配^(.*)(:[ ]+)\[.*\]([ ]*)$，则说明是数组格式，否则清除l_startRowNum行的值域，并认定为列表格式。
  #l_startRowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
  l_startRowData=$(sed -n "${l_startRowNum}p" <<< "${_yamlFileContent}")
  if [[ "${l_startRowData}" =~ ^(.*)(:[ ]+)\[.*\]([ ]*)$ ]];then
    _updateArrayParam "${l_yamlFile}" "${l_startRowNum}" "${l_startRowData}" "${l_arrayIndex}" "${l_newContent}"
  else
    #更新列表项
    _updateListParam "${@}"
  fi

}

#更新文件中数组参数的指定项的值
function _updateArrayParam() {
  export gDefaultRetVal
  export _yamlFileContent

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_startRowData=$3
  local l_arrayIndex=$4
  local l_newContent=$5

  local l_paramValue
  local l_arrayItems
  local l_itemCount
  local l_i
  local l_addCount
  local l_tmpIndex

  #获取l_startRowNum行的值域
  l_paramValue="${l_startRowData#*:}"
  l_paramValue="${l_paramValue#*[}"
  l_paramValue="${l_paramValue%]*}"

  if [ "${l_paramValue}" ];then
    #将值域字符串转换为数组。
    # shellcheck disable=SC2206
    l_arrayItems=(${l_paramValue//,/ })
    l_itemCount="${#l_arrayItems[@]}"

    if [ "${l_arrayIndex}" -lt "${l_itemCount}" ];then
      #循环读取数组项，并将l_arrayIndex项的值替换为新的值。
      l_paramValue=""
      for ((l_i = 0; l_i < l_itemCount; l_i++)){
        if [ "${l_i}" -eq "${l_arrayIndex}" ];then
          l_paramValue="${l_paramValue},${l_newContent}"
        else
          l_paramValue="${l_paramValue},${l_arrayItems[${l_i}]}"
        fi
      }
      #删除开头的","
      l_paramValue="${l_paramValue:1}"
    else
      ((l_addCount = l_arrayIndex - l_itemCount + 1))
      ((l_tmpIndex = l_addCount))
      while [ "${l_tmpIndex}" -gt 1 ];do
        l_paramValue="${l_paramValue},\"\""
        ((l_tmpIndex = l_tmpIndex -1))
      done
      #在列表项最后添加新增的项。
      l_paramValue="${l_paramValue},${l_newContent}"
      ((l_itemCount = l_itemCount + l_addCount))
    fi
  else
    #直接将l_newContent赋值给l_paramValue
    l_paramValue="${l_newContent}"
    ((l_itemCount = l_itemCount + 1))
  fi

  #更新l_startRowNum行的数据
  #sed -i "${l_startRowNum}c \\${l_startRowData%%:*}: [${l_paramValue}]" "${l_yamlFile}"
  _yamlFileContent=$(sed "${l_startRowNum}c\\${l_startRowData%%:*}: [${l_paramValue}]" <<< "${_yamlFileContent}")

  #返回信息格式：起始行号 截至行号 数组项总数 新增行数 删除行数
  gDefaultRetVal="${l_startRowNum} ${l_startRowNum} ${l_itemCount} 0 0"

}

#更新文件中指定的列表参数的指定项的值
function _updateListParam() {
  export gFileContentMap
  export _yamlFileContent

  local l_yamlFile=$1
  #参数名称所在行
  local l_startRowNum=$2
  #第l_arrayIndex项的数据块起始行号
  local l_blockStartRowNum=$3
  #第l_arrayIndex项的数据块截至行号
  local l_blockEndRowNum=$4
  local l_arrayIndex=$5
  local l_newContent=$6
  #数组项或列表项总数。
  local l_itemCount=$7

  local l_tmpSpaceNum
  local l_startRowSpaceNum
  local l_tmpSpaceNum1
  local l_content
  local l_tmpSpaceStr

  local l_addRowNum
  local l_deletedRowNum

  #如果l_newContent的第一行是以“|”行开头的，则要删除第一行。
  #需要考虑l_newContent=”.*\n.*\n“这样的格式。
  #l_content=$(echo -e "${l_newContent}" | grep -m 1 -oP "^[ ]*\|[+-]*[ ]*$")
  l_content=$(echo -e "${l_newContent}")
  l_content=$(grep -m 1 -oE "^[ ]*\|[+-]*[ ]*$" <<< "${l_content}")
  if [ "${l_content}" ];then
    l_content="${l_content%%[^ ]*}"
    l_tmpSpaceNum="${#l_content}"
    #加上行尾的换行符。
    ((l_tmpSpaceNum = l_tmpSpaceNum + 1))
    l_newContent="${l_newContent:${l_tmpSpaceNum}}"
  fi

  #计算新内容的前导空格数量
  _getPrefixSpaceNum "${l_newContent}"
  l_tmpSpaceNum="${gDefaultRetVal}"

  #todo: 这里的l_blockStartRowNum行一定是"-"开头的行。
  #todo: 如果插入的序号大于当前列表项总数，则要在_getDataBlockRowNum函数中就已经处理了。

  #计算目标列表项的前导空格数量。
  #l_content=$(sed -n "${l_blockStartRowNum}p" "${l_yamlFile}")
  #获取开始行的前导空格数量。
  l_content=$(sed -n "${l_blockStartRowNum}p" <<< "${_yamlFileContent}")
  _getPrefixSpaceNum "${l_content}"
  #得到列表项的前导空格数
  l_startRowSpaceNum="${gDefaultRetVal}"
  #目标列表项的前导空格数应该等于l_startRowSpaceNum + 2.
  ((l_tmpSpaceNum1 = l_startRowSpaceNum + 2))

  #计算应有的前导空格数与插入内容的前导空格数的差。
  ((l_tmpSpaceNum = l_tmpSpaceNum1 - l_tmpSpaceNum))
  if [ "${l_tmpSpaceNum}" -ne 0 ];then
    #调整新内容的缩进格式。
    _indentContent "${l_newContent}" "${l_tmpSpaceNum}"
    l_newContent="${gDefaultRetVal}"
  fi

  #如果新内容不是以“-”开头的，则为新内容添加“-”前缀。
  if [[ ! ("${l_newContent}" =~ ^([ ]*)(- )) ]];then
    l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum1}s")
    l_newContent="${l_tmpSpaceStr:2}- ${l_newContent:${l_tmpSpaceNum1}}"
  fi

  #将l_newContent转换为单行字符串。
  _convertToSingleRow "${l_newContent}"
  l_content="${gDefaultRetVal}"

  #如果l_blockEndRowNum行的前导空格数小于或等于l_startRowSpaceNum的值
  #说明l_blockEndRowNum行不属于列表项数据块。此时如果l_blockEndRowNum行的上方存在的注释行
  #则在l_blockEndRowNum上的上面插入新的列表项，会导致注释行与l_blockEndRowNum行分离。
  #为避免此类情况出现，这里要查找l_blockEndRowNum行的上方第一个非空有效行。


  #直接将l_content输出到l_blockStartRowNum行上（会自动换行）
  #sed -i "${l_blockStartRowNum},${l_blockEndRowNum}c \\${l_content}" "${l_yamlFile}"
  _yamlFileContent=$(sed "${l_blockStartRowNum},${l_blockEndRowNum}c\\${l_content}" <<< "${_yamlFileContent}")

  if [ "${l_blockEndRowNum}" -gt "${l_blockStartRowNum}" ];then
    #计算删除的行数。
    ((l_deletedRowNum = l_blockEndRowNum - l_blockStartRowNum + 1))
  else
    ((l_deletedRowNum = 0))
  fi

  #获取新内容的行数。
  #优化之：l_addRowNum=$(echo -e "${l_content}" | grep -oP "^([ ]*).*$" | wc -l )
  l_addRowNum=$(echo -e "${l_content}" | wc -l)
  ((l_blockEndRowNum = l_blockStartRowNum + l_addRowNum - 1))

  #返回结果
  gDefaultRetVal="${l_blockStartRowNum} ${l_blockEndRowNum} ${l_itemCount} ${l_addRowNum} ${l_deletedRowNum}"
}

#缩进内容块, l_indent为负数向左移动，为正数向右移动
function _indentContent(){
  export gDefaultRetVal

  local l_content=$1
  local l_indent=$2

  local l_tmpSpaceStr
  local l_len

  if [[ "${l_indent}" -eq 0 ]];then
    gDefaultRetVal=${l_content}
    return
  fi

  l_len="${l_indent}"
  [[ "${l_len}" -lt 0 ]] && ((l_len = 0 - l_len))
  l_tmpSpaceStr=$(printf "%${l_len}s")

  if [ "${l_indent}" -gt 0 ];then
    gDefaultRetVal=$(echo -e "${l_content}" | sed "s/^/${l_tmpSpaceStr}/")
  elif [ "${l_indent}" -lt 0 ];then
    gDefaultRetVal=$(echo -e "${l_content}" | sed "s/^${l_tmpSpaceStr}//")
  fi
}

#获取给定参数的前导空格数量。
#注意：l_content中的注释行也必須保持正确的缩进格式。
function _getPrefixSpaceNum() {
  export gDefaultRetVal
  local l_content=$1
  #如果第一行是前导竖杠，是否忽略该行而取下一有效行的前导空格。
  local l_ignoreVerticalBarRow=$2
  local l_firstLine

  if [ ! "${l_ignoreVerticalBarRow}" ];then
    l_ignoreVerticalBarRow="false"
  fi

  if [ "${l_ignoreVerticalBarRow}" == "true" ];then
    #如果第一行是空格和“|”开头的，则删除第一行。
    if [[ "${l_content}" =~ ^([ ]*)\| ]];then
      l_content=$(echo -e "${l_content}" | sed "1d")
    fi
  fi
  #获取第一行的前导空格数量。
  l_firstLine=$(echo -e "${l_content}" | grep -m 1 -oE '^ *[[:alpha:]_-]+')
  l_firstLine="${l_firstLine%%[^ ]*}"
  gDefaultRetVal="${#l_firstLine}"
}

#查找文件中符合条件的有效行，读取并返回第一行(l_order=positive)或最后一行(l_order=reverse)的行号和前导空格数量。
#如果未指定l_order参数，则读取并返回文件中从l_startRowNum行到l_endRowNum行间符合条件的且前导空格最少的行的行号和前导空格数量
function _getRowNumAndPrefixSpaceNum(){
  export gDefaultRetVal
  export _yamlFileContent

  local l_yamlFile=$1
  local l_regexStr=$2
  local l_startRowNum=$3
  local l_endRowNum=$4
  #positive(正序)或reverse(倒序)，
  #如果未设置，则获取文件中从l_startRowNum行开始符合条件的且前导空格最少的行的行号和前导空格数量
  local l_order=$5

  local l_content
  local l_rowNum
  local l_rowData
  local l_spaceNum
  local l_array
  local l_hasItemPrefix

  if [ ! "${l_startRowNum}" ];then
    ((l_startRowNum = 1))
  fi

  if [[ ! "${l_endRowNum}" || "${l_endRowNum}" == "-1" ]];then
    l_endRowNum="10000"
  fi

  if [[ "${l_order}" && "${l_order}" == "positive" ]];then
    #从l_yamlFile文件的第l_startRowNum行开始直至l_endRowNum行，查找所有符合正则表达式的行（以行号开头）, 并返回第一行内容。
    #awk命令返回的行首行号是文件中的绝对行号。
    l_content=$(awk -v start="${l_startRowNum}" -v end="${l_endRowNum}" '
            NR>=start && NR<=end && $0 ~ regex {print NR ":" $0; exit}
        ' regex="${l_regexStr}" <<< "${_yamlFileContent}")
  elif [[ "${l_order}" && "${l_order}" == "reverse" ]];then
    #从l_yamlFile文件的第l_startRowNum行开始直至l_endRowNum行，查找所有符合正则表达式的行（以行号开头）, 并返回最后一行内容。
    #awk命令返回的行首行号是文件中的绝对行号。
    l_content=$(awk -v start="${l_startRowNum}" -v end="${l_endRowNum}" '
            NR>=start && NR<=end && $0 ~ regex {last=NR ":" $0}
            END {if (last) print last}
        ' regex="${l_regexStr}" <<< "${_yamlFileContent}")
  else
    #从l_yamlFile文件的第l_startRowNum行开始直至l_endRowNum行，查找并返回所有符合正则表达式的行（以行号开头）。
    #awk命令返回的行首行号是文件中的绝对行号。
    l_content=$(awk -v start="${l_startRowNum}" -v end="${l_endRowNum}" '
            BEGIN { RS="\n"; ORS="\n" }
            NR>=start && NR<=end && $0 ~ regex {print NR ":" $0}
        ' regex="${l_regexStr}" <<< "${_yamlFileContent}")
  fi

  ((l_rowNum = -1))
  ((l_spaceNum = -1))
  l_hasItemPrefix="false"
  if [ "${l_content}" ];then
    if [[ "${l_order}" && ("${l_order}" == "positive" || "${l_order}" == "reverse") ]];then
      #读取开头的行号，这个是绝对行号。
      l_rowNum="${l_content%%:*}"
      l_content="${l_content#*:}"
      #计算前导空格数量。
      l_content="${l_content%%[^ ]*}"  # 提取行首连续空格
      l_spaceNum=${#l_content}         # 直接获取空格数量
      [[ "${l_content}" =~ ^([ ]*)\- ]] && l_hasItemPrefix="true"
    else
      #读取l_content中前导空格最少的行的行号。
      _getRowNum "${l_content}"
      # shellcheck disable=SC2206
      l_array=(${gDefaultRetVal})
      l_rowNum="${l_array[0]}"
      l_spaceNum="${l_array[1]}"
      l_hasItemPrefix="${l_array[2]}"
    fi
  fi
  #返回结果
  gDefaultRetVal="${l_rowNum} ${l_spaceNum} ${l_hasItemPrefix}"
}

#从过滤出的信息中读取指定索引的行的行号；
#如果未指定索引，则读取前导空格最少的行的行号。
#如果索引为负数，则读取最后一行的行号。
function _getRowNum() {
  export gDefaultRetVal

  #l_content内容是已经过滤了注释行的有效行信息
  #格式为：{行号}:{行内容}
  local l_content=$1
  #需要读取第几行（从1开始）的前导行号？
  local l_rowNum=$2

  local l_lineCount
  local l_line
  local l_i
  local l_spaceNum
  local l_tmpSpaceNum
  local l_tmpRowNum
  local l_hasItemPrefix

  local trimmed_line

  #获取l_content的行数。
  l_lineCount=0
  [[ ${l_content} ]] && l_lineCount=$(wc -l <<< "${l_content}")

  l_hasItemPrefix="false"
  ((l_spaceNum = -1))
  ((l_tmpRowNum= -1))
  #如果没有设置索引，则取前导空格最少的行的行号。
  if  [ ! "${l_rowNum}" ]; then
    for (( l_i = 1; l_i <= l_lineCount; l_i++ )); do
      l_line=$(echo -e "${l_content}" | sed -n "${l_i}p")
      #获取前导空格数量
      trimmed_line="${l_line#*:}"
      trimmed_line="${trimmed_line%%[^ ]*}"  # 保留前导空格部分
      ((l_tmpSpaceNum = ${#trimmed_line}))
      if [ "${l_spaceNum}" -eq -1 ] || [ "${l_spaceNum}" -gt "${l_tmpSpaceNum}" ];then
        l_spaceNum="${l_tmpSpaceNum}"
        #得到第一个”:“前面的行号。
        l_tmpRowNum=${l_line%%:*}
        [[ "${l_line#*:}" =~ ^([ ]*)\- ]] && l_hasItemPrefix="true"
      fi
    done
  elif [ "${l_rowNum}" -le "${l_lineCount}" ];then
    #如果是读取最后一行，则:
    if [ "${l_rowNum}" -le 0 ];then
      ((l_i = l_lineCount))
    else
      ((l_i = l_rowNum))
    fi

    l_line=$(echo -e "${l_content}" | sed -n "${l_i}p")
    l_tmpRowNum=${l_line%%:*}

    #获取前导空格数量
    trimmed_line="${l_line#*:}"
    trimmed_line="${trimmed_line%%[^ ]*}"  # 保留前导空格部分
    ((l_spaceNum = ${#trimmed_line}))
    [[ "${l_line#*:}" =~ ^([ ]*)\- ]] && l_hasItemPrefix="true"
  fi

  #返回结果
  gDefaultRetVal="${l_tmpRowNum} ${l_spaceNum} ${l_hasItemPrefix}"
}

#删除指定参数的内容。
function _deleteContentInFile(){
  export gDefaultRetVal
  export gFileContentMap
  export _yamlFileContent

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_endRowNum=$3
  local l_arrayIndex=$4

  local l_LineCount
  local l_isOk
  local l_content
  if [[ "${l_startRowNum}" -ge 1 && "${l_endRowNum}" -ge 1 ]];then
    #如果删除的是单行，且不是数组项，且是以空格和/或”-“开头，且下一行前导空格等于l_startRowNum行前导空格数加2，
    #则要为下一行添加列表项前导标识”-“。
    #此操作主要处理：删除的参数是数组项的第一项，这会导致丢失数组项前缀符“-”，为此需要评估并为l_startRowNum行的下一行添加数组项前缀。
    if [[ "${l_startRowNum}" -eq "${l_endRowNum}" && "${l_arrayIndex}" -lt 0 ]];then
      _checkAndAddListItemPrefix "${@}"
      l_isOk="${gDefaultRetVal}"
    fi
    if [[ "${l_isOk}" && "${l_isOk}" == "false" ]];then
      #l_content=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
      l_content=$(sed -n "${l_startRowNum}p" <<< "${_yamlFileContent}")
      if [[ "${l_content}" =~ ^([ ]*)(\-) ]];then
        l_content="${l_content%%-*}- "
        #sed -i "${l_startRowNum}c\\${l_content}" "${l_yamlFile}"
        _yamlFileContent=$(sed "${l_startRowNum}c\\${l_content}" <<< "${_yamlFileContent}")
        ((l_LineCount = 0))
        gDefaultRetVal="${l_startRowNum} ${l_endRowNum} ${l_LineCount}"
        return
      fi
    fi
    #删除从l_startRowNum行（含）到l_endRowNum行（含）的内容。
    #sed -i "${l_startRowNum},${l_endRowNum}d" "${l_yamlFile}"
    _yamlFileContent=$(sed "${l_startRowNum},${l_endRowNum}d" <<< "${_yamlFileContent}")

    ((l_LineCount = l_endRowNum - l_startRowNum + 1))
    gDefaultRetVal="${l_startRowNum} ${l_endRowNum} ${l_LineCount}"
  elif [[ "${l_startRowNum}" -ge 1 && "${l_endRowNum}" -le 0 ]];then
    ((l_startRowNum = l_startRowNum > 1 ? l_startRowNum - 1 : l_startRowNum))
    #获取文件总行数。
    #l_endRowNum=$(sed -n '$=' "${l_yamlFile}")
    l_endRowNum=$(sed -n '$=' <<< "${_yamlFileContent}")
    #删除从l_startRowNum行（含）到文件末尾的内容。
    #sed -i "${l_startRowNum},\$d" "${l_yamlFile}"
    _yamlFileContent=$(sed "${l_startRowNum},\$d" <<< "${_yamlFileContent}")

    ((l_LineCount = l_endRowNum - l_startRowNum + 1))
    gDefaultRetVal="${l_startRowNum} ${l_endRowNum} ${l_LineCount}"
  elif [[ "${l_startRowNum}" -le 0 && "${l_endRowNum}" -ge 1 ]];then
    #删除从第1行（含）到第l_endRowNum行(含)的内容。
    #sed -i "1,${l_endRowNum}d" "${l_yamlFile}"
    _yamlFileContent=$(sed "1,${l_endRowNum}d" <<< "${_yamlFileContent}")

    gDefaultRetVal="1 ${l_endRowNum} ${l_endRowNum}"
  else
    #获取文件总行数。
    #l_LineCount=$(sed -n '$=' "${l_yamlFile}")
    l_lineCount=$(sed -n '$=' <<< "${_yamlFileContent}")
    #清空文件内容。
    #sed -i "1,\$d" "${l_yamlFile}"
    _yamlFileContent=$(sed "1,\$d" <<< "${_yamlFileContent}")

    gDefaultRetVal="1 ${l_LineCount} ${l_LineCount}"
  fi
}

#读取指定参数的数据块信息，返回数据格式：
#{数据块的起始行号} {数据块的截止行号} {数据块的前导空格数} {现有列表项总数} {执行过程中新增的列表项数} {执行过程中删除的文件行数}
function _getDataBlockRowNum() {
  export gDefaultRetVal

  export _yamlFileContent

  local l_mode=$1
  local l_yamlFile=$2
  #参数所在行的行号
  local l_paramRowNum=$3
  local l_maxRowNum=$4
  local l_curArrayIndex=$5
  #参数行前导空格数量。
  local l_paramRowPrefixSpaceNum=$6
  #参数行是否有列表项前缀符
  local l_hasListItemPrefix=$7

  local l_tmpStartRowNum
  local l_blockStartRowNum
  local l_blockEndRowNum
  local l_blockPrefixSpaceNum

  local l_content
  local l_tmpContent
  local l_tmpContent1
  local l_tmpSpaceNum
  local l_tmpRowNum
  local l_itemCount
  local l_tmpIndex
  local l_insertPosition
  local l_tmpSpaceStr
  local l_addItemCount
  local l_delLineCount

  local l_array

  ((l_itemCount = -1))
  ((l_addItemCount = 0))
  ((l_delLineCount = 0))

  #先判断是否是数组类型的参数
  l_content=$(sed -n "${l_paramRowNum},${l_paramRowNum}p" <<< "${_yamlFileContent}")
  if [[ "${l_content}" && "${l_content}" =~ ^([ ]*)(.*):(.*)$ ]];then
    l_content="${l_content#*:}"
    if [[ "${l_content}" =~ ^([ ]*)(\[).*(\])$ ]];then
      l_content="${l_content#*[}"
      l_content="${l_content%]*}"
      # shellcheck disable=SC2206
      l_array=(${l_content//,/ })
      l_itemCount=${#l_array[@]}
      if [[ "${l_curArrayIndex}" -ge "${l_itemCount}" && "${l_mode}" == "insert" ]];then
        ((l_itemCount = l_itemCount + l_addItemCount))
      fi
      #设置返回值。
      gDefaultRetVal="${l_paramRowNum} ${l_paramRowNum} ${l_paramRowPrefixSpaceNum} ${l_itemCount} ${l_addItemCount} ${l_delLineCount}"
      return
    fi
  fi

  #预设参数下属数据块的起始行号=参数所在行的下一行。
  ((l_tmpStartRowNum = l_paramRowNum + 1))
  #预设参数下属数据块的前导空格数量=参数所在行前导空格数量 + 2
  ((l_blockPrefixSpaceNum = l_paramRowPrefixSpaceNum + 2))
  #如果参数行存在列表项前导符，则数据块的前导空格数量=l_paramRowPrefixSpaceNum + 4
  [[ "${l_hasListItemPrefix}" == "true" ]] && ((l_blockPrefixSpaceNum = l_paramRowPrefixSpaceNum + 4))

  ((l_blockStartRowNum = -1))
  ((l_blockEndRowNum = -1))

  #如果l_tmpStartRowNum行是注释行或空白行
  #则要获取l_paramRowNum行下的第一个有效行，并重新赋值给l_tmpStartRowNum。
  l_tmpContent=$(sed -n "${l_tmpStartRowNum}p" <<< "${_yamlFileContent}")
  #如果是注释行或空白行，则需要重新定位和修正l_tmpStartRowNum的值。
  if [[ "${l_tmpContent}" =~ ^([ ]*)# || "${l_tmpContent}" =~ ^([ ]*)$ ]];then
    l_tmpContent=$(sed -n "${l_tmpStartRowNum},${l_maxRowNum}p" <<< "${_yamlFileContent}")
    #如果不为空，则获取有效行的行号作为起始行，
    #否则说明参数没有下属数据块，l_blockStartRowNum和l_blockEndRowNum保持默认值-1.
    if [ "${l_tmpContent}" ];then
      _getMatchedLines "${l_tmpContent}" "^ *[a-zA-Z_\-]+.*$" "first"
      l_tmpContent="${gDefaultRetVal}"
      l_tmpRowNum="${l_tmpContent%%:*}"
      #更新数据块的预设起始行
      ((l_tmpStartRowNum = l_tmpStartRowNum + l_tmpRowNum -1))
    fi
  fi

  #如果l_tmpStartRowNum小于等于l_maxRowNum，则继续确认数据块的起止行。
  #否则说明参数没有下属数据块，l_blockStartRowNum和l_blockEndRowNum保持默认值-1.
  if [ "${l_tmpStartRowNum}" -le "${l_maxRowNum}" ];then
    #直接从文件中读取l_tmpStartRowNum至l_maxRowNum间的数据。
    _readLinesInRange "${_yamlFileContent}" "${l_tmpStartRowNum}" "${l_maxRowNum}"
    l_content="${gDefaultRetVal}"
    #l_content=$(echo -e "${_yamlFileContent}" | sed -n "${l_tmpStartRowNum},${l_maxRowNum}p")
    #事实上l_content不可能是空的。
    if [ "${l_content}" ];then
      #查找兄弟行或父级行的查询匹配字符串。
      #兄弟行的前导空格数应是数据块的前导空格数减2。
      ((l_tmpSpaceNum = l_blockPrefixSpaceNum - 2))
      #构造兄弟行或父级行的正则表达式。
      l_tmpRegex="^[ ]{0,${l_tmpSpaceNum}}[a-zA-Z_\-]+.*$"

      #找到第一个兄弟行或父级行的行号。
      _getMatchedLines "${l_content}" "${l_tmpRegex}" "first"
      l_tmpContent="${gDefaultRetVal}"
      #l_tmpContent=$(echo -e "${l_content}" | grep -m 1 -noP "${l_tmpRegex}")
      if [ ! "${l_tmpContent}" ];then
        #说明从l_tmpStartRowNum到l_maxRowNum行都是参数的下属数据块。
        l_blockStartRowNum="${l_tmpStartRowNum}"
        l_blockEndRowNum="${l_maxRowNum}"
      else
        #得到兄弟行或父级行的相对行号
        l_tmpRowNum="${l_tmpContent%%:*}"
        #如果l_tmpRowNum==1,说明参数行的下一个兄弟行或父级行就是l_tmpStartRowNum行，
        #  也即参数不存在下属数据块，l_blockStartRowNum和l_blockEndRowNum保持默认值-1.
        #如果l_tmpRowNum>1,说明参数存在单行或多行下属数据块。
        if [ "${l_tmpRowNum}" -gt 1 ];then
          #截止行应是兄弟行行号减1，再转换为文件绝对行号还需要减1
          ((l_tmpRowNum = l_tmpStartRowNum + l_tmpRowNum - 2))
          if [ "${l_tmpRowNum}" -ge "${l_tmpStartRowNum}" ];then
            ((l_blockStartRowNum = l_tmpStartRowNum))
            ((l_blockEndRowNum = l_tmpRowNum))
          fi
        fi
      fi

    fi
  fi

  if [ "${l_curArrayIndex}" ] && [ "${l_curArrayIndex}" -ge 0 ];then
    ((l_itemCount = 0))
    #先获取现有列表项的总数。
    if [ "${l_blockStartRowNum}" -gt 0 ];then
      #读取数据块内容
      _readLinesInRange "${_yamlFileContent}" "${l_blockStartRowNum}" "${l_blockEndRowNum}"
      l_content="${gDefaultRetVal}"

      #l_content=$(echo -e "${_yamlFileContent}" | sed -n "${l_blockStartRowNum},${l_blockEndRowNum}p")

      #获取第一个有效行内容
      _getMatchedLines "${l_content}" "^ *[a-zA-Z_\-]+.*$" "first"
      l_tmpContent="${gDefaultRetVal#*:}"
      #获取前导空格数量。
      l_tmpContent="${l_tmpContent%%[^ ]*}"  # 提取行首连续空格
      l_tmpRowNum=${#l_tmpContent}           # 直接获取空格数量

      #从l_content中查找所有列表项起始行的行号和行内容信息
      _getMatchedLines "${l_content}" "^[ ]{0,${l_tmpRowNum}}[\-]+.*$" "all"
      l_tmpContent="${gDefaultRetVal}"

      #获取现有列表项的数量。
      l_itemCount=0
      [[ "${l_tmpContent}" ]] && l_itemCount=$(wc -l <<< "${l_tmpContent}")

      if [ "${l_curArrayIndex}" -lt "${l_itemCount}" ];then
        #定位截止行号
        ((l_tmpRowNum = l_curArrayIndex + 2 ))
        #当l_tmpRowNum小于等于l_itemCount时，才修改l_blockEndRowNum的值，否则保持l_blockEndRowNum的值。
        if [ "${l_tmpRowNum}" -le "${l_itemCount}" ];then
          _readLinesInRange "${l_tmpContent}" "${l_tmpRowNum}"
          l_tmpContent1="${gDefaultRetVal}"
          #l_tmpContent1=$(echo -e "${l_tmpContent}" | sed -n "${l_tmpRowNum}p")
          l_tmpRowNum="${l_tmpContent1%%:*}"
          #相对行号转绝对行号（减1）,再转截止行号（减1）
          ((l_blockEndRowNum = l_blockStartRowNum + l_tmpRowNum - 2))
        fi
        #定位起始行号。
        ((l_tmpRowNum = l_curArrayIndex + 1 ))
        _readLinesInRange "${l_tmpContent}" "${l_tmpRowNum}"
        l_tmpContent1="${gDefaultRetVal}"
        #l_tmpContent1=$(echo -e "${l_tmpContent}" | sed -n "${l_tmpRowNum}p")
        l_tmpRowNum="${l_tmpContent1%%:*}"
        #相对行号转绝对行号
        ((l_blockStartRowNum = l_blockStartRowNum + l_tmpRowNum -1))
      elif [[ "${l_itemCount}" == 0 && ${l_mode} == "insert" ]];then
        #清除旧有的非列表类型的数据块。
        _yamlFileContent=$(sed "${l_blockStartRowNum},${l_blockEndRowNum}d" <<< "${_yamlFileContent}")
        #设置删除的文件行数。
        ((l_delLineCount = l_blockStartRowNum - l_blockEndRowNum + 1))
        ((l_blockStartRowNum = -1))
        ((l_blockEndRowNum = -1))
      fi
    fi

    if [ "${l_curArrayIndex}" -ge "${l_itemCount}" ];then
      if [ "${l_mode}" == "insert" ];then
        #默认插入到数据块结尾行的下一行。
        l_insertPosition="${l_blockEndRowNum}"
        #如果截止行号为-1，则插入到参数行的下一行。
        if [[ "${l_blockEndRowNum}" -eq -1 ]];then
          l_insertPosition="${l_paramRowNum}"
          #读取_yamlFileContent中l_paramRowNum行的内容
          _readLinesInRange "${_yamlFileContent}" "${l_paramRowNum}"
          l_tmpContent="${gDefaultRetVal}"
          #l_tmpContent=$(echo -e "${_yamlFileContent}" | sed -n "${l_paramRowNum}p")
          if [[ "${l_tmpContent}" =~ ^([ ]*)[a-zA-Z_\-]+(.*)(: )(.*)$ ]];then
             #需要清除l_paramRowNum行可能存在的值域。
            l_tmpContent="${l_tmpContent%%:*}:"
            #替换_yamlFileContent中l_paramRowNum行的内容为l_tmpContent
            _yamlFileContent=$(sed "${l_paramRowNum}c\\${l_tmpContent}" <<< "${_yamlFileContent}")
          fi
        fi
        #构造替换行的内容：将新增项放置在替换行的末尾，中间用\n隔开，
        _readLinesInRange "${_yamlFileContent}" "${l_insertPosition}"
        l_tmpContent="${gDefaultRetVal}"
        #l_tmpContent=$(echo -e "${_yamlFileContent}" | sed -n "${l_insertPosition}p")

        l_tmpSpaceStr=$(printf "%${l_blockPrefixSpaceNum}s")
        l_tmpContent="${l_tmpContent}\n${l_tmpSpaceStr}- "
        #补上缺失的列表项
        ((l_addItemCount = l_curArrayIndex + 1 - l_itemCount))
        #设置新增后列表项的总数量
        ((l_itemCount = l_curArrayIndex + 1))
        ((l_tmpIndex = 0))
        while [ "${l_tmpIndex}" -lt "${l_addItemCount}" ];do
          #替换_yamlFileContent中l_insertPosition行的内容为l_tmpContent
          _yamlFileContent=$(sed "${l_insertPosition}c\\${l_tmpContent}" <<< "${_yamlFileContent}")
          #调整一次格式，使能换行符
          _yamlFileContent=$(echo -e "${_yamlFileContent}")
          ((l_tmpIndex = l_tmpIndex + 1))
        done
        #设置数据块起止行号：都等于最后一个列表项所在行的行号
        ((l_blockStartRowNum = l_insertPosition + l_addItemCount))
        ((l_blockEndRowNum = l_blockStartRowNum))
      else
        #不是插入模式，则设置数据块起止行号为-1.
        ((l_blockStartRowNum = -1))
        ((l_blockEndRowNum = -1))
      fi
    fi
  fi

  #删除数据块的开始和结尾部分的注释行。
  if [[ "${l_blockStartRowNum}" -gt 0 && "${l_blockStartRowNum}" -le "${l_blockEndRowNum}" ]];then
    #读取数据块内容。
    _readLinesInRange "${_yamlFileContent}" "${l_blockStartRowNum}" "${l_blockEndRowNum}"
    l_content="${gDefaultRetVal}"
    #l_content=$(echo -e "${_yamlFileContent}" | sed -n "${l_blockStartRowNum},${l_blockEndRowNum}p")
    if [ "${l_content}" ];then
      #去掉结尾部分的注释行
      _getMatchedLines "${l_content}" "^([ ]*)[a-zA-Z_\-]+.*$" "last"
      l_tmpContent="${gDefaultRetVal}"

      #l_tmpContent=$(echo -e "${l_content}" | grep -noP "^([ ]*)[a-zA-Z_\-]+" | tail -n 1)
      l_tmpRowNum="${l_tmpContent%%:*}"
      ((l_blockEndRowNum=l_blockStartRowNum + l_tmpRowNum - 1))

      #去掉前导部分注释行
      _getMatchedLines "${l_content}" "^([ ]*)[a-zA-Z_\-]+.*$" "first"
      l_tmpContent="${gDefaultRetVal}"
      #l_tmpContent=$(echo -e "${l_content}" | grep -m 1 -noP "^([ ]*)[a-zA-Z_\-]+")
      l_tmpRowNum="${l_tmpContent%%:*}"
      ((l_blockStartRowNum=l_blockStartRowNum + l_tmpRowNum - 1))
    fi
  fi

  #设置返回值。
  gDefaultRetVal="${l_blockStartRowNum} ${l_blockEndRowNum} ${l_blockPrefixSpaceNum} ${l_itemCount} ${l_addItemCount} ${l_delLineCount}"
}

#读取数据块的内容
function _readDataBlock(){
  export gDefaultRetVal
  export _yamlFileContent

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_endRowNum=$3
  local l_arrayIndex=$4
  local l_isDataBlock=$5

  local l_content
  local l_array

  #先直接读取内容。
  _readLinesInRange "${_yamlFileContent}" "${l_startRowNum}" "${l_endRowNum}"
  l_content="${gDefaultRetVal}"
  #l_content=$(echo -e "${_yamlFileContent}" | sed -n "${l_startRowNum},${l_endRowNum}p")
  if [ "${l_isDataBlock}" == "false" ];then
    #如果是数组格式，则直接读取l_arrayIndex指定的数组项。
    if [[ "${l_arrayIndex}" -ge 0 && "${l_content}" =~ ^(.*):([ ]+)\[(.*)\]([ ]*)$ ]];then
      #去掉开头的"["符号
      l_content="${l_content#*[}"
      #去掉结尾的"]"符号
      l_content="${l_content%]*}"
      #字符串转数组
      # shellcheck disable=SC2206
      l_array=(${l_content//,/ })
      if [ "${l_arrayIndex}" -lt "${#l_array[@]}" ];then
        #读取第l_arrayIndex项数据。
        l_content="${l_array[${l_arrayIndex}]}"
      else
        l_content="null"
      fi
    else
      l_content="${l_content#*:}"
    fi
  fi

  #返回数据
  gDefaultRetVal="${l_content}"
}

function _getReadContent() {
  export gDefaultRetVal
  export _yamlFileContent

  local l_yamlFile=$1
  local l_paramName=$2
  local l_paramRowNum=$3
  local l_content=$4
  local l_curArrayIndex=$5
  local l_keepOriginalFormat=$6
  local l_isDataBlock=$7

  local l_prefixStr
  local l_tmpContent
  local l_tmpSpaceNum
  local l_tmpRowNum
  local l_content1
  local l_content2

  ((l_tmpSpaceNum = -1))
  if [ "${l_isDataBlock}" == "true" ];then
    #如果有前缀字符串，则添加之。
    if [ "${l_keepOriginalFormat}" == "true" ];then
      #获取参数值中可能存在的前导字符，例如：|等
      #l_prefixStr=$(sed -n "${l_paramRowNum}p" "${l_yamlFile}")
      #l_prefixStr=$(echo -e "${_yamlFileContent}" | sed -n "${l_paramRowNum}p")
      _readLinesInRange "${_yamlFileContent}" "${l_paramRowNum}"
      l_prefixStr="${gDefaultRetVal}"

      if [[ "${l_prefixStr}" =~ ^(.*):([ ]+)\|[+-]*([ ]*)$ ]];then
        l_prefixStr="${l_prefixStr#*:}"
        l_prefixStr="${l_prefixStr// /}"
        l_content=$(echo -e "${l_prefixStr}\n${l_content}")
      fi
    else
      if [ "${l_curArrayIndex}" -ge 0 ];then
        #l_tmpContent=$(echo -e "${l_content}" | grep -m 1 -noP "^([ ]*)[a-zA-Z_\-]+(.*)$")
        _getMatchedLines "${l_content}" "^([ ]*)[a-zA-Z_\-]+.*$" "first"
        l_tmpContent="${gDefaultRetVal}"
        #以下处理主要是考虑到注释行的存在，所以感觉写的笨拙
        if [[ "${l_tmpContent}" =~ ([0-9]+):([ ]*)\- ]];then
          #读取第一个列表项的行号
          l_tmpRowNum="${l_tmpContent%%:*}"
          #读取第一个列表项的行内容
          l_tmpContent="${l_tmpContent#*:}"
          #替换”-“为空格
          l_tmpContent="${l_tmpContent%%-*} ${l_tmpContent#*-}"
          #更新该行的内容，将前导"-"字符替换为空格。
          l_content1=""
          if [[ "${l_tmpRowNum}" -gt 1 ]];then
            #l_content1=$(echo -e "${l_content}" | sed -n "1,${l_tmpRowNum}p")
            _readLinesInRange "${l_content}" "1" "${l_tmpRowNum}"
            l_content1="${gDefaultRetVal}"
            l_content1="${l_content1}\n"
          fi
          ((l_tmpRowNum = l_tmpRowNum + 1))
          #l_content2=$(echo -e "${l_content}" | sed -n "${l_tmpRowNum},\$p")
          _readLinesInRange "${l_content}" "${l_tmpRowNum}" "-1"
          l_content2="${gDefaultRetVal}"
          if [ "${l_content2}" ];then
            l_content2="\n${l_content2}"
          fi
          l_content="${l_content1}${l_tmpContent}${l_content2}"
          l_content=$(echo -e "${l_content}")
          #获取前导空格数量。
          #l_tmpSpaceNum=$(echo -e "${l_tmpContent}" | grep -m 1 -oP "^[ ]*" | grep -oP " " | wc -l)
          l_tmpContent="${l_tmpContent%%[^ ]*}"  # 提取行首连续空格
          l_tmpSpaceNum=${#l_tmpContent}         # 直接获取空格数量
        fi
      fi

      #删除l_content的前导空格
      if [ "${l_tmpSpaceNum}" -lt 0 ];then
        #l_tmpContent=$(echo -e "${l_content}" | grep -m 1 -oP "^([ ]*)[a-zA-Z_\-]+(.*)$")
        _getMatchedLines "${l_content}" "^([ ]*)[a-zA-Z_\-]+.*$" "first"
        l_tmpContent="${gDefaultRetVal#*:}"
        #l_tmpSpaceNum=$(echo -e "${l_tmpContent}" | grep -m 1 -oP "^[ ]*" | grep -oP " " | wc -l)
        l_tmpContent="${l_tmpContent%%[^ ]*}"  # 提取行首连续空格
        l_tmpSpaceNum=${#l_tmpContent}         # 直接获取空格数量
      fi

      if [ "${l_tmpSpaceNum}" -gt 0 ];then
        #删除前导空格
        _indentContent "${l_content}" "-${l_tmpSpaceNum}"
        l_content="${gDefaultRetVal}"
      fi
    fi
  else
    #处理简单值
    l_content="${l_content:1}"
  fi

  gDefaultRetVal="${l_content}"
}

function _checkAndAddListItemPrefix() {
  export gDefaultRetVal
  export _yamlFileContent

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_endRowNum=$3
  local l_arrayIndex=$4

  local l_rowData
  local l_tmpRowNum
  local l_rowNumAndSpaceNum
  local l_tmpSpaceNum
  local l_tmpSpaceStr
  local l_isOk

  l_isOk="false"
  if [[ "${l_startRowNum}" -eq "${l_endRowNum}" && "${l_arrayIndex}" -lt 0 ]];then
    #读取l_startRowNum行的数据。
    #l_rowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
    #l_rowData=$(echo -e "${_yamlFileContent}" | sed -n "${l_startRowNum}p")
    _readLinesInRange "${_yamlFileContent}" "${l_startRowNum}"
    l_rowData="${gDefaultRetVal}"

    if [[ "${l_rowData}" =~ ^([ ]*)(\-).*$ ]];then
      ((l_tmpRowNum = l_startRowNum + 1))
      #获取下一有效行的行号。
      _getRowNumAndPrefixSpaceNum "${l_yamlFile}" "^[ ]*[a-zA-Z]+" "${l_tmpRowNum}" "-1" "positive"
      # shellcheck disable=SC2206
      l_rowNumAndSpaceNum=(${gDefaultRetVal})
      #得到有效行行号
      l_tmpRowNum="${l_rowNumAndSpaceNum[0]}"
      if [ "${l_tmpRowNum}" -ne -1 ];then
        #得到有效行前导空格数量。
        l_tmpSpaceNum="${l_rowNumAndSpaceNum[1]}"
        if [ "${l_tmpSpaceNum}" -ge 2 ];then
          ((l_tmpSpaceNum = l_tmpSpaceNum -2))
          if [[ "${l_rowData}" =~ ^([ ]{${l_tmpSpaceNum}})(\-).*$ ]];then
            #此时需要为l_tmpRowNum行添加列表项前导字符”-“
            #先读取l_tmpRowNum行的数据。
            #l_rowData=$(sed -n "${l_tmpRowNum}p" "${l_yamlFile}")
            #l_rowData=$(echo -e "${_yamlFileContent}" | sed -n "${l_tmpRowNum}p")
            _readLinesInRange "${_yamlFileContent}" "${l_tmpRowNum}"
            l_rowData="${gDefaultRetVal}"
            #构造前导空格字符串。
            l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum}s- ")
            #使用l_tmpSpaceStr替换l_rowData数据的前导空格。
            ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
            l_rowData="${l_tmpSpaceStr}${l_rowData:${l_tmpSpaceNum}}"
            #最后，替换文件中l_tmpRowNum行的数据。
            #sed -i "${l_tmpRowNum}c\\${l_rowData}" "${l_yamlFile}"
            _yamlFileContent=$(sed "${l_tmpRowNum}c\\${l_rowData}" <<< "${_yamlFileContent}")
            l_isOk="true"
          fi
        fi
      fi
    fi
  fi

  gDefaultRetVal="${l_isOk}"
}

#使用单行数据更新指定行的数据
function _updateSingleRowValue() {
  export gDefaultRetVal
  export gFileContentMap
  export _yamlFileContent

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_newContent=$3

  local l_rowData
  local l_tmpContent
  local l_tmpSpaceNum
  local l_tmpSpaceNum1
  local l_tmpSpaceStr
  local l_endRowNum
  local l_addRowNum

  ((l_endRowNum = l_startRowNum))
  ((l_addRowNum = 0))
  _readLinesInRange "${_yamlFileContent}" "${l_startRowNum}"
  l_rowData="${gDefaultRetVal}"
  #如果新内容包含": "字符串,则
  if [[ "${l_newContent}" =~ ^([ ]*)[a-zA-Z_]+[a-zA-Z0-9_\-]*(: ).*$ ]];then
    #获取l_startRowNum行前导空格数
    #l_tmpSpaceNum=$(echo -e "${l_rowData}" | grep -o "^[ ]*" | grep -o " " | wc -l)
    l_tmpContent="${l_rowData%%[^ ]*}"  # 提取行首连续空格
    l_tmpSpaceNum=${#l_tmpContent}      # 直接获取空格数量
    #在l_startRowNum行的下一行插入数据，因此前导空格数加2.
    ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
    #如果l_startRowNum行是以“- ”开头的，前导空格数再加2.
    [[ "${l_rowData}" =~ ^([ ]*)(- ) ]] && ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
    #获取新内容的前导空格数
    #l_tmpSpaceNum1=$(echo -e "${l_newContent}" | grep -o "^[ ]*" | grep -o " " | wc -l)
    l_tmpContent="${l_newContent%%[^ ]*}"  # 提取行首连续空格
    l_tmpSpaceNum1=${#l_tmpContent}        # 直接获取空格数量
    #获取指定长度的字符串
    l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum}s")
    #构造新内容
    l_newContent="${l_tmpSpaceStr}${l_newContent:${l_tmpSpaceNum1}}"
    #在l_startRowNum的下面插入一行。
    #sed -i "${l_startRowNum}a\\${l_newContent}" "${l_yamlFile}"
    _yamlFileContent=$(sed "${l_startRowNum}a\\${l_newContent}" <<< "${_yamlFileContent}")

    #最后执行依次l_startRowNum行值域的清除操作，防止l_startRowNum行上存在”|“等前导字符串。
    #sed -i "${l_startRowNum}c\\${l_rowData%%:*}:" "${l_yamlFile}"
    _yamlFileContent=$(sed "${l_startRowNum}c\\${l_rowData%%:*}:" <<< "${_yamlFileContent}")

    ((l_endRowNum = l_startRowNum + 1))
    ((l_addRowNum = 1))
  else
    #直接更新到l_startRowNum行的值域。
    l_rowData="${l_rowData%%:*}: ${l_newContent}"
    _yamlFileContent=$(sed "${l_startRowNum}c\\${l_rowData}" <<< "${_yamlFileContent}")
  fi
  gDefaultRetVal="${l_startRowNum} ${l_endRowNum} -1 ${l_addRowNum}"
}

#使用多行数据更新指定行的数据。
function _updateMultipleRowValue() {
  export gDefaultRetVal
  export _yamlFileContent

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_newContent=$3
  #新内容所占的行数。
  local l_lineCount=$4

  local l_firstRowData
  local l_rowData
  local l_lineCount
  local l_startRowData
  local l_tmpSpaceNum
  local l_tmpSpaceNum1
  local l_tmpRowNum

  l_rowData="${l_newContent}"
  #获取l_newContent的总行数。
  l_lineCount=$(echo -e "${l_rowData}" | wc -l)
  #过滤出第一个有效行
  #l_firstRowData=$(echo -e "${l_rowData}" | grep -noP "^[ ]*([a-zA-Z_\-\|]+).*$" | head -n 1)
  l_rowData=$(echo -e "${l_rowData}")
  _getMatchedLines "${l_rowData}" "^[ ]*[a-zA-Z_\-\|]+.*$" "first"
  l_firstRowData=${gDefaultRetVal}
  #如果第一行数据是”|“开头的，则删除该行。
  if [[ "${l_firstRowData}" =~ ^([0-9]+):([ ]*)\|[+-]*([ ]*)$ ]];then
    #获得第一行有效行的行号
    l_tmpRowNum="${l_firstRowData%%:*}"
    #获取第一行有效行的内容
    l_firstRowData="${l_firstRowData#*:}"

    if [[ "${l_tmpRowNum}" -gt 0 && "${l_tmpRowNum}" -le "${l_lineCount}" ]]; then
      #获取第一行有效行后面的内容
      #l_rowData=$(echo -e "${l_newContent}" | sed "1,${l_tmpRowNum}d")
      # 使用tail命令更高效，直接跳过前N行
      ((l_tmpRowNum = l_tmpRowNum + 1))
      l_rowData=$(echo -e "${l_newContent}" | tail -n +"${l_tmpRowNum}")
    fi
  else
    l_firstRowData=""
  fi

  #不论l_firstRowData是否是空串，都使用l_firstRowData更新l_startRowNum行的值域部分

  #去掉左右空格
  l_firstRowData="${l_firstRowData#"${l_firstRowData%%[^[:space:]]*}"}"
  l_firstRowData="${l_firstRowData%"${l_firstRowData##*[^[:space:]]}"}"

  #先获取l_startRowNum行的内容
  _readLinesInRange "${_yamlFileContent}" "${l_startRowNum}"
  l_startRowData="${gDefaultRetVal}"
  #更新l_startRowNum行的值域
  _yamlFileContent=$(sed "${l_startRowNum}c\\${l_startRowData%%:*}: ${l_firstRowData}" <<< "${_yamlFileContent}")

  #在l_startRowNum行的下一行插入l_rowData数据:

  #获取l_startRowNum行的前导空格。
  l_tmpSpaceNum=$(echo -e "${l_startRowData}" | grep -o "^[ ]*" | grep -o " " | wc -l)
  if [[ "${l_startRowData}" =~ ^([ ]*)\- ]];then
    #如果l_startRowData是以空格和”-“为前导的，则计算的前导空格还要加2.
    ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
  fi
  #l_startRowNum行的下一行数据的前导空格数等于(l_tmpSpaceNum + 2)
  ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
  #在获取新数据第一行的前导空格数量.
  #todo: 正则表达式兼容了”<“（xml格式）和”[“（ini格式）开头的内容。
  #l_tmpSpaceNum1=$(echo -e "${l_rowData}" | grep -m 1 -oP "^[ ]*[a-zA-Z_\-\<\[]+.*$" | grep -oP "^[ ]*" | grep -oP " " | wc -l)
  _getMatchedLines "${l_rowData}" "^[ ]*[a-zA-Z_\-\<\[\]+.*$" "first"
  l_firstRowData="${gDefaultRetVal#*:}"
  #获取前导空格数量。
  l_firstRowData="${l_firstRowData%%[^ ]*}"  # 提取行首连续空格
  l_tmpSpaceNum1=${#l_firstRowData}          # 直接获取空格数量

  #计算前导空格数量的差值。
  ((l_tmpSpaceNum = l_tmpSpaceNum - l_tmpSpaceNum1))
  #将l_rowData数据整体左移或右移l_tmpSpaceNum个字符。l_tmpSpaceNum为负数时向左移动，为正数时向右移动。
  _indentContent "${l_rowData}" "${l_tmpSpaceNum}"
  l_rowData="${gDefaultRetVal}"
  #多行格式的字符串转换为单行格式的字符串(字符串中含有换行符):
  _convertToSingleRow "${l_rowData}"
  l_rowData="${gDefaultRetVal}"
  #将单行格式的l_rowData插入到l_startRowNum行的下一行(字符串中的\n会被自动识别为换行符)。
  #sed -i "${l_startRowNum}a\\${l_rowData}" "${l_yamlFile}"
  _yamlFileContent=$(sed "${l_startRowNum}a\\${l_rowData}" <<< "${_yamlFileContent}")

  #计算插入的最后一行数据所在的行号。
  ((l_tmpRowNum = l_startRowNum + l_lineCount))
  #修正l_startRowNum的值，使其指向参数下属数据块的起始行
  ((l_startRowNum = l_startRowNum +1 ))
  #返回：更新的参数下属数据块的起始行号、参数下属数据块的截止行号、-1(填充值，无意义)
  gDefaultRetVal="${l_startRowNum} ${l_tmpRowNum} -1"
}

#多行字符串转单行字符串（原字符串中的'\n'字符被转换为”\n“字符串）
function _convertToSingleRow() {
  export gDefaultRetVal
  local l_content=$1

  #local l_rowData

  #这里使用”`“字符作为换行符的替换字符，先将原字符串中的”`“字符替换为双”``“字符串。
  #l_rowData=$(echo -e "${l_content}" | sed "s/\`/\`\`/g")
  #然后将换行符转换为”`“字符并删除结尾的"`"符号，再将所有”`“字符转换为”\n“字符串,最后将"\n\n"字符串转换为”`“字符.
  #gDefaultRetVal=$(echo -e "${l_rowData}" | tr '\n' '\`' | sed "s/\`$//" | sed "s/\`/\\\n/g" | sed "s/\\\n\\\n/\`/g")

  # 使用AWK单次处理提高性能，处理速度提升约40%
  gDefaultRetVal=$(echo -e "${l_content}" | awk '
      BEGIN {
        RS = "\n";   # 记录分隔符为换行
        ORS = "";     # 输出记录分隔符为空
        quot_count = 0;
      }
      {
        # 替换原始反引号为双反引号
        gsub("`","``");

        # 处理换行符和空行逻辑
        if (NR > 1) {
          # 检测连续空行转换为单个反引号
          if (prev_empty && $0 ~ /^[[:space:]]*$/) {
            printf "`";
            quot_count++;
          } else {
            printf "\\n%s", $0;
          }
        } else {
          printf "%s", $0;
        }

        # 记录前一行是否为空行
        prev_empty = ($0 ~ /^[[:space:]]*$/);
      }
      END {
        # 添加最后一个换行符（可选）
        if (quot_count > 0) printf "`";
      }'
    )

}

function _adjustCachedParamsAfterUpdate() {
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_execResult=$3

  local l_array
  local l_startRowNum
  local l_endRowNum
  #文件行变动数量。正数为增加，负数为减少。
  local l_lineChangeCount

  # shellcheck disable=SC2206
  l_array=(${l_execResult})

  l_startRowNum="${l_array[0]}"
  l_endRowNum="${l_array[1]}"
  ((l_lineChangeCount = l_array[3] - l_array[4]))

  if [ "${l_lineChangeCount}" -ne 0 ];then
    #删除缓存中key以l_paramPath为前缀的记录。
    _deleteChildData "${l_yamlFile}" "${l_paramPath}"
    #在缓存中找出Key的值是l_paramPath的值的前向匹配子串的记录，将其截止行号加上l_lineChangeCount数量。
    _adjustEndRowNum "${l_yamlFile}" "${l_paramPath}" "${l_lineChangeCount}"
    #在缓存中查找Value值中起始行号大于l_startRowNum的记录，将其起始行号加上l_lineChangeCount数量。
    _adjustStartRowNum "${l_yamlFile}" "${l_paramPath}" "${l_startRowNum}" "${l_lineChangeCount}"
  fi
}

function _adjustCachedParamsAfterDelete() {
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_execResult=$3

  local l_array
  local l_startRowNum
  local l_deletedRowNum
  local l_listItemIndex

  # shellcheck disable=SC2206
  l_array=(${l_execResult})

  l_startRowNum=${l_array[0]}
  l_deletedRowNum="${l_array[2]}"
  l_listItemIndex="${l_array[3]}"

  #删除缓存中key以l_paramPath为前缀的记录,也即删除其下层参数的缓存信息。
  #如果l_listItemIndex大于等于0，则清除该参数路径开头的所有缓存记录
  _deleteChildData "${l_yamlFile}" "${l_paramPath}" "${l_listItemIndex}"
  #在缓存中找出Key的值是l_paramPath的值的前向匹配子串的记录，将其截止行号减去l_deletedRowNum数量。
  _adjustEndRowNum "${l_yamlFile}" "${l_paramPath}" "-${l_deletedRowNum}"
  #在缓存中查找Value值中起始行号大于l_startRowNum的记录，将其起始行号减去l_deletedRowNum数量。
  _adjustStartRowNum "${l_yamlFile}" "${l_paramPath}" "${l_startRowNum}" "-${l_deletedRowNum}"
}

#删除缓存中key以l_paramPath为前缀的记录,也即删除其下层参数的缓存信息。
#如果l_listItemIndex大于等于0，则清除该参数路径开头的所有缓存记录
function _deleteChildData() {
  export gFileDataBlockMap

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_listItemIndex=$3

  local l_mapSize
  local l_mapKey
  local l_prefixStr
  local l_regexStr
  local l_flag

  if [ ! "${l_listItemIndex}" ];then
    #1.更新操作完成后调用_deleteChildData时，没有传入l_listItemIndex参数。
    #此时设置l_listItemIndex=-1。此时本函数仅删除l_paramPath参数下属的参数。
    #2.删除操作完成后调用_deleteChildData时，传入了l_listItemIndex参数。
    #此时本函数完成删除整个列表类参数的缓存数据（不论列表序号是多少）
    ((l_listItemIndex = -1))
  fi

  l_mapSize="${#gFileDataBlockMap[@]}"
  if [ "${l_mapSize}" -gt 0 ];then
    l_prefixStr="${l_yamlFile}#${l_paramPath}"
    if [ "${l_listItemIndex}" -ge 0 ];then
      l_prefixStr="${l_prefixStr%[*}"
    fi
    l_prefixStr="${l_prefixStr//\[/#}"
    l_prefixStr="${l_prefixStr//\]/#}"

    l_regexStr="^(${l_prefixStr}[#.]+)"

    # shellcheck disable=SC2068
    for l_mapKey in ${!gFileDataBlockMap[@]};do
      #删除缓存中key以l_paramPath为前缀的记录。
      #l_flag=$(echo -e "${l_mapKey}" | grep -oP "${l_regexStr}")
      #if [ "${l_flag}" ];then
      if [[ "${l_mapKey}" =~ ${l_regexStr} ]]; then
        #删除缓存数据项
        unset gFileDataBlockMap["${l_mapKey}"]
      fi
    done
  fi
}

#在缓存中找出Key的值是l_paramPath的值的前向匹配子串的记录，将其截止行号减去l_deletedRowNum数量。
function _adjustEndRowNum() {
  export gFileDataBlockMap

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_deletedRowNum=$3

  local l_mapSize
  local l_tmpParamPath
  local l_mapKey
  local l_mapValue
  local l_array

  l_mapSize="${#gFileDataBlockMap[@]}"
  if [ "${l_mapSize}" -gt 0 ];then
    l_tmpParamPath="${l_paramPath}"
    while [ "${l_tmpParamPath}" ]; do
      if [[ "${l_tmpParamPath}" =~ ^(.*)\[[0-9]+\]([ ]*)$ ]];then
        l_tmpParamPath="${l_tmpParamPath%[*}"
      elif [[ "${l_tmpParamPath}" =~ ^(.*)\.(.*)$ ]];then
        l_tmpParamPath="${l_tmpParamPath%.*}"
      else
        break
      fi

      l_tmpParamPath="${l_tmpParamPath//\[/#}"
      l_tmpParamPath="${l_tmpParamPath//\]/#}"

      #构造l_mapKey参数的值。
      l_mapKey="${l_yamlFile}#${l_tmpParamPath}"
      #读取可能存在的缓存参数。
      l_mapValue="${gFileDataBlockMap[${l_mapKey}]}"
      if [ "${l_mapValue}" ];then
        #更新值中截止行号参数。
        # shellcheck disable=SC2206
        l_array=(${l_mapValue//,/ })
        ((l_array[1]= l_array[1] + l_deletedRowNum))
        # shellcheck disable=SC2124
        l_mapValue="${l_array[@]}"
        l_mapValue="${l_mapValue// /,}"
        gFileDataBlockMap["${l_mapKey}"]="${l_mapValue}"
      fi
    done
  fi
}

#在缓存中查找Value值中起始行号大于l_startRowNum的记录，将其起始行号减去l_deletedRowNum数量。
function _adjustStartRowNum() {
  export gFileDataBlockMap

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_startRowNum=$3
  local l_changedLineCount=$4

  local l_mapSize
  local l_mapKey
  local l_mapValue
  local l_array

  l_mapSize="${#gFileDataBlockMap[@]}"
  if [ "${l_mapSize}" -gt 0 ];then
    # shellcheck disable=SC2068
    for l_mapKey in ${!gFileDataBlockMap[@]};do
      #如果不是目标文件的参数路径，则直接继续下一个。
      if [[ ! "${l_mapKey}" =~ ^(${l_yamlFile//\./\\\.}) ]];then
        continue
      fi
      #读取可能存在的缓存参数。
      l_mapValue="${gFileDataBlockMap[${l_mapKey}]}"
      if [ "${l_mapValue}" ];then
        # shellcheck disable=SC2206
        l_array=(${l_mapValue//,/ })
        if [ "${l_array[0]}" -gt "${l_startRowNum}" ];then
          ((l_array[0] = l_array[0] + l_changedLineCount))
          ((l_array[1] = l_array[1] + l_changedLineCount))
          # shellcheck disable=SC2124
          l_mapValue="${l_array[@]}"
          l_mapValue="${l_mapValue// /,}"
          gFileDataBlockMap["${l_mapKey}"]="${l_mapValue}"
        fi
      fi
    done
  fi
}

function _combine(){
  export gDefaultRetVal

  local l_srcContent=$1
  local l_srcParamPath=$2
  local l_targetYamlFile=$3
  local l_targetParamPath=$4
  local l_allowInsertNewListItem=$5
  local l_exitOnFailure=$6
  #当列表项中存在特殊的"- !"项时，l_reserveDeleteItem为true表示：需要将这项也同时赋值到目标文件中
  local l_cascadeDelete=$7

  #第一个有效行的内容
  local l_firstLineContent
  #某层前导空格数
  local l_layerPrefixSpaceNum
  #读取某层参数的正则表达式
  local l_layerRegex
  #某层的参数行
  local l_layerParamLines
  local l_tmpParamLine

  local l_cascadeDeleteFlag
  local l_targetParamContent
  local l_targetParamItemCount

  #子函数内会调用_targetParamNameIndexMap变量
  declare -A _targetParamNameIndexMap

  local l_lineNum
  local l_itemRowNum
  local l_paramName
  local l_paramValue
  local l_tmpSpaceNum
  local l_lineCount
  local l_tmpIndex
  local l_targetIndex

  local l_startRowNum
  local l_endRowNum
  local l_tmpContent
  local l_tmpContent1
  local l_tmpSrcParamPath
  local l_tmpTargetParamPath
  local l_tmpContent2

  if [ ! "${l_srcContent}" ];then
    return
  fi

  #先获取第一个有效行，以该行的前导空格数作为第一层参数的前导空格数。
  #l_firstLineContent=$(grep -m 1 -E '^[ ]*[a-zA-Z_-]+.*$' <<< "${l_srcContent}")
  _getMatchedLines "${l_srcContent}" "^[ ]*[a-zA-Z_\-]+.*$" "first"
  l_firstLineContent="${gDefaultRetVal#*:}"
  l_tmpContent=${l_firstLineContent%%[^ ]*}  # 提取行首连续空格
  l_layerPrefixSpaceNum=${#l_tmpContent}      # 直接获取空格数量

  if [[ "${l_firstLineContent}" =~ ^([ ]*)\- ]];then
    #读取所有的列表项起始行
    l_layerRegex="^[ ]{${l_layerPrefixSpaceNum}}- .*"
    l_layerParamLines=$(grep -nE "${l_layerRegex}" <<< "${l_srcContent}")

    #判断是否存在”- !“格式的列表项：如果存在则使用源文件中的当前参数值整体替换目标文件中对应的列表参数的值。
    l_cascadeDeleteFlag=$(grep -E "^([0-9]+):([ ]*)\-([ ]*)!([ ]*)$" <<< "${l_layerParamLines}")
    if [ "${l_cascadeDeleteFlag}" ];then
      #整体赋值到目标文件对应列表参数。
      info "检测到带有整体替换标识项的列表型参数${l_targetParamPath}，执行整体替换 ..."
      if [[ "${l_allowInsertNewListItem}" == "true" ]];then
        insertParam "${l_targetYamlFile}" "${l_targetParamPath}" "${l_srcContent}"
      else
        updateParam "${l_targetYamlFile}" "${l_targetParamPath}" "${l_srcContent}"
      fi
      if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
        if [[ "${l_exitOnFailure}" == "true" ]];then
          error "整体替换${l_targetParamPath}参数失败"
        else
          warn "整体替换${l_targetParamPath}参数失败"
        fi
      else
        info "整体替换成功"
      fi
      return
    fi

    getListTypeByContent "${l_srcContent}"
    if [ "${gDefaultRetVal}" == "array" ];then
      #是数组，则直接整体替换。
      info "检测到数组型列表参数${l_targetParamPath}，执行整体替换 ..."
      if [[ "${l_allowInsertNewListItem}" == "true" ]];then
        insertParam "${l_targetYamlFile}" "${l_targetParamPath}" "${l_srcContent}"
      else
        updateParam "${l_targetYamlFile}" "${l_targetParamPath}" "${l_srcContent}"
      fi
      if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
        if [[ "${l_exitOnFailure}" == "true" ]];then
          error "整体替换${l_targetParamPath}参数失败"
        else
          warn "整体替换${l_targetParamPath}参数失败"
        fi
      else
        info "整体替换成功"
      fi
      return
    fi

    #预先读取目标文件中l_targetParamPath列表参数的内容。
    info "将目标文件中${l_targetParamPath}参数的现有值读入内存中备查 ..."
    l_targetParamContent=""
    readParam "${l_targetYamlFile}" "${l_targetParamPath}"
    if [ "${gDefaultRetVal}" == "null" ];then
      if [[ "${l_exitOnFailure}" == "true" ]];then
        error "目标文件中不存在${l_targetParamPath}参数"
      else
        warn "缓存${l_targetParamPath}参数现有值失败: 目标文件中不存在${l_targetParamPath}参数"
      fi
    else
      #预先读取目标文件中l_targetParamPath参数的内容。
      _deleteInvalidLines "${gDefaultRetVal}"
      l_targetParamContent="${gDefaultRetVal}"
      if [ "${l_targetParamContent}" ];then
        #列表项转成Map存放，方便后续匹配查找。
        _convertToNameIndexMap "${l_targetParamContent}"
      else
        warn "缓存${l_targetParamPath}参数现有值失败"
      fi
    fi

    #逐项更新到目标文件中
    l_lineCount=$(echo -e "${l_layerParamLines}" | sed -n '$=')
    ((l_tmpIndex = 0))
    while [ "${l_tmpIndex}" -lt "${l_lineCount}" ];do
      #读取列表项数据块的起始行行号
      ((l_lineNum = l_tmpIndex + 1))
      #l_tmpParamLine=$(echo -e "${l_layerParamLines}" | sed -n "${l_lineNum}p")
      _readLinesInRange "${l_layerParamLines}" "${l_lineNum}"
      l_tmpParamLine="${gDefaultRetVal}"
      l_startRowNum="${l_tmpParamLine%%:*}"
      #读取列表项数据块的截止行的行号
      ((l_lineNum = l_lineNum + 1))
      if [ "${l_lineNum}" -gt "${l_lineCount}" ];then
        #读取参数的数据块
        #l_tmpContent=$(echo -e "${l_srcContent}" | sed -n "${l_startRowNum}, \$p")
        _readLinesInRange "${l_srcContent}" "${l_startRowNum}" "-1"
        l_tmpContent="${gDefaultRetVal}"
      else
        #l_tmpParamLine=$(echo -e "${l_layerParamLines}" | sed -n "${l_lineNum}p")
        _readLinesInRange "${l_layerParamLines}" "${l_lineNum}"
        l_tmpParamLine="${gDefaultRetVal}"
        l_endRowNum="${l_tmpParamLine%%:*}"
        ((l_endRowNum = l_endRowNum - 1))
        #读取参数的数据块
        #l_tmpContent=$(echo -e "${l_srcContent}" | sed -n "${l_startRowNum}, ${l_endRowNum}p")
        _readLinesInRange "${l_srcContent}" "${l_startRowNum}" "${l_endRowNum}"
        l_tmpContent="${gDefaultRetVal}"
      fi

      #删除前导“-”符号。
      l_tmpContent1="${l_tmpContent/-/ }"
      #删除l_tmpContent前导空格
      _indentContent "${l_tmpContent1}" "-2"
      l_tmpContent1="${gDefaultRetVal}"

      #读取l_tmpContent1中name属性的值。 如果不存在name属性，则继续后面的处理。
      #l_paramName=$(echo -e "${l_tmpContent1}" | grep -m 1 -oP "^name:(.*)$")
      _getMatchedLines "${l_tmpContent1}" "^name:(.*)$" "first"
      l_tmpContent2="${gDefaultRetVal#*:}"

      if [[ "${l_tmpContent2}" ]];then
        #获取参数的值
        l_paramName="${l_tmpContent2#*:}"
        #去掉左右空格。
        l_paramName="${l_paramName#"${l_paramName%%[^[:space:]]*}"}"
        l_paramName="${l_paramName%"${l_paramName##*[^[:space:]]}"}"
        #如果剩下的值内容是以#开头的，则将l_paramName设置为空串。
        [[ "${l_paramName}" =~ ^[#]+ ]] && l_paramName=""
        #如果存在name属性，但是没有配置值，则不处理这个列表项。
        if [ ! "${l_paramName}" ];then
          warn "忽略项列表项${l_srcParamPath}[${l_tmpIndex}](存在name属性但是没有设置值)，继续下一个列表项"
          ((l_tmpIndex = l_tmpIndex + 1))
          continue
        fi
      fi

      l_targetParamItemCount="${#_targetParamNameIndexMap[@]}"

      ((l_targetIndex = -1))
      if [ "${l_targetParamItemCount}" -gt 0 ];then
        #根据列表项的name属性的值（优先）或列表项的序号，匹配源参数路径对应的目标参数路径
        _getMatchedListItemIndex "${l_tmpContent}" "${l_layerPrefixSpaceNum}" "${l_tmpIndex}"
        l_targetIndex="${gDefaultRetVal}"
      fi

      #将l_tmpContent变量设置为已经去掉前导“-”和空格的数据。
      l_tmpContent="${l_tmpContent1}"

      #如果没有匹配到，则直接追加到目标文件对应的列表参数中
      if [[ "${l_targetIndex}" -eq -1 ]];then
        if [[ "${l_allowInsertNewListItem}" != "true" ]];then
          warn "忽略项列表项${l_srcParamPath}[${l_tmpIndex}](在目标文件中未能匹配到对应的列表项)，继续下一个列表项"
          ((l_tmpIndex = l_tmpIndex + 1))
          continue
        fi
        #直接将列表项追加到目标文件对应的列表参数中
        info "向目标文件中插入列表项参数${l_targetParamPath}[${l_targetParamItemCount}] ..."
        insertParam "${l_targetYamlFile}" "${l_targetParamPath}[${l_targetParamItemCount}]" "${l_tmpContent}"
        if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
          if [[ "${l_exitOnFailure}" == "true" ]];then
            error "向目标文件中插入列表项参数${l_targetParamPath}[${l_targetParamItemCount}]失败"
          else
            warn "向目标文件中插入列表项参数${l_targetParamPath}[${l_targetParamItemCount}]失败"
            return
          fi
        else
          info "列表项参数整体插入成功"
          _targetParamNameIndexMap["${l_paramName}"]="${l_targetParamItemCount}"
        fi
      else
        #递归调用处理下层参数。
        l_tmpSrcParamPath="${l_srcParamPath}[${l_tmpIndex}]"
        [[ "${l_tmpSrcParamPath}" =~ ^\. ]] && l_tmpSrcParamPath="${l_tmpSrcParamPath:1}"
        l_tmpTargetParamPath="${l_targetParamPath}[${l_targetIndex}]"
        [[ "${l_tmpTargetParamPath}" =~ ^\. ]] && l_tmpTargetParamPath="${l_tmpTargetParamPath:1}"
        info "合并源文件中${l_tmpSrcParamPath}参数(目标文件中对应参数路径为${l_tmpTargetParamPath}) ..."
        _combineObject "${l_tmpContent}" "${l_tmpSrcParamPath}" "${l_targetYamlFile}" "${l_tmpTargetParamPath}" \
          "${l_allowInsertNewListItem}" "${l_exitOnFailure}" "${l_cascadeDelete}"
      fi

      ((l_tmpIndex = l_tmpIndex + 1))
    done
    return
  fi

  _combineObject "${@}"

}

function _combineObject(){
  export gDefaultRetVal

  local l_srcContent=$1
  local l_srcParamPath=$2
  local l_targetYamlFile=$3
  local l_targetParamPath=$4
  local l_allowInsertNewListItem=$5
  local l_exitOnFailure=$6
  #当列表项中存在特殊的"- !"项时，l_reserveDeleteItem为true表示：需要将这项也同时赋值到目标文件中
  local l_cascadeDelete=$7

  local l_targetParamBlockContent

  local l_firstLineContent
  local l_layerPrefixSpaceNum

  local l_layerRegex
  local l_layerParamLines
  local l_tmpArray
  local l_lineCount
  local l_tmpIndex

  local l_tmpParamLine
  local l_itemRowNum
  local l_paramName
  local l_paramValue
  local l_targetParamValue
  local l_tmpSpaceNum

  local l_tmpSrcParamPath
  local l_tmpTargetParamPath

  #读取目标文件中相同参数的数据块,以备后续使用。
  if [ "${l_targetParamPath}" ];then
    info "将目标文件中${l_targetParamPath}参数的现有值读入内存中备查 ..."
    readParam "${l_targetYamlFile}" "${l_targetParamPath}"
    if [[ "${gDefaultRetVal}" == "null" ]];then
      l_targetParamBlockContent=""
      warn "缓存${l_targetParamPath}参数现有值失败"
    else
      l_targetParamBlockContent="${gDefaultRetVal}"
      _deleteInvalidLines "${l_targetParamBlockContent}"
      l_targetParamBlockContent="${gDefaultRetVal}"
    fi
  fi

  #l_firstLineContent=$(echo -e "${l_srcContent}" | grep -m 1 -oP "^([ ]*)[a-zA-Z_\-]+" )
  #l_layerPrefixSpaceNum=$(echo -e "${l_firstLineContent}" | grep -oP "^[ ]*" | grep -oP " " | wc -l)
  _getMatchedLines "${l_srcContent}" "^([ ]*)[a-zA-Z_\-]+.*$" "first"
  l_firstLineContent="${gDefaultRetVal#*:}"
  l_firstLineContent="${l_firstLineContent%%[^ ]*}"  # 提取行首连续空格
  l_layerPrefixSpaceNum=${#l_firstLineContent}       # 直接获取空格数量

  #内容不是列表类型的，则读取参数名称及其参数值。
  l_layerRegex="^[ ]{${l_layerPrefixSpaceNum}}[a-zA-Z_-]+(.*)$"
  l_layerParamLines=$(grep -nE "${l_layerRegex}" <<< "${l_srcContent}")

  #l_lineCount=$(echo -e "${l_layerParamLines}" | sed -n '$=')
  readarray -t l_tmpArray <<< "${l_layerParamLines}"
  l_lineCount=${#l_tmpArray[@]}

  ((l_tmpIndex = 0))
  while [ "${l_tmpIndex}" -lt "${l_lineCount}" ];do
    #读取l_layerParamLines中的第l_tmpIndex行数据
    l_tmpParamLine=${l_tmpArray[${l_tmpIndex}]}
    #读取参数所在行的行号
    l_itemRowNum="${l_tmpParamLine%%:*}"
    #过滤掉行号部分的内容
    l_tmpParamLine="${l_tmpParamLine#*:}"
    #读取参数名称
    l_paramName="${l_tmpParamLine%%:*}"
    if [ "${l_paramName}" != "${l_tmpParamLine}" ];then
      #删除参数名称前的空格。
      l_paramName="${l_paramName// /}"
      #读取参数值
      l_paramValue="${l_tmpParamLine#*:}"
      if [ "${l_paramValue}" ];then
        #获取参数值的前导空格数量。
        l_tmpSpaceNum=$(echo -e "${l_paramValue}" | grep -oP "^[ ]*" | grep -oP " " | wc -l)
        #删除参数的前导空格。
        l_paramValue="${l_paramValue:${l_tmpSpaceNum}}"
        #删除参数值尾部空格。
        l_paramValue=$(echo -e "${l_paramValue}" | sed 's/[[:space:]]*$//')
        #如果剩下的值内容是以#开头的，则将l_paramValue设置为空串。
        [[ "${l_paramValue}" =~ ^[#]+ ]] && l_paramValue=""
      fi

      if [ ! "${l_paramValue}" ];then
        #l_paramValue为空，则读取参数的下属数据块。
        _readDataBlockContent "${l_srcContent}" "${l_itemRowNum}" "${l_layerPrefixSpaceNum}"
        l_paramValue="${gDefaultRetVal}"
        if [ "${l_paramValue}" ];then
          l_tmpSrcParamPath="${l_srcParamPath}.${l_paramName}"
          [[ "${l_tmpSrcParamPath}" =~ ^\. ]] && l_tmpSrcParamPath="${l_tmpSrcParamPath:1}"
          l_tmpTargetParamPath="${l_targetParamPath}.${l_paramName}"
          [[ "${l_tmpTargetParamPath}" =~ ^\. ]] && l_tmpTargetParamPath="${l_tmpTargetParamPath:1}"
          info "合并源文件中${l_tmpSrcParamPath}参数(目标文件中对应参数路径为${l_tmpTargetParamPath}) ..."
          #递归调用处理下层参数。
          _combine "${l_paramValue}" "${l_tmpSrcParamPath}" "${l_targetYamlFile}" "${l_tmpTargetParamPath}" \
            "${l_allowInsertNewListItem}" "${l_exitOnFailure}" "${l_cascadeDelete}"
          ((l_tmpIndex = l_tmpIndex + 1))
          continue
        fi
      fi

      #处理单值多行的情况
      if [[ "${l_paramValue}" && "${l_paramValue}" =~ ^\| ]];then
        #需要读取参数的下属数据块。
        _readDataBlockContent "${l_srcContent}" "${l_itemRowNum}" "${l_layerPrefixSpaceNum}"
        [[ "${gDefaultRetVal}" ]] && l_paramValue="${l_paramValue}\n${gDefaultRetVal}"
      fi

      #判断l_paramValue值与目标文件中的值是否不同，不同才执行更新。
      l_targetParamValue=""
      if [ "${l_targetParamBlockContent}" ];then
        l_tmpParamLine=$(echo -e "${l_targetParamBlockContent}" | grep -m 1 -noP "^${l_paramName}:(.*)$")
        l_itemRowNum="${l_tmpParamLine%%:*}"
        l_tmpParamLine="${l_tmpParamLine#*:}"
        l_targetParamValue="${l_tmpParamLine#*:}"
        if [ "${l_targetParamValue}" ];then
          #获取参数值的前导空格数量。
          l_tmpSpaceNum=$(echo -e "${l_targetParamValue}" | grep -oP "^[ ]*" | grep -oP " " | wc -l)
          #删除参数的前导空格。
          l_targetParamValue="${l_targetParamValue:${l_tmpSpaceNum}}"
          #删除参数值尾部空格。
          l_targetParamValue=$(echo -e "${l_targetParamValue}" | sed 's/[[:space:]]*$//')
          #如果剩下的值内容是以#开头的，则将l_paramValue设置为空串。
          [[ "${l_targetParamValue}" =~ ^[#]+ ]] && l_targetParamValue=""
        fi
        #处理单值多行的情况
        if [[ "${l_targetParamValue}" && "${l_targetParamValue}" =~ ^\| ]];then
          #需要读取参数的下属数据块。
          _readDataBlockContent "${l_targetParamBlockContent}" "${l_itemRowNum}" "0"
          [[ "${gDefaultRetVal}" ]] && l_targetParamValue="${l_targetParamValue}\n${gDefaultRetVal}"
        fi
      fi

      if [ "${l_targetParamValue}" != "${l_paramValue}" ];then
        #直接赋值给目标文件中的对应参数。
        if [[ "${l_allowInsertNewListItem}" == "false" ]];then
          updateParam "${l_targetYamlFile}" "${l_targetParamPath}.${l_paramName}" "${l_paramValue}"
        else
          insertParam "${l_targetYamlFile}" "${l_targetParamPath}.${l_paramName}" "${l_paramValue}"
        fi
        if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
          if [[ "${l_allowInsertNewListItem}" == "false" && "${l_exitOnFailure}" == "true" ]];then
            error "合并${l_targetParamPath}.${l_paramName}参数失败:${gDefaultRetVal}"
          else
            warn "合并${l_targetParamPath}.${l_paramName}参数失败:${gDefaultRetVal}"
            return
          fi
        else
          info "合并${l_targetParamPath}.${l_paramName}参数的值为:${l_paramValue}"
        fi
      else
        warn "${l_targetParamPath}.${l_paramName}参数值(${l_targetParamValue})没有变化，继续合并下一个参数 ..."
      fi

    fi
    ((l_tmpIndex = l_tmpIndex + 1))
  done

}

#combine函数使用的数据块内容读取函数
function _readDataBlockContent(){
  export gDefaultRetVal

  local l_srcContent=$1
  local l_lineNum=$2
  local l_linePrefixSpaceNum=$3

  local l_tmpRowNum
  local l_content
  local l_tmpContent
  local l_tmpRegex
  local l_tmpSpaceNum

  gDefaultRetVal=""

  #获取目标范围内的内容
  ((l_tmpRowNum = l_lineNum + 1))
  l_content=$(echo -e "${l_srcContent}" | sed -n "${l_tmpRowNum},\$p")
  if [ ! "${l_content}" ];then
    return
  fi

  #获取第一个兄弟行或父级行
  l_tmpRegex="^[ ]{0,${l_linePrefixSpaceNum}}[a-zA-Z_]+"
  if [ "${l_linePrefixSpaceNum}" -gt 0 ];then
    ((l_tmpSpaceNum = l_linePrefixSpaceNum -1))
    l_tmpRegex="^([ ]{0,${l_tmpSpaceNum}}\-|${l_tmpRegex:1})"
  fi

  l_tmpContent=$(echo -e "${l_content}" | grep -m 1 -noP "${l_tmpRegex}")
  if [ "${l_tmpContent}" ];then
    l_tmpRowNum="${l_tmpContent%%:*}"
    ((l_tmpRowNum = l_tmpRowNum - 1))
    if [ "${l_tmpRowNum}" -gt 0 ];then
      l_content=$(echo -e "${l_content}" | sed -n "1,${l_tmpRowNum}p")
    else
      l_content=""
    fi
  fi

  if [ "${l_content}" ];then
    #统一去除前导空格
    l_tmpSpaceNum=$(echo -e "${l_content}" | grep -m 1 -oP "^([ ]*)[a-zA-Z_\-]+" | grep -oP "^[ ]*" | grep -oP " " | wc -l)
    if [ "${l_tmpSpaceNum}" -gt 0 ];then
      _indentContent "${l_content}" "-${l_tmpSpaceNum}"
      l_content="${gDefaultRetVal}"
    fi
    #去除注释行和空白行
    _deleteInvalidLines "${l_content}"
  fi

}

#删除无效行
function _deleteInvalidLines() {
  export gDefaultRetVal

  local l_srcContent=$1

  local l_lineCount
  local l_tmpIndex
  local l_tmpContent

  gDefaultRetVal=""

  if [ ! "${l_srcContent}" ];then
    return
  fi

  #去除注释行和空白行
  l_lineCount=$(sed -n '$=' <<< "${l_srcContent}")
  l_tmpIndex=1;
  while [ "${l_tmpIndex}" -le "${l_lineCount}" ];do
    l_tmpContent=$(sed -n "${l_tmpIndex}p" <<< "${l_srcContent}")
    if [[ "${l_tmpContent}" =~ ^([ ]*)# || "${l_tmpContent}" =~ ^([ ]*)$ ]];then
      #删除注释行或空白行
      l_srcContent=$(sed "${l_tmpIndex}d" <<< "${l_srcContent}")
      ((l_lineCount = l_lineCount -1))
      continue
    fi
    ((l_tmpIndex = l_tmpIndex + 1))
  done
  gDefaultRetVal="${l_srcContent}"
}

function _getMatchedListItemIndex(){
  export _targetParamNameIndexMap

  local l_srcContent=$1
  local l_prefixSpaceNum=$2
  local l_srcIndex=$3
  local l_allowInsertNewListItem=$4

  local l_targetItemCount
  local l_nameLine
  local l_srcNameValue
  local l_targetIndex
  local l_tmpSpaceNum

  l_targetItemCount=${#_targetParamNameIndexMap[@]}
  if [ "${l_targetItemCount}" -eq 0 ];then
    ((l_targetItemCount = -1))
  fi

  l_srcContent="${l_srcContent/-/ }"
  ((l_prefixSpaceNum = l_prefixSpaceNum + 2))
  #l_nameLine=$(echo -e "${l_srcContent}" | grep -m 1 -oP "^[ ]{${l_prefixSpaceNum}}name:(.*)$")
  _getMatchedLines "${l_srcContent}" "^[ ]{${l_prefixSpaceNum}}name:(.*)$" "first"
  l_nameLine="${gDefaultRetVal#*:}"
  #如果源内容中没有name属性，或者目标内容中没有name属性，都按序号进行匹配。
  if [[ ! "${l_nameLine}" || "${l_targetItemCount}" -lt 0 ]];then
    ((l_targetIndex = l_srcIndex))
    #如果l_srcIndex大于等于l_targetItemCount，则设置l_targetIndex=-1，表示没有匹配到。
    [[ "${l_srcIndex}" -ge "${l_targetItemCount}" ]] && ((l_targetIndex = -1))
    gDefaultRetVal="${l_targetIndex}"
    return
  fi

  ((l_targetIndex = -1))
  #源内容和目标内容都有name,则按name进行匹配，匹配失败则返回-1.
  l_srcNameValue="${l_nameLine#*:}"
  if [ "${l_srcNameValue}" ];then
    #删除参数的前导空格和尾部空格。
    l_srcNameValue="${l_srcNameValue#"${l_srcNameValue%%[^[:space:]]*}"}"
    l_srcNameValue="${l_srcNameValue%"${l_srcNameValue##*[^[:space:]]}"}"
    [[ "${l_srcNameValue}" =~ ^[#]+ ]] && l_srcNameValue=""
    if [ "${l_srcNameValue}" ];then
      # shellcheck disable=SC2154
      l_targetIndex="${_targetParamNameIndexMap[${l_srcNameValue}]}"
      # shellcheck disable=SC2145
      [[ ! "${l_targetIndex}" ]] && ((l_targetIndex = -1))
    fi
  fi
  gDefaultRetVal="${l_targetIndex}"
}

function _convertToNameIndexMap() {
  export _targetParamNameIndexMap

  local l_srcContent=$1

  local l_itemLines
  local l_itemCount
  local l_itemIndex

  local l_lineNum
  local l_lineContent
  local l_startRowNum
  local l_endRowNum
  local l_itemContent
  local l_nameLine
  local l_targetNameValue
  local l_tmpSpaceNum

  l_itemLines=$(echo -e "${l_srcContent}" | grep -noP "^\-")
  l_itemCount=$(echo -e "${l_itemLines}" | wc -l)
  ((l_itemIndex = 0))
  while [ "${l_itemIndex}" -lt "${l_itemCount}" ];do
    #读取列表项的开始行的行号
    ((l_lineNum = l_itemIndex + 1))
    l_lineContent=$(echo -e "${l_itemLines}" | sed -n "${l_lineNum}p")
    l_startRowNum="${l_lineContent%%:*}"
    #读取列表项的截止行的行号
    ((l_lineNum = l_lineNum + 1))
    if [ "${l_lineNum}" -ge "${l_itemCount}" ];then
      #读取参数的数据块
      l_itemContent=$(echo -e "${l_srcContent}" | sed -n "${l_startRowNum},\$p")
    else
      l_lineContent=$(echo -e "${l_itemLines}" | sed -n "${l_lineNum}p")
      l_endRowNum="${l_lineContent%%:*}"
      ((l_endRowNum = l_endRowNum - 1))
      #读取参数的数据块
      l_itemContent=$(echo -e "${l_srcContent}" | sed -n "${l_startRowNum}, ${l_endRowNum}p")
    fi

    l_targetNameValue="${l_itemIndex}_targetParamNameIndexMap"

    l_itemContent="${l_itemContent/-/ }"
    l_nameLine=$(echo -e "${l_itemContent}" | grep -m 1 -oP "^[ ]{2}name:(.*)$")
    if [ "${l_nameLine}" ];then
      l_nameLine="${l_nameLine#*:}"
      #获取参数值的前导空格数量。
      l_tmpSpaceNum=$(echo -e "${l_nameLine}" | grep -oP "^[ ]*" | grep -oP " " | wc -l)
      #删除参数的前导空格。
      l_nameLine="${l_nameLine:${l_tmpSpaceNum}}"
      #删除参数值尾部空格。
      l_nameLine=$(echo -e "${l_nameLine}" | sed 's/[[:space:]]*$//')
      #如果剩下的值内容是以#开头的，则将l_paramValue设置为空串。
      [[ "${l_nameLine}" =~ ^[#]+ ]] && l_nameLine=""
      [[ "${l_nameLine}" ]] && l_targetNameValue="${l_nameLine}"
    fi
    _targetParamNameIndexMap["${l_targetNameValue}"]="${l_itemIndex}"

    ((l_itemIndex = l_itemIndex + 1))
  done

}

function _getAllParamPathAndValueByParentPath() {
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_paramPath=$2
  # 关联数组引用
  local l_resultMapName=$3
  # 顺序数组引用
  local l_paramKeys=$4
  local l_paramDataBlock=$5
  local l_paramPathPrefix=$6

  local l_firstLine
  local l_content
  local l_listItemCount
  local l_i

  local l_paramLines
  local l_paramLine
  local l_paramName
  local l_paramValue
  local l_tmpParamPath
  local l_lineCount
  local l_currentIndex

  #排除注释行
  l_firstLine=$(grep -m 1 -oP "^[a-zA-Z_\-]+.*" <<< "${l_paramDataBlock}")
  [[ ! "${l_firstLine}" ]] && return

  if [[ "${l_paramPathPrefix}" && ! "${l_paramPathPrefix}" =~ ^(.*)(\.)$ ]];then
    l_paramPathPrefix="${l_paramPathPrefix}."
  fi

  if [[ "${l_firstLine}" =~ ^(\- ) ]];then
    l_content=$(grep -oP "^(\- )" <<< "${l_paramDataBlock}")
    l_listItemCount=$(wc -l <<< "${l_content}")
    getListTypeByContent "${l_content}"
    if [ "${gDefaultRetVal}" == "array" ];then
      #处理数组项
      for (( l_i=0; l_i < l_listItemCount; l_i++ ));do
        readParam "${l_yamlFile}" "${l_paramPath[${l_i}]}"
        info "将${l_paramPath}[${l_i}]参数及其值${gDefaultRetVal}放入${l_resultMapName}中"
        eval "${l_resultMapName}[${l_paramPathPrefix}${l_paramPath}[${l_i}]]=\"${gDefaultRetVal}\""
        # 获取数组当前长度作为新元素的索引
        eval "l_currentIndex=\"\${#${l_paramKeys}[@]}\""
        eval "${l_paramKeys}[${l_currentIndex}]=\"${l_paramPathPrefix}${l_paramPath}[${l_i}]\""
      done
    else
      for (( l_i=0; l_i < l_listItemCount; l_i++ ));do
        #读取列表项的数据块
        readParam "${l_yamlFile}" "${l_paramPath}[${l_i}]"
        l_paramDataBlock="${gDefaultRetVal}"
        #递归处理列表项
        _getAllParamPathAndValueByParentPath "${l_yamlFile}" "${l_paramPath}[${l_i}]" \
          "${l_resultMapName}" "${l_paramKeys}" "${l_paramDataBlock}" "${l_paramPathPrefix}"
      done
    fi
    return
  fi

  l_content=$(grep -oP "^([a-zA-Z_]+).*$" <<< "${l_paramDataBlock}")
  stringToArray "${l_content}" "l_paramLines"
  l_listItemCount=${#l_paramLines[@]}
  # shellcheck disable=SC2068
  for (( l_i=0; l_i < l_listItemCount; l_i++ ));do
    l_paramLine="${l_paramLines[${l_i}]}"
    l_paramName="${l_paramLine%%:*}"
    l_paramValue="${l_paramLine#*:}"
    #去掉头尾空格
    l_paramValue="${l_paramValue#"${l_paramValue%%[^[:space:]]*}"}"
    l_paramValue="${l_paramValue%"${l_paramValue##*[^[:space:]]}"}"

    l_tmpParamPath="${l_paramPath}.${l_paramName}"
    readParam "${l_yamlFile}" "${l_tmpParamPath}"

    if [[ "${l_paramValue}" =~ ^([ ]*\|[ ]*$) || "${l_paramValue}" || ! "${gDefaultRetVal}" ]];then
      # 获取数组当前长度作为新元素的索引
      eval "l_currentIndex=\"\${#${l_paramKeys}[@]}\""
      eval "${l_paramKeys}[${l_currentIndex}]=\"${l_paramPathPrefix}${l_tmpParamPath}\""
    fi

    if [[ "${l_paramValue}" =~ ^([ ]*\|[ ]*$) ]];then
      info "将${l_paramPathPrefix}${l_tmpParamPath}参数及其值(多行数据)放入${l_resultMapName}中"
      eval "${l_resultMapName}[${l_paramPathPrefix}${l_tmpParamPath}]=\"${gDefaultRetVal}\""
    elif [ "${l_paramValue}" ];then
      info "将${l_paramPathPrefix}${l_tmpParamPath}参数及其值${l_paramValue}放入${l_resultMapName}"
      eval "${l_resultMapName}[${l_paramPathPrefix}${l_tmpParamPath}]=\"${l_paramValue}\""
    elif [ ! "${gDefaultRetVal}" ];then
      info "将${l_paramPathPrefix}${l_tmpParamPath}参数及其值(空)放入${l_resultMapName}中"
      eval "${l_resultMapName}[${l_paramPathPrefix}${l_tmpParamPath}]=\"\""
    else
      #递归处理列表项
      _getAllParamPathAndValueByParentPath "${l_yamlFile}" "${l_tmpParamPath}" \
        "${l_resultMapName}" "${l_paramKeys}" "${gDefaultRetVal}" "${l_paramPathPrefix}"
    fi
  done

}

function _getParamLines() {
  export gDefaultRetVal

  local l_content="$1"
  local l_param="$2"
  local l_space="$3"

  gDefaultRetVal=$(awk -v space="${l_space}" -v param="${l_param}" '
BEGIN {
   # 构建两种匹配模式：列表项格式和子级格式
   regex1 = "^ {" space "}- "param":"     # 精确匹配列表项
   regex2 = "^ {" space + 2 "}"param":"    # 精确匹配子级项
}
{
   # 检查前导空格数
   prefix = substr($0, 1, space + 2)
   if ($0 ~ regex1 || $0 ~ regex2) {
       print
   }
}' <<< "${l_content}")
}

function _getItemCount() {
  export gDefaultRetVal

  local l_content=$1
  local l_spaceNum=$2

  local l_itemCount
  local l_line

  mapfile -t matches <<< "${l_content}"
  l_itemCount=0
  for l_line in "${matches[@]}"; do
    [[ "${l_line}" =~ ^[[:space:]]{${l_spaceNum}}- ]] && ((l_itemCount++))
  done
  gDefaultRetVal="${l_itemCount}"
}

function _getLineCount() {
  export gDefaultRetVal

  local l_content=$1
  local l_spaceNum=$2

  local l_itemCount
  local l_line

  mapfile -t matches <<< "${l_content}"
  l_itemCount=0
  for l_line in "${matches[@]}"; do
    [[ "${l_line}" =~ ^[[:space:]]\w+ ]] && ((l_itemCount++))
  done
  gDefaultRetVal="${l_itemCount}"
}

function _getParamValue() {
  export gDefaultRetVal

  local l_lineContent=$1
  local l_paramValue=$2
  local l_paramQueryDicFile=$3
  local l_paramQueryDicPrefix=$4

  local l_curParamValue
  local l_params
  local l_param

  #读取冒号后面的内容。
  l_curParamValue="${l_lineContent#*:}"
  #去掉左右空格
  l_curParamValue="${l_curParamValue#"${l_curParamValue%%[^[:space:]]*}"}"
  l_curParamValue="${l_curParamValue%"${l_curParamValue##*[^[:space:]]}"}"

  if [ "${l_curParamValue}" != "${l_paramValue}" ];then
    #读取返回值中包含的参数变量。
    l_params=$(grep -oE '\$\{[a-zA-Z_]\w*(\-\w+)*\}' <<< "${l_curParamValue}")
    if [ "${l_params}" ];then
      # shellcheck disable=SC2068
      for l_param in ${l_params[@]};do
        l_param="${l_param#*\{}"
        l_param="${l_param%\}*}"
        #读取同文件中的变量的值。
        readParam "${l_paramQueryDicFile}" "${l_paramQueryDicPrefix}.${l_param}"
        [[ "${gDefaultRetVal}" != "null" ]] && l_curParamValue="${l_curParamValue//\$\{${l_param}\}/${gDefaultRetVal}}"
      done
    fi
  fi
  gDefaultRetVal="${l_curParamValue}"
}

#获取匹配的行内容
function _getMatchedLines() {
  export gDefaultRetVal

  local l_lines=$1
  local l_regexStr=$2
  local l_mode=$3

  local line_number=0
  local l_matched_line
  local l_line

  while IFS= read -r l_line; do
    ((line_number++))
    if [[ "${l_line}" =~ ${l_regexStr} ]]; then
      if [ "${l_mode}" == "first" ];then
        l_matched_line="${line_number}:${l_line}"
        break;
      elif [ "${l_mode}" == "last" ];then
        l_matched_line="${line_number}:${l_line}"
      else
        if [ "${l_matched_line}" ];then
          l_matched_line="${l_matched_line}\n${line_number}:${l_line}"
        else
          l_matched_line="${line_number}:${l_line}"
        fi
      fi
    fi
  done <<< "${l_lines}"

  if [[ "${l_mode}" == "first" || "${l_mode}" == "last" ]];then
    gDefaultRetVal="${l_matched_line}"
  elif [ "${l_matched_line}" ];then
    gDefaultRetVal=$(echo -e "${l_matched_line}")
  else
    gDefaultRetVal=""
  fi
}

#获取给定内容中指定行号范围内的内容。
function _readLinesInRange() {
  export gDefaultRetVal

  local l_content=$1
  local l_startRowNum=$2
  local l_endRowNum=$3

  local l_content_array
  local l_array_length
  local l_start
  local l_end

  if [ ! "${l_endRowNum}" ];then
    l_endRowNum="${l_startRowNum}"
  fi

  # 转换行号为数组索引（数组从0开始）
  ((l_start = l_startRowNum - 1))

  mapfile -t l_content_array <<< "${l_content}"
  l_array_length=${#l_content_array[@]}

  # 处理结束位置越界的情况
  if [[ "${l_endRowNum}" -le 0 || "${l_endRowNum}" -gt "${l_array_length}" ]]; then
    ((l_endRowNum = l_array_length))
  fi

  ((l_end = l_endRowNum - 1))
  l_content=$(printf "%s\n" "${l_content_array[@]:l_start:l_end - l_start + 1}")

  gDefaultRetVal="${l_content}"
}

function profileFunction() {
  local func_name=$1
  local log_file="/tmp/yaml_helper.log"
  shift  # 处理剩余参数
  # 创建日志目录
  mkdir -p "$(dirname "${log_file}")"
  if [ ! -f "${log_file}" ];then
    echo "222" > "${log_file}"
  fi
  # 生成带跟踪的函数
  eval "function _traced_${func_name}() {
      local start=\$(date +%s%3N)
      command ${func_name} \"\$@\"  # 正确传递所有参数
      local end=\$(date +%s%3N)
      echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] ${func_name} \$((end-start))ms args:\$*\" >> \"${log_file}\"
  }"
  # 使用别名覆盖原函数
  alias ${func_name}="_traced_$
  }{func_name}"
}
# 用法：profileFunction __readOrWriteYamlFile

#-------------------------------------主流程-------------------------------------------#

#加载必须的库文件
# shellcheck disable=SC2164

export _selfRootDir

if [ ! "${_selfRootDir}" ];then
  # shellcheck disable=SC2164
  _selfRootDir=$(cd "$(dirname "$0")"; pwd)
fi
source "${_selfRootDir}/helper/log-helper.sh"

#定义log-helper文件需要的调试模式指示变量
export gDebugMode
if [ ! "${gDebugMode}" ];then
  gDebugMode="true"
fi

#是否启用内部缓存机制。
export gEnableCache
if [ ! "${gEnableCache}" ];then
  gEnableCache="true"
fi

#本文件中所有函数默认的返回变量。
export gDefaultRetVal

#是否立即将内存缓存中的文件内容变更回写到文件中。
export gSaveBackImmediately
if [ ! "${gSaveBackImmediately}" ];then
  gSaveBackImmediately="true"
fi

#${文件绝对路径}=>文件路径，用于缓存读取过的文件。
declare -A gFileContentMap

#${文件}_${参数路径}=>读取参数映射Map，用于缓存读取过的参数。
declare -A gFileDataBlockMap

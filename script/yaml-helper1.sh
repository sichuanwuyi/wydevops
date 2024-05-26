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

  l_arrayLen=$(eval "echo \${#${l_arrayName}[@]}")
  if [ "${l_arrayLen}" -ge 1 ];then
    ((l_arrayLen = l_arrayLen - 1))
    #删除最后一行的换行符
    l_line=$(eval "echo \"\${${l_arrayName}[${l_arrayLen}]}\"")
    l_line=$(echo "${l_line}" | tr -d '\n')
    l_line="${l_line//\$/\\\$}"
    l_line="${l_line//\"/\\\"}"
    eval "${l_arrayName}[${l_arrayLen}]=\"${l_line}\""
  fi

  unset l_content
  unset l_arrayName
  unset l_replaceStr

  unset l_arrayLen
  unset l_line
  unset l_ifs
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
  local l_cacheSize
  local l_cachedParamKey
  local _cachedParams
  local _rowRangeStart
  local _rowRangeEnd
  #本次操作新增的参数路径数量。
  local _addParamPathCount
  local l_paramArray

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
      l_tmpParamPath="${l_paramPath%.*}"
      while [ "${l_tmpParamPath}" ]; do
        echo "------continue-----${l_tmpParamPath}-----------"
        #获取l_cachedParamKey参数。
        l_cachedParamKey="${l_yamlFile##*/}|${l_tmpParamPath}"
        l_cachedParamKey="${l_cachedParamKey//\[/\\\[}"
        l_cachedParamKey="${l_cachedParamKey//\]/\\\]}"
        #读取可能存在的缓存参数。
        _cachedParams="${gFileDataBlockMap[${l_cachedParamKey}]}"
        if [ "${_cachedParams}" ];then
          echo "----${l_cachedParamKey} => ${_cachedParams}-----"
          break
        fi
        #向左回退参数路径，继续查找可能存在的缓存数据。
        if [[ "${l_tmpParamPath}" =~ ^(.*)\.(.*)$ ]];then
          l_tmpParamPath="${l_tmpParamPath%.*}"
        else
          l_tmpParamPath=""
        fi
      done

      if [ "${_cachedParams}" ];then
        #debug "载入缓存中匹配的参数:${l_cachedParamKey}=>${_cachedParams}"
        l_tmpParamPath="${l_paramPath:${#l_tmpParamPath}}"
        l_tmpParamPath="${l_tmpParamPath:1}"
        # shellcheck disable=SC2206
        l_paramArray=(${_cachedParams//,/ })
        #解析缓存的读取参数。
        l_params[2]="${l_tmpParamPath}"
        [[ "${l_paramsLen}" -lt 4 ]] && l_params[3]=""
        l_params[4]="${l_paramArray[0]}"
        l_params[5]="${l_paramArray[1]}"
        [[ "${l_paramsLen}" -lt 7 ]] && l_params[6]=""
        l_params[7]="${l_paramArray[2]}"
        l_params[8]="${l_paramArray[3]}"
        _cachedParams=""
      fi
    fi

    _rowRangeStart=""
    _rowRangeEnd=""
    # shellcheck disable=SC2145
    __readOrWriteYamlFile "${l_params[@]}"

    #初始化l_cachedParamKey参数。
    l_cachedParamKey="${l_yamlFile##*/}|${l_paramPath%.*}"
    l_cachedParamKey="${l_cachedParamKey//\[/\\\[}"
    l_cachedParamKey="${l_cachedParamKey//\]/\\\]}"
    #根据操作模式的不同，对缓存的参数进行更新或调整。
    case ${l_mode} in
       "read"|"rowRange")
         #读取模式下：刷新缓存数据。
         if [ "${gDefaultRetVal}" != "null" ];then
           if [ "${_rowRangeEnd}" -gt "${_rowRangeStart}" ];then
             #提前生成缓存数据
             _createCacheForParamPath "${l_yamlFile}" "${l_paramPath}" "${_rowRangeStart}" "${_rowRangeEnd}"
           fi
           gFileDataBlockMap["${l_cachedParamKey}"]="${_cachedParams}"
           #debug "读取模式下,更新父级参数路径缓存:${l_cachedParamKey}=>${_cachedParams}"
         else
           unset gFileDataBlockMap["${l_cachedParamKey}"]
           #debug "读取参数失败,清除父级参数路径缓存:${l_cachedParamKey}"
         fi
         ;;
       "update"|"insert")
         if [[ "${gDefaultRetVal}" =~ ^(\-1) ]];then
           unset gFileDataBlockMap["${l_cachedParamKey}"]
           #debug "行范围读取失败,清除父级参数路径缓存:${l_cachedParamKey}"
         else
           #更新模式下：对缓存数据进行更新调整
           _adjustCachedParamsAfterUpdate "${l_yamlFile}" "${l_paramPath}" "${gDefaultRetVal}"
           #更新父级缓存数据:首次添加时，起始行要加1
           if [[ ! "${gFileDataBlockMap[${l_cachedParamKey}]}" && ! ${l_paramPath%.*} =~ ^(.*)\.(.*)$ ]];then
             # shellcheck disable=SC2206
             l_paramArray=(${_cachedParams//,/ })
             ((l_paramArray[0] = l_paramArray[0] + 1))
             # shellcheck disable=SC2124
             _cachedParams="${l_paramArray[@]}"
             _cachedParams="${_cachedParams// /,}"
           fi
           gFileDataBlockMap["${l_cachedParamKey}"]="${_cachedParams}"
         fi
         ;;
       "delete")
         if [[ ! "${gDefaultRetVal}" =~ ^(\-1) ]];then
           #删除模式下：对缓存数据进行删除调整
           _adjustCachedParamsAfterDelete "${l_yamlFile}" "${l_paramPath}" "${gDefaultRetVal}"
           l_cachedParamKey="${l_yamlFile##*/}|${l_paramPath}"
           l_cachedParamKey="${l_cachedParamKey//\[/\\\[}"
           l_cachedParamKey="${l_cachedParamKey//\]/\\\]}"
           unset gFileDataBlockMap["${l_cachedParamKey}"]
         fi
         ;;
     esac
  else
    # shellcheck disable=SC2145
    __readOrWriteYamlFile "${@}"
  fi

  unset l_params
  unset l_paramsLen
  unset l_mode
  unset l_yamlFile

  unset l_paramPath
  unset l_tmpParamPath
  unset l_cacheSize
  unset l_cachedParamKey
  unset _cachedParams
  unset _addParamPathCount
  unset l_paramArray
}

function __readOrWriteYamlFile() {
  export gDefaultRetVal
  export gDataBlockStartNum
  export gDataBlockEndNum
  export gLastArrayIndex
  export gIsBlockRow
  #引入父级方法定义的非全局变量
  export _cachedParams
  #引入父级方法定义的非全局变量
  export _addParamPathCount
  #读模式下返回数据的起始行
  export _rowRangeStart
  #读取模式下返回数据的截止行
  export _rowRangeEnd


  local l_paramPath=$3

  if [ ! "${l_paramPath}" ];then
    gDefaultRetVal="-1"
    unset l_paramPath
    return
  fi

  #模式：read、rowRange、update、insert、delete
  local l_mode=$1
  local l_yamlFile=$2
  local l_paramValue=$4
  local l_initStartRowNum=$5
  local l_initEndRowNum=$6
  #l_mode=read时，返回数据是否保持原始格式。
  local l_keepOriginalFormat=$7
  #以下两个参数是递归调用时使用的参数
  #前次调用时的参数数组项序号。
  local l_lastArrayIndex=$8
  #当l_initStartRowNum=l_initEndRowNum时，用来指明该行是前一个参数所在行或是前一参数的下层数据块行。
  local l_isBlockRow=$9

  local l_pathArray
  local l_paramName
  local l_stdParamName
  local l_arrayIndex

  local l_rowNumAndSpaceNum
  local l_startRowNum
  local l_isInsertParam
  local l_retValue
  local l_initSpaceNum
  local l_tmpSpaceNum
  local l_tmpSpaceNum1
  local l_regexStr
  local l_rowNum
  local l_endRowNum

  local l_content
  local l_isSampleValue
  local l_itemCount

  if [ ! "${l_keepOriginalFormat}" ];then
    l_keepOriginalFormat="false"
  fi

  if [ ! "${l_lastArrayIndex}" ];then
    l_lastArrayIndex="-1"
  fi

  #将l_paramPath参数转成数组。
  # shellcheck disable=SC2206
  l_pathArray=(${l_paramPath//./ })
  #获得第一个参数路径的名称。
  l_paramName="${l_pathArray[0]}"
  #获取“[”字符前面部分的参数
  l_stdParamName="${l_paramName%%[*}"
  #获取参数路径的数组下标值。
  if [[ "${l_paramName}" =~ ^(.*)\[(.*)$ ]];then
    #获取存在的数组下标值。
    l_arrayIndex="${l_paramName#*[}"
    l_arrayIndex="${l_arrayIndex%]*}"
  else
    l_arrayIndex=-1
  fi

  if [ ! -f "${l_yamlFile}" ];then
    if [ "${l_mode}" == "insert" ];then
      info "插入模式: 目标文件不存在则创建目标文件"
      echo "${l_stdParamName}: " > "${l_yamlFile}"
    else
      error "目标文件不存在"
    fi
  fi

  if [[ ! "${l_initStartRowNum}" || "${l_initStartRowNum}" -eq 1 ]];then
    #重新初始化l_startRowNum的值：获取文件第一个有效行的行号（跳过文件头部的注释行）
    l_content=$(awk "NR==1, NR==-1" "${l_yamlFile}" | grep -m 1 -noP "^([ ]*)[a-zA-Z_]+")
    l_initStartRowNum="${l_content%%:*}"
  fi

  if [ ! "${l_initEndRowNum}" ];then
    #此处不能直接设置为文件末尾行号，因为后续代码会根据这个参数判断是否是首次调用。
    ((l_initEndRowNum = -1))
  fi

  l_regexStr=""
  #获取第一行有效行的前导空格数量,确定后续目标参数的查询正则表达式中的前导空格匹配部分。
  l_content=$(awk "NR==${l_initStartRowNum}, NR==${l_initEndRowNum}" "${l_yamlFile}" | grep -m 1 -oP "^[ ]*[a-zA-Z_\-]+")
  if [ "${l_content}" ];then
    #获取有效的前导空格数量。
    _getPrefixSpaceNum "${l_content}"
    l_tmpSpaceNum="${gDefaultRetVal}"
    if [ "${l_initStartRowNum}" -ge "${l_initEndRowNum}" ];then
      #起止行号相同的情况下，下层数据块起始行的前导空格数还要在l_tmpSpaceNum1的基础上加2.
      ((l_tmpSpaceNum1 = l_tmpSpaceNum + 2))
    fi
    if [[ "${l_content}" =~ ^([ ]*)(\-) ]];then
      #数组项的情况，目标参数前导空格数还要加2
      ((l_tmpSpaceNum1 = l_tmpSpaceNum + 2))
      l_regexStr="^(([ ]{${l_tmpSpaceNum}}- ${l_stdParamName})|([ ]{${l_tmpSpaceNum1}}${l_stdParamName}))"
    else
      l_regexStr="^([ ]{${l_tmpSpaceNum}}${l_stdParamName})"
    fi
  else
    l_regexStr="^[ ]*${l_stdParamName}"
  fi

  #构造缓存串。
  _cachedParams="${l_initStartRowNum},${l_initEndRowNum},${l_lastArrayIndex},${l_isBlockRow}"

  #获取文件中指定范围内层级最浅的
  # 第一个符合条件的l_stdParamName参数所在行号和前导空格数量
  # shellcheck disable=SC2034
  # shellcheck disable=SC2207
  _getRowNumAndPrefixSpaceNum "${l_yamlFile}" "${l_regexStr}:" "${l_initStartRowNum}" "${l_initEndRowNum}"
  # shellcheck disable=SC2206
  l_rowNumAndSpaceNum=(${gDefaultRetVal})
  l_startRowNum="${l_rowNumAndSpaceNum[0]}"
  l_initSpaceNum="${l_rowNumAndSpaceNum[1]}"

  l_isInsertParam="false"
  if [ "${l_startRowNum}" -lt 0 ];then
    #如果参数路径仍包含点分符且不是插入模式，则返回异常结果。
    case ${l_mode} in
      "read")
        #读取模式下返回null表示读取失败。
        l_retValue="null"
        ;;
      "update")
        #更新模式下返回-1表示更新失败。
        #返回格式：更新的起始行号、截至行号、数组或列表的总项数、更新的新内容所占的行数、本次操作过程中删除的总行数。
        l_retValue="-1 -1 -1 0 0"
        ;;
      "delete")
        #删除成功，则返回：${删除的起始行号(含)} ${删除的截至行号(含)} ${实际删除的行数}
        #删除成功，则返回: -1 -1 0
        l_retValue="-1 -1 0"
        ;;
      "rowRange")
        #行范围读取模式下返回-1，表示读参数行范围失败。
        #返回格式：起始行号、截至行号
        l_retValue="-1 -1"
        ;;
      "insert")
        echo "--1--${l_stdParamName}----${l_initStartRowNum}------${l_initEndRowNum}---------"
        #插入模式下：自动创建缺失的参数路径。
        _insertParamDirectly "${l_yamlFile}" "${l_stdParamName}" "${l_initStartRowNum}" "${l_initEndRowNum}" \
          "${l_lastArrayIndex}" "${l_isBlockRow}"
        # shellcheck disable=SC2206
        l_rowNumAndSpaceNum=(${gDefaultRetVal})
        #设置定位目标参数行的位置和前导空格数量。
        l_startRowNum="${l_rowNumAndSpaceNum[0]}"
        l_initSpaceNum="${l_rowNumAndSpaceNum[1]}"
        #设置初始化结束行等于目标参数行
        ((l_initEndRowNum = l_startRowNum))
        l_isInsertParam="true"
        ((_addParamPathCount = _addParamPathCount + 1))
        echo "--2--${l_stdParamName}----${l_startRowNum}------${l_initEndRowNum}---------"
        ;;
    esac
  fi

  if [ ! "${l_retValue}" ];then
    if [[ "${l_isInsertParam}" == "false" || "${l_arrayIndex}" -ge 0 ]];then
      #获取参数数据块的起止行号（内部实现了缺失数组项或列表项的插入逻辑）
      # shellcheck disable=SC2207
      _getDataBlockRowNum "${l_mode}" "${l_yamlFile}" "${l_startRowNum}" "${l_initEndRowNum}" "${l_arrayIndex}" "${l_initSpaceNum}"
      # shellcheck disable=SC2206
      l_rowNumAndSpaceNum=(${gDefaultRetVal})
      #得到数据块的起始行和截至行
      l_rowNum="${l_rowNumAndSpaceNum[0]}"
      l_endRowNum="${l_rowNumAndSpaceNum[1]}"

      [[ "${l_arrayIndex}" -ge 0 ]] && l_itemCount="${l_rowNumAndSpaceNum[2]}"

      l_isSampleValue="false"
      [[ "${#l_rowNumAndSpaceNum[@]}" -ge 4 ]] && l_isSampleValue="${l_rowNumAndSpaceNum[3]}"

      l_isBlockRow="true"
      [[ "${l_startRowNum}" -eq "${l_rowNum}" ]] && l_isBlockRow="false"

      #根据l_mode参数的值进行后续处理。
      case ${l_mode} in
        "read")
          #如果参数数据块不存在,则读取模式下返回null，表示读取失败。
          [[ "${l_rowNum}" -eq -1 ]] && l_retValue="null"
          ;;
        "update")
          #如果参数数据块不存在,则更新模式下返回-1，表示更新失败。
          #返回格式：更新的起始行号、截至行号、数组或列表的总项数、更新的新内容所占的行数、本次操作过程中删除的总行数。
          [[ "${l_rowNum}" -eq -1 ]] && l_retValue="-1 -1 -1 0 0"
          ;;
        "delete")
          #删除成功，则返回：${删除的起始行号(含)} ${删除的截至行号(含)} ${实际删除的行数}
          #删除成功，则返回: -1 -1 0
          [[ "${l_rowNum}" -eq -1 ]] && l_retValue="-1 -1 0"
          ;;
        "rowRange")
          if [[ "${l_paramPath}" =~ ^(.*)\.(.*)$ || "${l_paramPath}" =~ ^(.*)\[[0-9]+\]([ ]*)$ ]];then
            #如果参数数据块不存在且后面还有参数路径或数组项，则行范围读取模式下返回-1，表示读参数行范围失败。
            #返回格式：起始行号、截至行号
            [[ "${l_rowNum}" -eq -1 ]] && l_retValue="-1 -1"
          else
            #如果后面还有参数路径或数组项，则行范围读取模式下返回当前gDefaultRetVal的值。
            l_retValue="${gDefaultRetVal}"
          fi
          ;;
        "insert")
          ##如果参数数据块不存在且后面还有参数路径或数组项，插入模式下返回-1，表示参数插入失败。
          #返回格式：更新的起始行号、截至行号、数组或列表的总项数、本次操作增加或删除的总行数。
          [[ "${l_rowNum}" -eq -1 ]] && l_retValue="-1 -1 -1 0"
          ;;
      esac
    else
      #是新插入的参数，则直接设置数据块的起始行和截至行
      l_rowNum="${l_startRowNum}"
      l_endRowNum="${l_startRowNum}"
      l_isBlockRow="false"
    fi

    if [ ! "${l_retValue}" ];then
      if [[ "${l_paramPath}" =~ ^(.*)\.(.*)$ ]];then
        #删除第一个参数路径,继续处理下一个参数路径
        l_paramPath=${l_paramPath#*.}
        l_lastArrayIndex="${l_arrayIndex}"
        ((l_rowNum = l_rowNum + 1))
        __readOrWriteYamlFile "${l_mode}" "${l_yamlFile}" "${l_paramPath}" "${l_paramValue}" \
          "${l_rowNum}" "${l_endRowNum}" "${l_keepOriginalFormat}" "${l_lastArrayIndex}" "${l_isBlockRow}"
        l_retValue="${gDefaultRetVal}"
      else
        #根据l_mode参数的值进行后续处理。
        case ${l_mode} in
          "read")
            _rowRangeStart="${l_rowNum}"
            _rowRangeEnd="${l_endRowNum}"
            #读取l_rowNum行与l_endRowNum行间的内容。
            _readDataBlock "${l_yamlFile}" "${l_rowNum}" "${l_endRowNum}" "${l_arrayIndex}"
            l_content="${gDefaultRetVal}"
            #获取并调整读取的数据块内容，并返回之。
            _getReadContent "${l_stdParamName}" "${l_content}" "${l_isSampleValue}" "${l_arrayIndex}" \
              "${l_startRowNum}" "${l_keepOriginalFormat}"
            l_retValue="${gDefaultRetVal}"
            ;;
          "update")
            _updateParam "${l_yamlFile}" "${l_startRowNum}" "${l_rowNum}" "${l_endRowNum}" "${l_arrayIndex}" \
              "${l_paramValue}" "${l_itemCount}"
            l_retValue="${gDefaultRetVal}"
            ;;
          "delete")
            if [[ "${l_arrayIndex}" -lt 0 ]];then
              #要删除的不是数组项，则要从参数名称所在行开始删除。
              ((l_rowNum = l_startRowNum))
            fi
            #删除指定参数
            _deleteParam "${l_yamlFile}" "${l_rowNum}" "${l_endRowNum}" "${l_arrayIndex}"
            l_retValue="${gDefaultRetVal}"
            ;;
          "rowRange")
            l_retValue="${l_rowNum}" "${l_endRowNum}"
            ;;
          "insert")
            #更新新插入参数的值。
            _updateParam "${l_yamlFile}" "${l_startRowNum}" "${l_rowNum}" "${l_endRowNum}" "${l_arrayIndex}" \
              "${l_paramValue}" "${l_itemCount}"
            l_retValue="${gDefaultRetVal}"
            ;;
        esac
      fi
    fi

  fi

  #将返回值赋值给gDefaultRetVal变量。
  gDefaultRetVal="${l_retValue}"

  unset l_mode
  unset l_yamlFile
  unset l_paramPath
  unset l_paramValue
  unset l_initStartRowNum
  unset l_initEndRowNum
  unset l_keepOriginalFormat
  unset l_lastArrayIndex
  unset l_isBlockRow

  unset l_pathArray
  unset l_paramName
  unset l_stdParamName
  unset l_arrayIndex

  unset l_rowNumAndSpaceNum
  unset l_startRowNum
  unset l_isInsertParam
  unset l_retValue
  unset l_initSpaceNum
  unset l_tmpSpaceNum
  unset l_tmpSpaceNum1
  unset l_regexStr
  unset l_rowNum
  unset l_endRowNum

  unset l_content
  unset l_isSampleValue
  unset l_itemCount
}

#不检查是否已经存在，直接插入指定的参数
function _insertParamDirectly(){
  export gDefaultRetVal

  #目标yaml文件
  local l_yamlFile=$1
  #要插入的参数名称
  local l_stdParamName=$2
  #插入范围的起始行行号
  local l_startRowNum=$3
  #插入范围的截至行行号
  local l_endRowNum=$4
  #上一次的数组项值。
  local l_lastArrayIndex=$5
  #当l_startRowNum=l_endRowNum时，表明l_startRowNum行是否是上一参数的下层数据。
  local l_isBlockRow=$6

  local l_tmpStartRowNum
  local l_tmpEndRowNum
  local l_tmpSpaceNum
  local l_tmpSpaceStr
  local l_content

  if [ ! "${l_endRowNum}" ];then
    ((l_endRowNum = -1))
  fi

  if [[ -s "${l_yamlFile}" ]];then

    if [[ "${l_endRowNum}" -eq -1 ]];then
      #l_endRowNum==-1说明第一个参数路径就就没有找到了
      #获取文件末尾行的行号。
      l_endRowNum=$(sed -n '$=' "${l_yamlFile}")
      #设置插入行位置（在其下一行插入）。
      ((l_tmpEndRowNum = l_endRowNum))
    fi

    #读取l_startRowNum行的内容。
    l_content=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
    #获取前导空格数
    l_tmpSpaceNum=$(echo -e "${l_content}" | grep -oP "^[ ]*" | grep -oP " " | wc -l )
    if [ "${l_tmpEndRowNum}" ];then
      #构造前导空格串
      l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum}s")
      #直接在l_tmpEndRowNum行的下一行插入兄弟行
      sed -i "${l_tmpEndRowNum}a \\${l_tmpSpaceStr}${l_stdParamName}: " "${l_yamlFile}"
      ((l_tmpEndRowNum = l_tmpEndRowNum + 1))
      #返回插入行行号和前导空格数量
      gDefaultRetVal="${l_tmpEndRowNum} ${l_tmpSpaceNum}"
    else
      gDefaultRetVal=""
      if [ "${l_startRowNum}" -ge "${l_endRowNum}" ];then
        if [[ "${l_content}" =~ ^([ ]*)(\-)([ ]*)$ ]];then
          #此种情况是：新创建了数组项且尚未定义任务数组项的属性参数。
          #构造前导空格串
          l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum}s")
          #这种情况下需要在l_startRowNum行上插入参数。
          sed -i "${l_startRowNum}c \\${l_tmpSpaceStr}- ${l_stdParamName}: " "${l_yamlFile}"
          #设置返回值。
          gDefaultRetVal="${l_startRowNum} ${l_tmpSpaceNum}"
        else
          #这种情况下需要在l_startRowNum或l_endRowNum行的下一行上插入参数(同级的):
          #默认情况下都是插入兄弟行，但是:
          if [[ "${l_lastArrayIndex}" -ge 0 ]];then
            #当缺失的参数是某个数组项的属性时, 在l_endRowNum行的下面插入兄弟行
            ((l_tmpEndRowNum = l_endRowNum))
            #如果前导字符串中包含“-”，则说明l_tmpSpaceNum当前未包含“- ”占据的空格数，因此前导空格数还要加2.
            [[ "${l_content}" =~ ^([ ]*)(\-) ]] && ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
          else
            #当缺失的参数不是某个数组项的属性时：
            #首先确定的是在l_startRowNum行的下一行插入数据。
            ((l_tmpEndRowNum = l_startRowNum))
            #接着，如果l_isBlockRow=false，则插入下层行，否则插入兄弟行。
            if [ "${l_isBlockRow}" == "false" ];then
              #插入下层行，前导空格数要加2
               ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
              #如果前导字符串中包含“-”，则说明l_tmpSpaceNum当前未包含“- ”占据的空格数，因此前导空格数还要加2.
              [[ "${l_content}" =~ ^([ ]*)(\-) ]] && ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
              #清除l_startRowNum行上的值域
              sed -i "${l_startRowNum}c \\${l_content%%:*}: " "${l_yamlFile}"
            fi
          fi
        fi
      else
        #将插入行位置设置为最后一行（在其下一行插入新行）。
        ((l_tmpEndRowNum = l_endRowNum))
        #如果前导字符串中包含“-”，则说明l_tmpSpaceNum当前未包含“- ”占据的空格数，因此前导空格数还要加2.
        [[ "${l_content}" =~ ^([ ]*)(\-) ]] && ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
      fi

      if [ ! "${gDefaultRetVal}" ];then
        #构造前导空格串
        l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum}s")
        #获取文件末尾行的行号。
        l_endRowNum=$(sed -n '$=' "${l_yamlFile}")
        if [ "${l_tmpEndRowNum}" -ge "${l_endRowNum}" ];then
          ((l_tmpEndRowNum = l_endRowNum))
        fi
        #在l_tmpEndRowNum的下一行插入缺失的参数
        sed -i "${l_tmpEndRowNum}a \\${l_tmpSpaceStr}${l_stdParamName}: " "${l_yamlFile}"
        ((l_tmpStartRowNum = l_tmpEndRowNum + 1))
        #设置返回值。
        gDefaultRetVal="${l_tmpStartRowNum} ${l_tmpSpaceNum}"
      fi

    fi
  else
    #如果文件内容为空，则直接插入变量即可。
    echo "${l_stdParamName}: " > "${l_yamlFile}"
    #返回插入行行号和前导空格数量
    gDefaultRetVal="1 0"
  fi

  unset l_yamlFile
  unset l_stdParamName
  unset l_startRowNum
  unset l_endRowNum
  unset l_lastArrayIndex
  unset l_isBlockRow

  unset l_tmpStartRowNum
  unset l_tmpEndRowNum
  unset l_tmpSpaceNum
  unset l_tmpSpaceStr
  unset l_content
}

function _deleteParam() {
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
  l_rowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
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
      sed -i "${l_startRowNum}c \\${l_newRowData}" "${l_yamlFile}"
      gDefaultRetVal="${l_startRowNum},${l_startRowNum},0"
    else
      #直接返回失败。
      gDefaultRetVal="-1 -1 0"
    fi
  else
    #在文件指定的起始行（包含）位置删除内容
    _deleteContentInFile "${@}"
  fi

  unset l_yamlFile
  unset l_startRowNum
  unset l_endRowNum
  unset l_arrayIndex

  unset l_rowData
  unset l_array
  unset l_arrayLen
  unset l_i
  unset l_newRowData
}

#使用新的内容替换yaml文件中指定的起始行和截至行的内容
function _updateParam() {
  export gDefaultRetVal

  local l_arrayIndex=$5
  local l_paramValue=$6

  local l_array

  #结合新值和旧值，判断修改的方式。
  if [ "${l_arrayIndex}" -lt 0 ];then
    #不是数组项或列表项
    _updateNotListOrArrayParam "${@}"
  else
    #是数组项或列表项
    _updateListOrArrayParam "${@}"
  fi

  if [[ "${_addParamPathCount}" && "${_addParamPathCount}" -gt 0 ]];then
    # shellcheck disable=SC2206
    l_array=(${gDefaultRetVal})
    ((l_array[3] = l_array[3] + _addParamPathCount ))
    # shellcheck disable=SC2124
    gDefaultRetVal="${l_array[@]}"
  fi

  unset l_arrayIndex
  unset l_array
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
    if [  "${l_blockStartRowNum}" -gt "${l_startRowNum}" ];then
      ((l_blockStartRowNum = l_startRowNum + 1))
      _deleteContentInFile "${l_yamlFile}" "${l_blockStartRowNum}" "${l_blockEndRowNum}" "${l_arrayIndex}"
      # shellcheck disable=SC2206
      l_array=(${gDefaultRetVal})
      ((l_deletedRowNum = l_array[2]))
    fi
    _updateSingleRowValue "${l_yamlFile}" "${l_startRowNum}" ""
    gDefaultRetVal="${gDefaultRetVal} ${l_deletedRowNum}"
  else
    #计算l_newContent的行数(会删除末尾的空行)。
    l_newLineCount=$(echo -e "${l_newContent}" | grep -oP "^([ ]*).*$" | wc -l )
    if [[ "${l_newLineCount}" -eq 1 ]];then
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
      gDefaultRetVal="${gDefaultRetVal} ${l_deletedRowNum}"
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
      gDefaultRetVal="${gDefaultRetVal} ${l_newLineCount} ${l_deletedRowNum}"
    fi
  fi

  unset l_yamlFile
  unset l_startRowNum
  unset l_blockStartRowNum
  unset l_blockEndRowNum
  unset l_arrayIndex
  unset l_newContent

  unset l_array
  unset l_deletedRowNum
}

#更新数组项或列表项参数
function _updateListOrArrayParam() {
  local l_yamlFile=$1
  #参数名称所在行
  local l_startRowNum=$2
  local l_arrayIndex=$5
  local l_newContent=$6

  local l_startRowData

  #先读取l_startRowNum行的数据，判断是列表还是数组？
  #如果l_startRowNum行能匹配^(.*)(:[ ]+)\[.*\]([ ]*)$，则说明是数组格式，否则清除l_startRowNum行的值域，并认定为列表格式。
  l_startRowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
  if [[ "${l_startRowData}" =~ ^(.*)(:[ ]+)\[.*\]([ ]*)$ ]];then
    _updateArrayParam "${l_yamlFile}" "${l_startRowNum}" "${l_startRowData}" "${l_arrayIndex}" "${l_newContent}"
  else
    #更新列表项
    _updateListParam "${@}"
  fi

  unset l_yamlFile
  unset l_startRowNum
  unset l_arrayIndex
  unset l_newContent

  unset l_startRowData
}

#更新文件中数组参数的指定项的值
function _updateArrayParam() {
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_startRowData=$3
  local l_arrayIndex=$4
  local l_newContent=$5

  local l_paramValue
  local l_arrayItems
  local l_itemCount
  local l_i

  #获取l_startRowNum行的值域
  l_paramValue="${l_startRowData#*:}"
  l_paramValue="${l_paramValue#*[}"
  l_paramValue="${l_paramValue%]*}"

  #将值域字符串转换为数组。
  # shellcheck disable=SC2206
  l_arrayItems=(${l_paramValue//,/ })
  l_itemCount="${#l_arrayItems[@]}"

  #循环读取数组项，并将l_arrayIndex项的值替换为新的值。
  l_paramValue=""
  for ((l_i = 0; l_i < l_itemCount; l_i++)){
    if [ "${l_i}" -eq "${l_arrayIndex}" ];then
      l_paramValue="${l_paramValue},${l_newContent}"
    else
      l_paramValue="${l_paramValue},${l_arrayItems[${l_i}]}"
    fi
  }

  #更新l_startRowNum行的数据
  sed -i "${l_startRowNum}c \\${l_startRowData%%:*}: [${l_paramValue:1}]" "${l_yamlFile}"

  #返回信息格式：起始行号 截至行号 数组项总数 新增行数 删除行数
  gDefaultRetVal="${l_startRowNum} ${l_startRowNum} ${l_itemCount} 0 0"

  unset l_yamlFile
  unset l_startRowNum
  unset l_startRowData
  unset l_arrayIndex
  unset l_newContent

  unset l_paramValue
  unset l_arrayItems
  unset l_itemCount
  unset l_i
}

#更新文件中指定的列表参数的指定项的值
function _updateListParam() {
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
  local l_tmpSpaceNum1
  local l_content
  local l_tmpSpaceStr

  local l_addRowNum
  local l_deletedRowNum

  #如果l_newContent的第一行是以“|”行开头的，则要删除第一行。
  l_content=$(echo -e "${l_newContent}" | grep -m 1 -oP "^[ ]*\|[+-]*[ ]*$")
  if [ "${l_content}" ];then
    l_tmpSpaceNum="${#l_content}"
    #加上行尾的换行符。
    ((l_tmpSpaceNum = l_tmpSpaceNum + 1))
    l_newContent="${l_newContent:${l_tmpSpaceNum}}"
  fi

  #计算新内容的前导空格数量
  _getPrefixSpaceNum "${l_newContent}"
  l_tmpSpaceNum="${gDefaultRetVal}"

  #计算目标列表项的前导空格数量。
  l_content=$(sed -n "${l_blockStartRowNum}p" "${l_yamlFile}")
  _getPrefixSpaceNum "${l_content}"
  l_tmpSpaceNum1="${gDefaultRetVal}"
  if [[ ! "${l_newContent}" =~ ^([ ]*)(- ) ]];then
    ((l_tmpSpaceNum1 = l_tmpSpaceNum1 + 2))
  fi

  #计算前导空格差。
  ((l_tmpSpaceNum = l_tmpSpaceNum1 - l_tmpSpaceNum))
  #调整新内容的缩进格式。
  _indentContent "${l_newContent}" "${l_tmpSpaceNum}"
  l_newContent="${gDefaultRetVal}"
  #如果新内容不是以“-”开头的，则为新内容添加“-”前缀。
  if [[ ! "${l_newContent}" =~ ^([ ]*)(- ) ]];then
    l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum1}s")
    l_newContent="${l_tmpSpaceStr:2}- ${l_newContent:${l_tmpSpaceNum1}}"
  fi

  #将l_newContent转换为单行字符串。
  _convertToSingleRow "${l_newContent}"
  l_content="${gDefaultRetVal}"

  #直接将l_content输出到l_blockStartRowNum行上（会自动换行）
  sed -i "${l_blockStartRowNum},${l_blockEndRowNum}c \\${l_content}" "${l_yamlFile}"

  if [ "${l_blockEndRowNum}" -gt "${l_blockStartRowNum}" ];then
    #计算删除的行数。
    ((l_deletedRowNum = l_blockEndRowNum - l_blockStartRowNum + 1))
  else
    ((l_deletedRowNum = 0))
  fi

  #获取新内容的行数。
  l_addRowNum=$(echo -e "${l_content}" | grep -oP "^([ ]*).*$" | wc -l )
  ((l_blockEndRowNum = l_blockStartRowNum + l_addRowNum - 1))

  #返回结果
  gDefaultRetVal="${l_blockStartRowNum} ${l_blockEndRowNum} ${l_itemCount} ${l_addRowNum} ${l_deletedRowNum}"

  unset l_yamlFile
  unset l_startRowNum
  unset l_blockStartRowNum
  unset l_blockEndRowNum
  unset l_arrayIndex
  unset l_newContent
  unset l_itemCount

  unset l_tmpSpaceNum
  unset l_tmpSpaceNum1
  unset l_content
  unset l_tmpSpaceStr

  unset l_addRowNum
  unset l_deletedRowNum
}

#缩进内容块, l_indent为负数向左移动，为正数向右移动
function _indentContent(){
  export gDefaultRetVal

  local l_content=$1
  local l_indent=$2

  local l_tmpSpaceStr
  local l_len

  l_len="${l_indent}"
  [[ "${l_len}" -lt 0 ]] && ((l_len = 0 - l_len))
  l_tmpSpaceStr=$(printf "%${l_len}s")

  if [ "${l_indent}" -gt 0 ];then
    gDefaultRetVal=$(echo -e "${l_content}" | sed "s/^/${l_tmpSpaceStr}/")
  elif [ "${l_indent}" -lt 0 ];then
    gDefaultRetVal=$(echo -e "${l_content}" | sed "s/^${l_tmpSpaceStr}//")
  fi

  unset l_content
  unset l_indent

  unset l_tmpSpaceStr
  unset l_len
}

#获取给定参数的前导空格数量。
#注意：l_content中的注释行也必須保持正确的缩进格式。
function _getPrefixSpaceNum() {
  local l_content=$1
  #如果第一行是前导竖杠，是否忽略该行而取下一有效行的前导空格。
  local l_ignoreVerticalBarRow=$2

  local l_firstLine
  local l_arrayLen
  local l_i
  local l_retValue

  export gDefaultRetVal

  if [ ! "${l_ignoreVerticalBarRow}" ];then
    l_ignoreVerticalBarRow="false"
  fi

  if [ "${l_ignoreVerticalBarRow}" == "true" ];then
    #如果第一行是空格和“|”开头的，则删除第一行。
    if [[ "${l_content}" =~ ^([ ]*)\| ]];then
      l_content=$(echo -e "${l_content}" | sed "1d")
    fi
  fi

  l_firstLine=$(echo -e "${l_content}" | grep -oP "^([ ]*)([a-zA-Z_\-]+).*$" | head -n 1)
  gDefaultRetVal=$(echo -e "${l_firstLine}" | grep -oP "^[ ]*" | grep -oP " " | wc -l)

  unset l_content
  unset l_ignoreVerticalBarRow

  unset l_lines
  unset l_arrayLen
  unset l_i
  unset l_retValue
}

#查找文件中符合条件的有效行，读取并返回第一行(l_order=positive)或最后一行(l_order=reverse)的行号和前导空格数量。
#如果未指定l_order参数，则读取并返回文件中从l_startRowNum行到l_endRowNum行间符合条件的且前导空格最少的行的行号和前导空格数量
function _getRowNumAndPrefixSpaceNum(){
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

  export gDefaultRetVal

  if [ ! "${l_startRowNum}" ];then
    ((l_startRowNum = 1))
  fi

  if [ ! "${l_endRowNum}" ];then
    ((l_endRowNum = -1))
  fi

  if [[ "${l_order}" && "${l_order}" == "positive" ]];then
    #从l_yamlFile文件的第l_startRowNum行开始直至l_endRowNum行，查找所有符合正则表达式的行（以行号开头）, 并返回第一行内容。
    l_content=$(awk "NR==${l_startRowNum}, NR==${l_endRowNum}" "${l_yamlFile}" | grep -m 1 -noP "${l_regexStr}")
  elif [[ "${l_order}" && "${l_order}" == "reverse" ]];then
    #从l_yamlFile文件的第l_startRowNum行开始直至l_endRowNum行，查找所有符合正则表达式的行（以行号开头）, 并返回最后一行内容。
    l_content=$(awk "NR==${l_startRowNum}, NR==${l_endRowNum}" "${l_yamlFile}" | grep -noP "${l_regexStr}" | tail -n 1)
  else
    #从l_yamlFile文件的第l_startRowNum行开始直至l_endRowNum行，查找并返回所有符合正则表达式的行（以行号开头）。
    l_content=$(awk "NR==${l_startRowNum}, NR==${l_endRowNum}" "${l_yamlFile}" | grep -noP "${l_regexStr}")
  fi

  if [ ! "${l_content}" ];then
    ((l_rowNum = -1))
    ((l_spaceNum = -1))
  else
    if [[ "${l_order}" && ("${l_order}" == "positive" || "${l_order}" == "reverse") ]];then
      #读取开头的行号
      l_rowNum="${l_content%%:*}"
    else
      #读取l_content中前导空格最少的行的行号。
      _getRowNum "${l_content}"
      l_rowNum="${gDefaultRetVal}"
    fi

    #相对行号转绝对行号
    ((l_rowNum = l_rowNum + l_startRowNum -1))
    #读取目标行的内容
    l_rowData=$(sed -n "${l_rowNum}p" "${l_yamlFile}")
    #获取行内容的前导空格数量，并赋值给l_initSpaceNum
    l_spaceNum=$(echo -e "${l_rowData}" | grep -o "^[ ]*" | grep -o " " | wc -l)
  fi

  #返回结果
  gDefaultRetVal="${l_rowNum} ${l_spaceNum}"

  unset l_yamlFile
  unset l_regexStr
  unset l_startRowNum
  unset l_endRowNum
  unset l_order

  unset l_content
  unset l_rowNum
  unset l_rowData
  unset l_spaceNum
}

#从过滤出的信息中读取指定索引的行的行号；
#如果未指定索引，则读取前导空格最少的行的行号。
#如果索引为负数，则读取最后一行的行号。
function _getRowNum() {
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

  export gDefaultRetVal

  #获取l_content的行数。
  l_lineCount=$(echo -e "${l_content}" | grep -oP "^[\d]+" | wc -l)

  #如果没有设置索引，则取前导空格最少的行的行号。
  if  [ ! "${l_rowNum}" ]; then
    ((l_spaceNum = -1))
    for (( l_i = 1; l_i <= l_lineCount; l_i++ )); do
      l_line=$(echo "${l_content}" | sed -n "${l_i}p")
      #获取前导空格数量
      l_tmpSpaceNum=$(echo -e "${l_line#*:}" | grep -o "^[ ]*" | grep -o " " | wc -l)
      if [ "${l_spaceNum}" -eq -1 ] || [ "${l_spaceNum}" -gt "${l_tmpSpaceNum}" ];then
        l_spaceNum="${l_tmpSpaceNum}"
        #得到第一个”:“前面的行号。
        l_tmpRowNum=${l_line%%:*}
      fi
    done
  elif [ "${l_rowNum}" -gt "${l_lineCount}" ];then
    l_tmpRowNum="-1"
  else
    #如果是读取最后一行，则:
    if [ "${l_rowNum}" -le 0 ];then
      ((l_i = l_lineCount))
    else
      ((l_i = l_rowNum))
    fi

    l_line=$(echo "${l_content}" | sed -n "${l_i}p")
    l_tmpRowNum=${l_line%%:*}
  fi

  #返回结果
  gDefaultRetVal="${l_tmpRowNum}"

  unset l_content
  unset l_rowNum

  unset l_lineCount
  unset l_line
  unset l_i
  unset l_spaceNum
  unset l_tmpSpaceNum
  unset l_tmpRowNum
}

#删除指定参数的内容。
function _deleteContentInFile(){
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_endRowNum=$3
  local l_arrayIndex=$4

  local l_LineCount

  if [[ "${l_startRowNum}" -ge 1 && "${l_endRowNum}" -ge 1 ]];then
    #如果删除的是单行，且不是数组项，且是以空格和/或”-“开头，且下一行前导空格等于l_startRowNum行前导空格数加2，
    #则要为下一行添加列表项前导标识”-“。
    #此操作主要处理：删除的参数是数组项的第一项，这会导致丢失数组项前缀符“-”，为此需要评估并为l_startRowNum行的下一行添加数组项前缀。
    if [[ "${l_startRowNum}" -eq "${l_endRowNum}" && "${l_arrayIndex}" -lt 0 ]];then
      _checkAndAddListItemPrefix "${@}"
    fi
    #删除从l_startRowNum行（含）到l_endRowNum行（含）的内容。
    sed -i "${l_startRowNum},${l_endRowNum}d" "${l_yamlFile}"
    ((l_LineCount = l_endRowNum - l_startRowNum + 1))
    gDefaultRetVal="${l_startRowNum} ${l_endRowNum} ${l_LineCount}"
  elif [[ "${l_startRowNum}" -ge 1 && "${l_endRowNum}" -le 0 ]];then
    ((l_startRowNum = l_startRowNum > 1 ? l_startRowNum - 1 : l_startRowNum))
    #获取文件总行数。
    l_endRowNum=$(wc -l < "${l_yamlFile}")
    #删除从l_startRowNum行（含）到文件末尾的内容。
    sed -i "${l_startRowNum},\$d" "${l_yamlFile}"
    ((l_LineCount = l_endRowNum - l_startRowNum + 1))
    gDefaultRetVal="${l_startRowNum} ${l_endRowNum} ${l_LineCount}"
  elif [[ "${l_startRowNum}" -le 0 && "${l_endRowNum}" -ge 1 ]];then
    #删除从第1行（含）到第l_endRowNum行(含)的内容。
    sed -i "1,${l_endRowNum}d" "${l_yamlFile}"
    gDefaultRetVal="1 ${l_endRowNum} ${l_endRowNum}"
  else
    #获取文件总行数。
    l_LineCount=$(wc -l < "${l_yamlFile}")
    #清空文件内容。
    sed -i "1,\$d" "${l_yamlFile}"
    gDefaultRetVal="1 ${l_LineCount} ${l_LineCount}"
  fi

  unset l_yamlFile
  unset l_startRowNum
  unset l_endRowNum
  unset l_arrayIndex

  unset l_LineCount
}

#在文件指定的起始行（包含）位置插入新的内容
#返回插入的新内容占据的最后一行的行号。
function _insertContentInFile(){
  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_endRowNum=$3
  local l_content=$4
  local l_updateValue=$5

  local l_lines
  local l_line
  local l_arrayLen
  local l_i
  local l_rowData
  local l_fileMaxRows

  export gDefaultRetVal

  if [ ! "${l_updateValue}" ];then
    l_updateValue="false"
  fi

  if [ ! "${l_isDelete}" ];then
    l_isDelete="false"
  fi

  # 将字符串按行拆分到数组中
  stringToArray "${l_content}" "l_lines"
  #得到数组长度。
  l_arrayLen=${#l_lines[@]}

  l_rowData=""
  # shellcheck disable=SC2068
  for ((l_i = 0; l_i < l_arrayLen; l_i ++))
  do
    l_line="${l_lines[${l_i}]}"
    if [ ! "${l_rowData}" ];then
      l_rowData="${l_line}"
    else
      l_rowData="${l_rowData}\n${l_line}"
    fi
  done

  l_fileMaxRows=$(sed -n '$=' "${l_yamlFile}")

  if [ "${l_startRowNum}" -gt "${l_fileMaxRows}" ];then
    #将内容追加到文件末尾。
    echo -e "\n${l_rowData}" >> "${l_yamlFile}"
    l_endRowNum=$(sed -n '$=' "${l_yamlFile}")
  elif [[ "${l_startRowNum}" -ge 1 && "${l_endRowNum}" -ge 1 ]];then
    #将l_startRowNum行（含）到l_endRowNum行（含）的内容替换为l_rowData。
    sed -i "${l_startRowNum},${l_endRowNum}c \\${l_rowData}" "${l_yamlFile}"
    ((l_endRowNum = l_startRowNum + l_arrayLen + (l_arrayLen > 0 ? -1 : 0 ) ))
  elif [[ "${l_startRowNum}" -ge 1 && "${l_endRowNum}" -le 0 ]];then
    #将从l_startRowNum行（含）到文件末尾的内容替换为l_rowData。
    sed -i "${l_startRowNum},\$c \\${l_rowData}" "${l_yamlFile}"
    ((l_endRowNum = l_startRowNum + l_arrayLen + (l_arrayLen > 0 ? -1 : 0 ) ))
  elif [[ "${l_startRowNum}" -le 0 && "${l_endRowNum}" -ge 1 ]];then
    #将第1行（含）到第l_endRowNum行(含)的内容替换为l_rowData。
    sed -i "1,${l_endRowNum}c \\${l_rowData}" "${l_yamlFile}"
    ((l_endRowNum= l_arrayLen > 0 ? l_arrayLen : 1))
  else
    #将整个文件内容替换为l_rowData。
    echo -e "${l_rowData}" > "${l_yamlFile}"
    l_endRowNum=$(sed -n '$=' "${l_yamlFile}")
  fi

  #返回结果:插入的结束行行号
  gDefaultRetVal="${l_endRowNum}"

  unset l_yamlFile
  unset l_startRowNum
  unset l_endRowNum
  unset l_content
  unset l_updateValue

  local l_lines
  local l_line
  local l_arrayLen
  local l_i
  local l_rowData
  local l_fileMaxRows

}

#获取指定行开始的数据块的起止行号。
function _getDataBlockRowNum() {
  export gDefaultRetVal

  local l_mode=$1
  local l_yamlFile=$2
  local l_startRowNum=$3
  local l_initEndRowNum=$4
  local l_arrayIndex=$5
  #l_startRowNum行的前导空格数。
  local l_initSpaceNum=$6

  local l_content
  local l_value
  local l_arrayLen

  if [ ! "${l_arrayIndex}" ];then
    (( l_arrayIndex = -1 ))
  fi

  #读取参数所在行的内容。
  l_content=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
  #获取第一个冒号后的内容。
  l_value="${l_content#*:}"
  # 去掉末尾的空格
  l_value="${l_value%% }"
  # 去掉头部的空格
  l_value="${l_value## }"

  if [ "${l_arrayIndex}" -lt 0 ];then
    if [[ "${l_value}"  && ! "${l_value}" =~ ^([ ]*)#(.*)$ ]] && [[ ! "${l_value}" =~ ^([ ]*)\|[+-]*([ ]*)$ ]] ;then
      #如果内容不为空,且不是以#号开头的注释内容,也不是“|”开头的块内容,
      #则将起止行号都设置为l_startRowNum，表明数据块就在参数所在行。
      #返回值中的-1,是数组长度占位符。
      #返回值中的true,表示是数据块是一个简单值而不是对象值。
      gDefaultRetVal="${l_startRowNum} ${l_startRowNum} -1 true"
    else
      #读取多行数据块的起止行号。
      _getStartAndEndRowNumFromMultipleRows "${@}"
    fi
  else
    if [[ "${l_value}"  && "${l_value}" =~ ^([ ]*\[)(.*)(\])$ ]] ;then
      #如果l_value不为空，则是以空格和/或“[”开头，以“]”结尾的字符串，则：
      #1. 先判断目标数组项是否存在，如果不存在且是插入模式，则完成目标数组项的插入。
      _insertArrayItem "${@}"
      l_arrayLen="${gDefaultRetVal}"
      if [ "${l_arrayIndex}" -ge "${l_arrayLen}" ];then
        #数组项不存在，则直接返回”-1 -1 l_arrayLen“，表明数组项不存在。
        gDefaultRetVal="-1 -1 ${l_arrayLen}"
      else
        #将起止行号都设置为l_startRowNum，表明数组项就在参数所在行。
        gDefaultRetVal="${l_startRowNum} ${l_startRowNum} ${l_arrayLen}"
      fi
    else
      #读取列表项数据块的起止行号。
      _getStartAndEndRowNumFromList "${@}"
    fi
  fi

  unset l_mode
  unset l_yamlFile
  unset l_startRowNum
  unset l_initEndRowNum
  unset l_arrayIndex
  unset l_initSpaceNum

  unset l_content
  unset l_value
  unset l_arrayLen
}

#读取数据块的内容
function _readDataBlock(){
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_endRowNum=$3
  local l_arrayIndex=$4

  local l_content
  local l_array

  #先直接读取内容。
  l_content=$(awk "NR==${l_startRowNum}, NR==${l_endRowNum}" "${l_yamlFile}")
  #如果是数组格式，则直接读取l_arrayIndex指定的数组项。
  if [ "${l_arrayIndex}" -ge 0 ];then
    if [[ "${l_content}" =~ ^(.*):([ ]+)\[(.*)\]([ ]*)$ ]];then
      #去掉开头的"["符号
      l_content="${l_content#*[}"
      #去掉结尾的"]"符号
      l_content="${l_content%]*}"
      #字符串转数组
      # shellcheck disable=SC2206
      l_array=(${l_content//,/ })
      #读取第l_arrayIndex项数据。
      l_content="${l_array[${l_arrayIndex}]}"
    fi
  fi

  #返回数据
  gDefaultRetVal="${l_content}"

  unset l_yamlFile
  unset l_startRowNum
  unset l_endRowNum
  unset l_arrayIndex

  unset l_content
  unset l_array
}

#查找第一个有效行，并判断如果该行是否是空格和/或”|“符号开头的？如果是则删除该行。
function _deleteFirstVerticalBarRow() {
  local l_content=$1
  #是否删除第一个有效行之前的注释行
  local l_deletePrefixCommentLines=$2

  local l_lines
  local l_arrayLen
  local l_i

  local l_isFirstValidRow
  local l_newContent

  export gDefaultRetVal

  if [ ! "${l_deletePrefixCommentLines}" ];then
    l_deletePrefixCommentLines="false"
  fi

  # 将旧内容字符串按行拆分到数组中
  stringToArray "${l_content}" "l_lines"
  #得到数组长度。
  l_arrayLen="${#l_lines[@]}"

  l_isFirstValidRow="false"
  for (( l_i = 0; l_i < l_arrayLen; l_i++ )); do
    if [ "${l_isFirstValidRow}" == "false" ];then
      #尚未找到第一个有效行则：
      if [[ "${l_lines[${l_i}]}" =~ ^([ ]*)#(.*)$ ]];then
        #当前行是注释行:
        if [ "${l_deletePrefixCommentLines}" == "true" ];then
          #删除前导注释行
          continue;
        fi
      elif [[ ! "${l_lines[${l_i}]}" =~ ^([ ]*)$ ]];then
        #当前行不是注释行且不是空行。
        l_isFirstValidRow="true"
        if [[ "${l_lines[${l_i}]}" =~ ^([ ]*)\|[+-]*([ ]*)$ ]];then
          #如果当前行是空格+|开头的，则跳过该行。
          continue;
        fi
      fi
    fi

    if [ "${l_newContent}" ];then
      l_newContent="${l_newContent}\n${l_lines[${l_i}]}"
    else
      l_newContent="${l_lines[${l_i}]}"
    fi
  done

  l_newContent=$(echo -e "${l_newContent}")

  #返回结果
  gDefaultRetVal="${l_newContent}"

  unset l_content

  unset l_lines
  unset l_arrayLen
  unset l_i

  unset l_isFirstValidRow
  unset l_newContent
}

#读取多行数据块的起止行号。
function _getStartAndEndRowNumFromMultipleRows() {
  export gDefaultRetVal

  local l_mode=$1
  local l_yamlFile=$2
  local l_startRowNum=$3
  local l_initEndRowNum=$4
  local l_arrayIndex=$5
  #l_startRowNum行的前导空格数。
  local l_initSpaceNum=$6

  local l_content
  local l_tmpStartRowNum
  local l_tmpEndRowNum
  local l_regexStr
  local l_rowNumAndSpaceNum
  local l_tmpContent

  #先获取l_initSpaceNum参数的实际值。
  l_content=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
  [[ "${l_content}" =~ ^([ ]*)(\-) ]] && ((l_initSpaceNum = l_initSpaceNum + 2))

  #查找l_startRowNum行的下一个兄弟行的行号。
  _getDataBlockEndRowNum "${l_yamlFile}" "${l_startRowNum}" "${l_initEndRowNum}" "${l_initSpaceNum}"
  l_tmpEndRowNum="${gDefaultRetVal}"

  #数据块的起始行等于参数行前进一行。
  ((l_tmpStartRowNum = l_startRowNum + 1))
  if [ "${l_tmpEndRowNum}" -gt "${l_tmpStartRowNum}" ];then
    #排除尾部注释行，并返回数据块的最终截至行。
    l_regexStr="^[ ]*(\-|[a-zA-Z_]?[a-zA-Z0-9_\-]*)"
    _getRowNumAndPrefixSpaceNum "${l_yamlFile}" "${l_regexStr}" "${l_tmpStartRowNum}" "${l_tmpEndRowNum}" "reverse"
    # shellcheck disable=SC2206
    l_rowNumAndSpaceNum=(${gDefaultRetVal})
    l_tmpEndRowNum="${l_rowNumAndSpaceNum[0]}"

    if [ "${l_tmpEndRowNum}" -ne -1 ];then
      #返回值不等于-1，说明存在有效行。
      gDefaultRetVal="${l_tmpStartRowNum} ${l_tmpEndRowNum}"
    else
      #返回值为-1，说明l_startRowNum行下属数据块不存在。
      gDefaultRetVal="-1 -1"
    fi
  elif [ "${l_tmpEndRowNum}" -eq "${l_tmpStartRowNum}" ];then
    #如果截至行等于起始行，则l_startRowNum行下属数据块只有一行。
    gDefaultRetVal="${l_tmpStartRowNum} ${l_tmpEndRowNum}"
  else
    gDefaultRetVal="-1 -1"
    #如果截至行小于起始行，则判断l_startRowNum行是否满足格式：{参数名}: {参数值}。
    l_tmpContent=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
    #如果l_startRowNum行数据满足格式：{参数名}: {参数值}，则返回l_startRowNum,并标识为简单值。
    [[ "${l_tmpContent}" =~ ^(.*):(.*)$ ]] && gDefaultRetVal="${l_startRowNum} ${l_startRowNum} -1 true"
  fi

  unset l_mode
  unset l_yamlFile
  unset l_startRowNum
  unset l_initEndRowNum
  unset l_arrayIndex
  unset l_initSpaceNum

  unset l_tmpStartRowNum
  unset l_tmpEndRowNum
  unset l_regexStr
  unset l_rowNumAndSpaceNum
  unset l_tmpContent
}

#从列表中读取列表项数据块的起止行号。
function _getStartAndEndRowNumFromList() {
  export gDefaultRetVal

  local l_mode=$1
  local l_yamlFile=$2
  local l_startRowNum=$3
  local l_endRowNum=$4
  local l_arrayIndex=$5
  #l_startRowNum行的前导空格数。
  local l_initSpaceNum=$6

  local l_tmpStartRowNum
  local l_tmpEndRowNum
  local l_blockEndRowNum
  local l_tmpSpaceNum
  local l_tmpSpaceStr
  local l_startRowData
  local l_content

  local l_listItems
  local l_itemCount
  local l_tmpItemCount
  local l_rowNumAndSpaceNum
  local l_item
  local l_nextItemIndex
  local l_tmpStartRowNum1

  #先获取l_initSpaceNum参数的实际值。
  l_startRowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
  [[ "${l_startRowData}" =~ ^([ ]*)(\-) ]] && ((l_initSpaceNum = l_initSpaceNum + 2))

  #获取l_startRowNum行参数的数据块的截至行行号。
  _getDataBlockEndRowNum "${l_yamlFile}" "${l_startRowNum}" "${l_endRowNum}" "${l_initSpaceNum}"
  l_blockEndRowNum="${gDefaultRetVal}"
  ((l_tmpEndRowNum = l_blockEndRowNum))

  l_content=""
  if [ "${l_startRowNum}" -lt "${l_tmpEndRowNum}" ];then
    #设置l_startRowNum行参数的数据块的起始行行号。
    ((l_tmpStartRowNum = l_startRowNum + 1))
    #可能的最大前导空格数等于(l_initSpaceNum + 2)
    ((l_tmpSpaceNum = l_initSpaceNum + 2))
    l_regexStr="^([ ]{${l_initSpaceNum},${l_tmpSpaceNum}})(\-)"
    #过滤出l_tmpStartRowNum到l_tmpEndRowNum行中的所有数组项的起始行信息。
    l_content=$(awk "NR==${l_tmpStartRowNum}, NR==${l_tmpEndRowNum}" "${l_yamlFile}" | grep -onP "${l_regexStr}")
  fi

  if [ ! "${l_content}" ];then
    if [ "${l_mode}" != "insert" ];then
      gDefaultRetVal="-1 -1 -1"
      ((l_itemCount = 0))
    else
      if [ "${l_startRowNum}" -lt "${l_tmpEndRowNum}" ];then
        #此时说明l_startRowNum行下的内容不是列表项格式，需要删除原有的内容。
        _deleteContentInFile "${l_yamlFile}" "${l_tmpStartRowNum}" "${l_tmpEndRowNum}" "${l_arrayIndex}"
      fi
      #清除l_startRowNum行可能存在的值域，例如：“|”
      if [[ ! "${l_startRowData#*:}" =~ ^([ ]*)$ ]];then
        sed -i "${l_startRowNum}c \\${l_startRowData%%:*}: " "${l_yamlFile}"
      fi
      #截至行号设置为l_startRowNum,也即是在l_startRowNum的下一行添加新项。
      l_tmpEndRowNum="${l_startRowNum}"
      ((l_itemCount = 0))
    fi
  else
    #字符串转数组
    stringToArray "${l_content}" "l_listItems"
    #获取列表项总数:
    l_itemCount=${#l_listItems[@]}

    l_item="${l_listItems[0]}"
    #去掉开头的行号信息
    l_item="${l_item#*:}"
    #去除“-”后面的内容
    l_item="${l_item%%-*}"
    #获取第一个列表项的前导空格数量。
    l_tmpSpaceNum="${#l_item}"
  fi

  #如果目标列表项缺失：
  if [ "${l_arrayIndex}" -ge "${l_itemCount}" ];then

    if [ "${l_mode}" != "insert" ];then
      #如果不是插入模式，则直接返回-1, 表示列表项不存在。
      gDefaultRetVal="-1 -1 ${l_itemCount}"
      #清除插入位置
      ((l_tmpEndRowNum = -1))
    fi

    if [ "${l_tmpEndRowNum}" -ge 0 ];then
      ((l_tmpItemCount = l_itemCount))
      ((l_tmpSpaceNum = l_initSpaceNum + 2))
      #循环插入缺失的列表项。
      while [ "${l_arrayIndex}" -ge "${l_tmpItemCount}" ]; do
        l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum}s")
        sed -i "${l_tmpEndRowNum}a\\${l_tmpSpaceStr}- " "${l_yamlFile}"
        ((l_tmpEndRowNum = l_tmpEndRowNum + 1))
        ((l_tmpItemCount = l_tmpItemCount + 1))
      done
      #数据块的起始位置同步设置为l_tmpEndRowNum
      ((l_tmpStartRowNum = l_tmpEndRowNum))
      #设置返回值。
      gDefaultRetVal="${l_tmpStartRowNum} ${l_tmpEndRowNum} ${l_tmpItemCount}"
    fi

  else
    #目标列表项已经存在了
    l_item="${l_listItems[${l_arrayIndex}]}"
    l_tmpEndRowNum="${l_item%%:*}"
    #将相对行号转换为绝对行号
    ((l_tmpStartRowNum1 = l_tmpStartRowNum + l_tmpEndRowNum -1))

    #去掉开头的行号信息
    l_item="${l_item#*:}"
    #获取前缀空格字符串。
    l_item="${l_item%-*}"
    #列表项的前导空格数量
    l_tmpSpaceNum="${#l_item}"

    #获取数据块的截至行：
    #判断第(l_arrayIndex + 1)项是否存在
    ((l_nextItemIndex = l_arrayIndex + 1))
    if [ "${l_nextItemIndex}" -lt "${l_itemCount}" ];then
      #如果第(l_arrayIndex + 1)项存在,则用该项的行号减1作为数据块的截至行号。
      l_item="${l_listItems[${l_nextItemIndex}]}"
      l_tmpEndRowNum="${l_item%%:*}"
      ((l_tmpEndRowNum = l_tmpStartRowNum + l_tmpEndRowNum - 2))
    else
      #如果第(l_arrayIndex + 1)项不存在，则：
      #从l_tmpStartRowNum1到l_endRowNum行，查找前导空格小于l_tmpSpaceNum的第一个有效行。
      l_regexStr="^([ ]{0,${l_tmpSpaceNum}})[a-zA-Z_]+"
      _getRowNumAndPrefixSpaceNum "${l_yamlFile}" "${l_regexStr}" "${l_tmpStartRowNum}" "${l_endRowNum}" "positive"
      # shellcheck disable=SC2206
      l_rowNumAndSpaceNum=(${gDefaultRetVal})
      l_tmpEndRowNum="${l_rowNumAndSpaceNum[0]}"
      if [ "${l_tmpEndRowNum}" -gt 0 ];then
        #找到了有效行，则数据块的截至行等于有效行的行号减1.
        ((l_tmpEndRowNum = l_tmpEndRowNum - 1))
      else
        #如果没有找到有效行，则设置截至行为l_endRowNum
        ((l_tmpEndRowNum = l_blockEndRowNum))
      fi
    fi

    #为清除后缀的注释行，从l_tmpStartRowNum1行到l_tmpEndRowNum行，
    #倒序查询第一个有效行，以该行的行号作为最终的截至行行号。
    l_regexStr="^[ ]*[a-zA-Z_\-]+"
    _getRowNumAndPrefixSpaceNum "${l_yamlFile}" "${l_regexStr}" "${l_tmpStartRowNum1}" "${l_tmpEndRowNum}" "reverse"
    # shellcheck disable=SC2206
    l_rowNumAndSpaceNum=(${gDefaultRetVal})
    l_tmpEndRowNum="${l_rowNumAndSpaceNum[0]}"
    if [ "${l_tmpEndRowNum}" -eq -1 ];then
      ((l_tmpEndRowNum = l_tmpStartRowNum1))
    fi

    #设置返回值。
    gDefaultRetVal="${l_tmpStartRowNum1} ${l_tmpEndRowNum} ${l_itemCount}"
  fi

  unset l_mode
  unset l_yamlFile
  unset l_startRowNum
  unset l_endRowNum
  unset l_arrayIndex
  unset l_initSpaceNum

  unset l_tmpStartRowNum
  unset l_tmpEndRowNum
  unset l_blockEndRowNum
  unset l_tmpSpaceNum
  unset l_tmpSpaceStr
  unset l_content

  unset l_listItems
  unset l_itemCount
  unset l_tmpItemCount
  unset l_rowNumAndSpaceNum
  unset l_item
  unset l_nextItemIndex
  unset l_tmpStartRowNum1
}

#在数组中插入目标数组项,并返回数组长度
function _insertArrayItem() {
  export gDefaultRetVal

  local l_mode=$1
  local l_yamlFile=$2
  local l_startRowNum=$3
  local l_arrayIndex=$5
  local l_newContent=$7

  local l_rowData
  local l_content
  local l_tmpContent
  local l_array
  local l_arrayLen

  if [ ! "${l_newContent}" ];then
    l_newContent="_*_"
  fi

  #读取参数所在行的内容。
  l_rowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
  #去掉开头的"["符号
  l_content="${l_rowData#*[}"
  #去掉结尾的"]"符号
  l_content="${l_content%]*}"

  #将字符串转换为数组。
  #将数组项间隔符(英文逗号)替换为空格
  l_tmpContent="${l_content//,/ }"
  # shellcheck disable=SC2206
  l_array=(${l_tmpContent})
  #获取数组的长度
  l_arrayLen="${#l_array[@]}"

  #如果目标数组项不存在，则在数组中追加数组项，确保目标数组项存在。
  if [[ "${l_arrayIndex}" -ge "${l_arrayLen}" && "${l_mode}" == "insert" ]];then
    l_tmpContent="${l_content%,*}"
    while [ "${l_arrayIndex}" -ge "${l_arrayLen}" ]; do
      if [ "${l_arrayIndex}" -eq "${l_arrayLen}" ];then
        #设置该项的值为l_newContent
        l_tmpContent="${l_tmpContent},${l_newContent}"
      else
        #使用”_*_“字符串填充中间的数组项。
        l_tmpContent="${l_tmpContent},_*_"
      fi
      ((l_arrayLen = l_arrayLen + 1))
    done
    #修改l_startRowNum行的内容
    l_tmpContent="[${l_tmpContent}]"
    sed -i "${l_startRowNum}c\\${l_rowData%:*}: ${l_tmpContent}" "${l_yamlFile}"
  fi

  #返回数组的长度
  gDefaultRetVal="${l_arrayLen}"

  unset l_mode
  unset l_yamlFile
  unset l_startRowNum
  unset l_arrayIndex
  unset l_newContent

  unset l_rowData
  unset l_content
  unset l_tmpContent
  unset l_array
  unset l_arrayLen
}

#得到l_startRowNum行上参数的下属数据块的截至行号。
function _getDataBlockEndRowNum(){
  export gDefaultRetVal

  local l_yamlFile=$1
  #参数所在的行
  local l_startRowNum=$2
  #父级参数数据块的截至行
  local l_endRowNum=$3
  #l_startRowNum行的前导空格数。
  local l_initSpaceNum=$4

  local l_content
  local l_tmpStartRowNum
  local l_tmpEndRowNum

  if [ "${l_endRowNum}" -eq -1 ];then
    l_endRowNum=$(sed -n '$=' "${l_yamlFile}")
  fi

  if [ "${l_startRowNum}" -ge "${l_endRowNum}" ];then
    l_tmpStartRowNum="${l_startRowNum}"
    #如果起止行号相对，则截至行号等于起始行号。
    l_tmpEndRowNum="${l_startRowNum}"
  else
    #构造正则表达式，并从(l_startRowNum + 1)行开始，到l_endRowNum行截至，获取第一个匹配行的行号。
    l_regexStr="^[ ]{0,${l_initSpaceNum}}(\-|[a-zA-Z_]+[a-zA-Z0-9_\-]*:)"
    ((l_tmpStartRowNum = l_startRowNum + 1))
    l_content=$(awk "NR==${l_tmpStartRowNum}, NR==${l_endRowNum}" "${l_yamlFile}" | grep -m 1 -noP "${l_regexStr}")
    if [ "${l_content}" ];then
      l_tmpEndRowNum="${l_content%%:*}"
      ((l_tmpEndRowNum = l_tmpStartRowNum + l_tmpEndRowNum -2))
    else
      #如果没有找到，则用l_endRowNum作为数据块的截至行号。
      ((l_tmpEndRowNum=l_endRowNum))
    fi
  fi

  if [[ "${l_tmpStartRowNum}" -le "${l_tmpEndRowNum}" && "${l_tmpEndRowNum}" -ne "${l_endRowNum}" ]];then
    #如果没有找到，则用最后一个有效行的行号作为数据块的截至行号。
    l_regexStr="^[ ]*(\-|[a-zA-Z0-9_]+)"
    l_content=$(awk "NR==${l_tmpStartRowNum}, NR==${l_tmpEndRowNum}" "${l_yamlFile}" | grep -noP "${l_regexStr}" | tail -n 1)
    if [ "${l_content}" ];then
      l_tmpEndRowNum="${l_content%%:*}"
      ((l_tmpEndRowNum = l_tmpStartRowNum + l_tmpEndRowNum - 1))
    else
      #此时说明l_tmpStartRowNum与l_tmpEndRowNum之间没有有效行，
      #将截至行号设置为起始行号。
      ((l_tmpEndRowNum = l_startRowNum))
    fi
  fi

  gDefaultRetVal="${l_tmpEndRowNum}"

  unset l_yamlFile
  unset l_startRowNum
  unset l_endRowNum
  unset l_initSpaceNum

  unset l_content
  unset l_tmpStartRowNum
  unset l_tmpEndRowNum
}

function _getReadContent() {
  export gDefaultRetVal

  local l_stdParamName=$1
  local l_content=$2
  local l_isSampleValue=$3
  local l_arrayIndex=$4
  local l_startRowNum=$5
  local l_keepOriginalFormat=$6

  local l_initRowPrefix
  local l_lines
  local l_lineCount
  local l_tmpSpaceNum

  #如果有前缀字符串，则添加之。
  if [ "${l_keepOriginalFormat}" == "true" ];then
    #获取参数值中可能存在的前导字符，例如：|等
    l_initRowPrefix=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
    if [[ "${l_initRowPrefix}" =~ ^(.*):([ ]+)\|[+-]*([ ]*)$ ]];then
      l_initRowPrefix="${l_initRowPrefix#*:}"
      l_content=$(echo -e "${l_initRowPrefix}\n${l_content}")
    fi
  fi

  #计算l_content的行数(会删除末尾的空行)。
  l_lineCount=$(echo -e "${l_content}" | grep -oP "^([ ]*).*$" | wc -l )

  if [ "${l_lineCount}" -eq  1 ];then
    #如果是数组项且以空格和/或"-"开头，则要将"-"替换成空格
    if [[ "${l_isSampleValue}" == "false" || "${l_keepOriginalFormat}" == "false" && "${l_arrayIndex}" -ge 0 && "${l_content}" =~ ^([ ]*)\- ]];then
      l_content="${l_content/-/ }"
      l_tmpSpaceNum=$(echo "${l_content}" | grep -o "^[ ]*" | grep -o " " | wc -l)
      l_content="${l_content:${l_tmpSpaceNum}}"
    fi
    #如果参数是简单值，则读取冒号后的参数值并返回之。
    [[ "${l_isSampleValue}" == "true" ]] && l_content="${l_content#*:}" && l_content="${l_content:1}"
  elif [ "${l_keepOriginalFormat}" == "false" ];then
    if [[ "${l_arrayIndex}" -ge 0 && "${l_content}" =~ ^([ ]*)\- ]];then
      l_content="${l_content/-/ }"
    fi
    #获取l_content的前导空格数量。
    _getPrefixSpaceNum "${l_content}"
    l_tmpSpaceNum="${gDefaultRetVal}"
    if [ "${l_tmpSpaceNum}" -gt 0 ];then
      #删除前导空格
      _indentContent "${l_content}" "-${l_tmpSpaceNum}"
      l_content="${gDefaultRetVal}"
    fi
  fi

  gDefaultRetVal="${l_content}"

  unset l_stdParamName
  unset l_content
  unset l_isSampleValue
  unset l_arrayIndex
  unset l_startRowNum
  unset l_keepOriginalFormat

  unset l_initRowPrefix
  unset l_lines
  unset l_lineCount
  unset l_tmpSpaceNum
}

function _checkAndAddListItemPrefix() {
  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_endRowNum=$3
  local l_arrayIndex=$4

  local l_rowData
  local l_tmpRowNum
  local l_rowNumAndSpaceNum
  local l_tmpSpaceNum
  local l_tmpSpaceStr

  if [[ "${l_startRowNum}" -eq "${l_endRowNum}" && "${l_arrayIndex}" -lt 0 ]];then
    #读取l_startRowNum行的数据。
    l_rowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
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
            l_rowData=$(sed -n "${l_tmpRowNum}p" "${l_yamlFile}")
            #构造前导空格字符串。
            l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum}s- ")
            #使用l_tmpSpaceStr替换l_rowData数据的前导空格。
            ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
            l_rowData="${l_tmpSpaceStr}${l_rowData:${l_tmpSpaceNum}}"
            #最后，替换文件中l_tmpRowNum行的数据。
            sed -i "${l_tmpRowNum}c \\${l_rowData}" "${l_yamlFile}"
          fi
        fi
      fi
    fi
  fi

  unset l_rowData
  unset l_tmpRowNum
  unset l_rowNumAndSpaceNum
  unset l_tmpSpaceNum
  unset l_tmpSpaceStr
}

#使用单行数据更新指定行的数据
function _updateSingleRowValue() {
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_newContent=$3

  local l_rowData
  local l_tmpSpaceNum
  local l_tmpSpaceNum1
  local l_tmpSpaceStr
  local l_endRowNum
  local l_addRowNum

  ((l_endRowNum = l_startRowNum))
  ((l_addRowNum = 0))
  l_rowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
  #如果新内容包含": "字符串,则
  if [[ "${l_newContent}" =~ ^([ ]*)[a-zA-Z_]+[a-zA-Z0-9_\-]*(: ).*$ ]];then
    #获取l_startRowNum行前导空格数
    l_tmpSpaceNum=$(echo "${l_rowData}" | grep -o "^[ ]*" | grep -o " " | wc -l)
    #在l_startRowNum行的下一行插入数据，因此前导空格数加2.
    ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
    #如果l_startRowNum行是以“- ”开头的，前导空格数再加2.
    [[ "${l_rowData}" =~ ^([ ]*)(- ) ]] && ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
    #获取新内容的前导空格数
    l_tmpSpaceNum1=$(echo "${l_newContent}" | grep -o "^[ ]*" | grep -o " " | wc -l)
    #获取指定长度的字符串
    l_tmpSpaceStr=$(printf "%${l_tmpSpaceNum}s")
    #构造新内容
    l_newContent="${l_tmpSpaceStr}${l_newContent:${l_tmpSpaceNum1}}"
    #在l_startRowNum的下面插入一行。
    sed -i "${l_startRowNum}a \\${l_newContent}" "${l_yamlFile}"
    #最后执行依次l_startRowNum行值域的清除操作，防止l_startRowNum行上存在”|“等前导字符串。
    sed -i "${l_startRowNum}c \\${l_rowData%%:*}:" "${l_yamlFile}"
    ((l_endRowNum = l_startRowNum + 1))
    ((l_addRowNum = 1))
  else
    #直接更新到l_startRowNum行的值域。
    l_rowData="${l_rowData%%:*}: ${l_newContent}"
    sed -i "${l_startRowNum}c \\${l_rowData}" "${l_yamlFile}"
  fi

  gDefaultRetVal="${l_startRowNum} ${l_endRowNum} -1 ${l_addRowNum}"

  unset l_yamlFile
  unset l_startRowNum
  unset l_newValue

  unset l_rowData
  unset l_tmpSpaceNum
  unset l_tmpSpaceNum1
  unset l_tmpSpaceStr
  unset l_endRowNum
  unset l_addRowNum
}

#使用多行数据更新指定行的数据。
function _updateMultipleRowValue() {
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_startRowNum=$2
  local l_newContent=$3
  #新内容所占的行数。
  local l_lineCount=$4

  local l_firstRowData
  local l_rowData
  local l_startRowData
  local l_tmpSpaceNum
  local l_tmpSpaceNum1
  local l_tmpRowNum

  l_rowData="${l_newContent}"
  #过滤出第一个有效行
  l_firstRowData=$(echo -e "${l_rowData}" | grep -noP "^[ ]*([a-zA-Z_\-\|]+).*$" | head -n 1)
  #如果第一行数据是”|“开头的，则删除该行。
  if [[ "${l_firstRowData}" =~ ^([0-9]+):([ ]*)\|[+-]*([ ]*)$ ]];then
    #获得第一行有效行的行号
    l_rowData="${l_firstRowData%%:*}"
    #获取第一行有效行的内容
    l_firstRowData="${l_firstRowData#*:}"
    #获取第一行有效行后面的内容
    l_rowData=$(echo -e "${l_newContent}" | sed "1,${l_rowData}d")
  else
    l_firstRowData=""
  fi

  #不论l_firstRowData是否是空串，都使用l_firstRowData更新l_startRowNum行的值域部分
  l_tmpSpaceNum=$(echo "${l_firstRowData}" | grep -o "^[ ]*" | grep -o " " | wc -l)
  l_firstRowData="${l_firstRowData:${l_tmpSpaceNum}}"
  #先获取l_startRowNum行的参数部分
  l_startRowData=$(sed -n "${l_startRowNum}p" "${l_yamlFile}")
  #更新l_startRowNum行的值域
  sed -i "${l_startRowNum}c \\${l_startRowData%%:*}: ${l_firstRowData}" "${l_yamlFile}"

  #在l_startRowNum行的下一行插入l_rowData数据:

  #获取l_startRowNum行的前导空格。
  l_tmpSpaceNum=$(echo "${l_startRowData}" | grep -o "^[ ]*" | grep -o " " | wc -l)
  if [[ "${l_startRowData}" =~ ^([ ]*)\- ]];then
    #如果l_startRowData是以空格和”-“为前导的，则计算的前导空格还要加2.
    ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
  fi
  #l_startRowNum行的下一行数据的前导空格数等于(l_tmpSpaceNum + 2)
  ((l_tmpSpaceNum = l_tmpSpaceNum + 2))
  #在获取新数据第一行的前导空格数量。
  l_tmpSpaceNum1=$(echo -e "${l_rowData}" | grep -o "^[ ]*[a-zA-Z_\-]+.*$" | grep -o "^[ ]*" | grep -o " " | wc -l)
  #计算前导空格数量的差值。
  ((l_tmpSpaceNum = l_tmpSpaceNum - l_tmpSpaceNum1))
  #将l_rowData数据整体左移或右移l_tmpSpaceNum个字符。l_tmpSpaceNum为负数时向左移动，为正数时向右移动。
  _indentContent "${l_rowData}" "${l_tmpSpaceNum}"
  l_rowData="${gDefaultRetVal}"
  #多行格式的字符串转换为单行格式的字符串(字符串中含有换行符):
  _convertToSingleRow "${l_rowData}"
  l_rowData="${gDefaultRetVal}"
  #将单行格式的l_rowData插入到l_startRowNum行的下一行(字符串中的\n会被自动识别为换行符)。
  sed -i "${l_startRowNum}a \\${l_rowData}" "${l_yamlFile}"

  #计算插入的最后一行数据所在的行号。
  ((l_tmpRowNum = l_startRowNum + l_lineCount))
  #修正l_startRowNum的值，使其指向参数下属数据块的起始行
  ((l_startRowNum = l_startRowNum +1 ))
  #返回：更新的参数下属数据块的起始行号、参数下属数据块的截止行号、-1(填充值，无意义)
  gDefaultRetVal="${l_startRowNum} ${l_tmpRowNum} -1"

  unset l_yamlFile
  unset l_startRowNum
  unset l_newContent
  unset l_lineCount

  unset l_firstRowData
  unset l_rowData
  unset l_tmpSpaceNum
  unset l_tmpSpaceNum1
  unset l_startRowData
  unset l_tmpRowNum
}

#多行字符串转单行字符串（原字符串中的'\n'字符被转换为”\n“字符串）
function _convertToSingleRow() {
  export gDefaultRetVal
  local l_content=$1
  local l_rowData

  #这里使用”`“字符作为换行符的替换字符，先将原字符串中的”`“字符替换为双”``“字符串。
  l_rowData=$(echo -e "${l_content}" | sed "s/\`/\`\`/g")
  #然后将换行符转换为”`“字符并删除结尾的"`"符号，再将所有”`“字符转换为”\n“字符串,最后将"\n\n"字符串转换为”`“字符.
  gDefaultRetVal=$(echo -e "${l_rowData}" | tr '\n' '\`' | sed "s/\`$//" | sed "s/\`/\\\n/g" | sed "s/\\\n\\\n/\`/g")

  unset l_content
  unset l_rowData
}

function _adjustCachedParamsAfterUpdate() {
  export gDefaultRetVal
  export gFileDataBlockMap
  export _cachedParams

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_execResult=$3

  local l_array
  local l_startRowNum
  local l_endRowNum
  local l_addRowNum
  local l_deletedRowNum
  local l_diffRowNum

  local l_mapKey
  local l_index

  # shellcheck disable=SC2206
  l_array=(${l_execResult})

  l_startRowNum=${l_array[0]}
  l_endRowNum=${l_array[1]}
  l_addRowNum="${l_array[3]}"
  l_deletedRowNum="${l_array[4]}"
  ((l_diffRowNum = l_addRowNum - l_deletedRowNum))

  if [ "${l_diffRowNum}" -ne 0 ];then
    #删除缓存中key以l_paramPath为前缀的记录。
    _deleteChildData "${l_yamlFile}" "${l_paramPath}"
    #在缓存中找出Key的值是l_paramPath的值的前向匹配子串的记录，将其截止行号减去l_deletedRowNum数量。
    _adjustEndRowNum "${l_yamlFile}" "${l_paramPath}" "${l_diffRowNum}"
    #在缓存中查找Value值中起始行号大于l_startRowNum的记录，将其起始行号减去l_deletedRowNum数量。
    _adjustStartRowNum "${l_yamlFile}" "${l_paramPath}" "${l_startRowNum}" "${l_diffRowNum}"

    if [ "${l_endRowNum}" -gt "${l_startRowNum}" ];then
      _createCacheForParamPath "${l_yamlFile}" "${l_paramPath}" "${l_startRowNum}" "${l_endRowNum}"
    fi
    # shellcheck disable=SC2206
    l_array=(${_cachedParams//,/ })
    ((l_array[1] = l_array[1] + l_diffRowNum))
    # shellcheck disable=SC2124
    _cachedParams="${l_array[@]}"
    _cachedParams=${_cachedParams// /,}
  fi

  unset l_yamlFile
  unset l_paramPath
  unset l_execResult

  unset l_array
  unset l_startRowNum
  unset l_endRowNum
  unset l_addRowNum
  unset l_deletedRowNum
  unset l_diffRowNum

  unset l_mapKey
  unset l_index
}

function _adjustCachedParamsAfterDelete() {
  export gDefaultRetVal

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_execResult=$3

  local l_array
  local l_startRowNum
  local l_deletedRowNum

  # shellcheck disable=SC2206
  l_array=(${l_execResult})

  l_startRowNum=${l_array[0]}
  l_deletedRowNum="${l_array[2]}"

  #删除缓存中key以l_paramPath为前缀的记录。
  _deleteChildData "${l_yamlFile}" "${l_paramPath}"
  #在缓存中找出Key的值是l_paramPath的值的前向匹配子串的记录，将其截止行号减去l_deletedRowNum数量。
  _adjustEndRowNum "${l_yamlFile}" "${l_paramPath}" "-${l_deletedRowNum}"
  #在缓存中查找Value值中起始行号大于l_startRowNum的记录，将其起始行号减去l_deletedRowNum数量。
  _adjustStartRowNum "${l_yamlFile}" "${l_paramPath}" "${l_startRowNum}" "-${l_deletedRowNum}"

  unset l_yamlFile
  unset l_paramPath
  unset l_execResult

  unset l_array
  unset l_startRowNum
  unset l_deletedRowNum
}

function _deleteChildData() {
  export gFileDataBlockMap
  local l_yamlFile=$1
  local l_paramPath=$2

  local l_mapSize
  local l_mapKey
  local l_prefixStr
  local l_flag

  l_mapSize="${#gFileDataBlockMap[@]}"
  if [ "${l_mapSize}" -gt 0 ];then
     l_prefixStr="${l_yamlFile}|${l_paramPath}"
     l_prefixStr="${l_prefixStr//\[/\\\[}"
     l_prefixStr="${l_prefixStr//\]/\\\]}"
    # shellcheck disable=SC2068
    for l_mapKey in ${!gFileDataBlockMap[@]};do
      #删除缓存中key以l_paramPath为前缀的记录。
      l_flag=$(echo "${l_mapKey}" | grep -oP "^${l_prefixStr}[\.]*")
      if [ "${l_flag}" ];then
        #删除缓存数据项
        unset gFileDataBlockMap["${l_mapKey}"]
      fi
    done
  fi

  unset l_yamlFile
  unset l_paramPath

  unset l_mapSize
  unset l_mapKey
  unset l_prefixStr
  unset l_flag
}

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
    l_tmpParamPath="${l_paramPath%.*}"
    while [ "${l_tmpParamPath}" ]; do
      #构造l_mapKey参数的值。
      l_mapKey="${l_yamlFile##*/}|${l_tmpParamPath}"
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
      #向左回退参数路径，继续查找可能存在的缓存数据。
      if [[ "${l_tmpParamPath}" =~ ^(.*)\.(.*)$ ]];then
        l_tmpParamPath="${l_tmpParamPath%.*}"
      else
        l_tmpParamPath=""
      fi
    done
  fi

  unset l_yamlFile
  unset l_paramPath
  unset l_deletedRowNum

  unset l_mapSize
  unset l_tmpParamPath
  unset l_mapKey
  unset l_mapValue
  unset l_array
}

function _adjustStartRowNum() {
  export gFileDataBlockMap

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_startRowNum=$3
  local l_deletedRowNum=$4

  local l_mapSize
  local l_mapKey
  local l_mapValue
  local l_array

  l_mapSize="${#gFileDataBlockMap[@]}"
  if [ "${l_mapSize}" -gt 0 ];then
    # shellcheck disable=SC2068
    for l_mapKey in ${!gFileDataBlockMap[@]};do
      #读取可能存在的缓存参数。
      l_mapValue="${gFileDataBlockMap[${l_mapKey}]}"
      # shellcheck disable=SC2206
      l_array=(${l_mapValue//,/ })
      if [ "${l_array[0]}" -gt "${l_startRowNum}" ];then
        ((l_array[0] = l_array[0] + l_deletedRowNum))
        ((l_array[1] = l_array[1] + l_deletedRowNum))
        # shellcheck disable=SC2124
        l_mapValue="${l_array[@]}"
        l_mapValue="${l_mapValue// /,}"
        gFileDataBlockMap["${l_mapKey}"]="${l_mapValue}"
      fi
    done
  fi

  unset l_yamlFile
  unset l_paramPath
  unset l_startRowNum
  unset l_deletedRowNum

  unset l_mapSize
  unset l_mapKey
  unset l_mapValue
  unset l_array
}

function _createCacheForParamPath(){
  export gFileDataBlockMap

  local l_yamlFile=$1
  local l_paramPath=$2
  local l_startRowNum=$3
  local l_endRowNum=$4

  local l_index
  local l_mapKey

  l_index=$(echo -e "${l_paramPath##*.}" | grep -oP "^(.*)\[\d+\]$")
  #提前为该参数生成缓存数据。
  if [ "${l_index}" ];then
    l_index="${l_index##*[}"
    l_index="${l_index%]*}"
  else
    ((l_index = -1))
  fi
  l_mapKey="${l_yamlFile##*/}|${l_paramPath}"
  l_mapKey="${l_mapKey//\[/\\\[}"
  l_mapKey="${l_mapKey//\]/\\\]}"
  gFileDataBlockMap["${l_mapKey}"]="${l_startRowNum},${l_endRowNum},${l_index},true"

  unset l_yamlFile
  unset l_paramPath
  unset l_startRowNum
  unset l_endRowNum

  unset l_index
  unset l_mapKey
}

#-------------------------------------主流程-------------------------------------------#

#加载必须的库文件
# shellcheck disable=SC2164

export _selfRootDir

if [ ! "${_selfRootDir}" ];then
  # shellcheck disable=SC2164
  _selfRootDir=$(cd "$(dirname "$0")"; pwd)
fi
source "${_selfRootDir}/log-helper.sh"

#是否启用内部缓存机制。
export gEnableCache
if [ ! "${gEnableCache}" ];then
  gEnableCache="true"
fi

# 申明全局调试模式指示变量，用于debug函数内控制信息的显示
export gDebugMode
# 申明默认调试文件输出目录
export gDebugOutDir

#本文件中所有函数默认的返回变量。
export gDefaultRetVal

#${文件}_${参数路径}=>读取参数映射Map，用于缓存读取过的参数。
declare -A gFileDataBlockMap

#引入的全局临时文件目录
export gTempFileDir

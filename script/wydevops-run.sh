#!/usr/bin/env bash

# 将 Windows 路径转为 Linux 风格路径
# 用法: linux_path=$(win2linux "$PWD")
function win2linux() {
  local p="${1:-$PWD}"

  if command -v wslpath >/dev/null 2>&1; then
    # 若传入已是类 Unix 路径，wslpath -u 会报错到 stderr
    # 丢弃 stderr，并在失败时回显原值
    wslpath -u "$p" 2>/dev/null || printf '%s\n' "$p"
  elif command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p" 2>/dev/null || printf '%s\n' "$p"
  else
    # 朴素回退：C:\Users\me -> /mnt/c/Users/me（若没有 /mnt，则输出 /c/...）
    local has_mnt=0; [ -d /mnt ] && has_mnt=1
    printf '%s\n' "$p" | awk -v usemnt="$has_mnt" '
      BEGIN{IGNORECASE=1}
      {
        gsub("\\\\","/")                 # 反斜杠 -> 斜杠
        if ($0 ~ /^[A-Za-z]:\//) {
          d=tolower(substr($0,1,1))
          rest=substr($0,3)              # 去掉 "C:"
          if (usemnt) printf "/mnt/%s%s\n", d, rest;
          else         printf "/%s%s\n",    d, rest;
        } else print                     # 已是类 Unix 路径则原样返回
      }'
  fi
}

#允许传入两个参数：第一个参数为项目目录，第二个参数为本地配置文件名称, 第三个为wydevops脚本目录

#定义wydevops脚本中script目录的路径
_SCRIPT_ROOT_DIR=$(win2linux ${3:-$WYDEVOPS_HOME})

#定义当前项目主模块目录路径:
#如果是单模块项目，则路径以工程目录结尾，最后面必须有"/"
#如果是多模块项目，则路径以主模块目录结尾，最后面不能有"/"
module_dir=$(win2linux "${1:-$PWD}")
_PROJECT_MAIN_MODULE_DIR=$(realpath -m -- "${module_dir}")

#如果module_dir是以"/"结尾，需要确保_PROJECT_MAIN_MODULE_DIR也以"/"结尾
if [[ "$1" == */ ]]; then
  _PROJECT_MAIN_MODULE_DIR="${_PROJECT_MAIN_MODULE_DIR}/"
fi

bash "${_SCRIPT_ROOT_DIR}/wydevops.sh" -e -f -m -c \
--localConfigFile "${2:-ci-cd-config.yaml}" \
-A linux/amd64 \
-O linux/amd64 \
-B single \
-I /d/cachedImage \
-L java \
-S build,docker,chart,package,deploy \
-M local \
-T true \
-W "${_SCRIPT_ROOT_DIR}" \
-P "${_PROJECT_MAIN_MODULE_DIR}" \
#-C "harbor,chartmuseum,192.168.1.214:80,admin,Harbor12345,80" \
#-D "harbor,registry.docker.home,192.168.1.214:80,admin,Harbor12345,80"
#-C "nexus,chartmuseum,192.168.1.214:8081,admin,Wpl118124,8081" \
#-D "nexus,registry.docker.home,192.168.1.214:8002,admin,Wpl118124,8081"
#-D "registry,wydevops,192.168.1.218:30783,admin,admin123,30784,true,docker-registry /etc/docker/registry/config.yml"
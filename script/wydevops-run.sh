#!/usr/bin/env bash
#todo: 使用本文件需要定义环境变量：WYDEVOPS_HOME， 该变量指向本项目script目录所在的磁盘路径

# 获取当前脚本所在目录的绝对路径（解析符号链接）
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
echo "$SCRIPT_DIR"

source "${SCRIPT_DIR}/helper/path-helper.sh"

#允许传入两个参数：第一个参数为项目目录，第二个参数为本地配置文件名称, 第三个为wydevops脚本目录

#定义wydevops脚本中script目录的路径
_SCRIPT_ROOT_DIR=$(win2linux ${3:-$WYDEVOPS_HOME})
if [ ! "${_SCRIPT_ROOT_DIR}" ];then
  _SCRIPT_ROOT_DIR=${PWD}
fi

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
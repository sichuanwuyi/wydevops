#!/usr/bin/env bash
#定义wydevops脚本中script目录的路径
_SCRIPT_ROOT_DIR="/e/tmt/wydevops/script"
#定义当前项目主模块目录路径:
#如果是单模块项目，则路径以工程目录结尾，最后面必须有"/"
#如果是多模块项目，则路径以主模块目录结尾，最后面不能有"/"
_PROJECT_MAIN_MODULE_DIR="/E/tmt/wydevops/sample/vue/vue-demo/"

bash "${_SCRIPT_ROOT_DIR}/wydevops.sh" -e -d -m \
-A linux/amd64 \
-O linux/amd64 \
-B single \
-I /d/cachedImage \
-L vue \
-S docker \
-M local \
-T true \
-W "${_SCRIPT_ROOT_DIR}" \
-P "${_PROJECT_MAIN_MODULE_DIR}" \
-C "nexus,chartmuseum,192.168.31.218:8081,admin,Wpl118124,8081" \
-D "nexus,wydevops,192.168.31.218:8001,admin,Wpl118124,8081"
#-C "harbor,chartmuseum,192.168.31.218:8088,admin,Harbor12345,8088" \
#-D "harbor,wydevops,192.168.31.218:8088,admin,Harbor12345,8088" \
#-N "http://192.168.100.236:8000/atom/v1/deployPlatform/api/update" \
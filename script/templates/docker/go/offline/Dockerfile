# 使用scratch创建最小镜像
FROM --platform=_PLATFORM_ scratch

WORKDIR _WORK-DIR-IN-CONTAINER_

RUN mkdir -p _WORK-DIR-IN-CONTAINER_/config
WORKDIR _WORK-DIR-IN-CONTAINER_

ENV VIPER_CONFIG=_WORK-DIR-IN-CONTAINER_/wydevops-config

# 复制编译好的二进制文件到镜像中
COPY ./_SERVICE-NAME_-_OS-TYPE_-_ARCH-TYPE_.out ./
COPY ./wydevops-config/ ./wydevops-config/

EXPOSE _EXPOSE_

# 设置容器启动时运行的命令
ENTRYPOINT ["_WORK-DIR-IN-CONTAINER_/_SERVICE-NAME_-_OS-TYPE_-_ARCH-TYPE_.out"]
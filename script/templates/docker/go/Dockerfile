FROM --platform=_PLATFORM_ _FROM-IMAGE0_ as builder

WORKDIR _WORK-DIR-IN-CONTAINER_

# 复制go.mod和go.sum文件并下载依赖
COPY go.mod go.sum ./
RUN go mod download

# 复制项目文件
COPY . .

# 编译Go程序，生成静态链接的二进制文件
RUN CGO_ENABLED=0 GOOS=_OS-TYPE_ GOARCH=_ARCH-TYPE_ go build -o _SERVICE-NAME_-_OS-TYPE_-_ARCH-TYPE_.out .

# 使用scratch创建最小镜像
FROM --platform=_PLATFORM_ scratch

WORKDIR _WORK-DIR-IN-CONTAINER_

ENV VIPER_CONFIG=_WORK-DIR-IN-CONTAINER_/config/config-prod.yaml

# 复制编译好的二进制文件到镜像中
COPY --from=builder _WORK-DIR-IN-CONTAINER_/_SERVICE-NAME_-_OS-TYPE_-_ARCH-TYPE_.out ./
COPY ./config-prod.yaml ./config/

EXPOSE _EXPOSE_

# 设置容器启动时运行的命令
ENTRYPOINT ["_WORK-DIR-IN-CONTAINER_/_SERVICE-NAME_-_OS-TYPE_-_ARCH-TYPE_.out"]
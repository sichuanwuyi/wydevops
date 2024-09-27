
FROM --platform=_PLATFORM_ _FROM-IMAGE0_
USER root

ENV TZ=_TZ_
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV JAVA_OPTS="-Dspring.config.location=_WORK-DIR-IN-CONTAINER_/config/"
ENV LANG C.UTF-8

RUN mkdir -p _WORK-DIR-IN-CONTAINER_/config

COPY ./dependencies/ ./snapshot-dependencies/ ./application/ ./spring-boot-loader/ _WORK-DIR-IN-CONTAINER_/
COPY ./config/ _WORK-DIR-IN-CONTAINER_/config/

EXPOSE _EXPOSE_

WORKDIR _WORK-DIR-IN-CONTAINER_

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.JarLauncher"]


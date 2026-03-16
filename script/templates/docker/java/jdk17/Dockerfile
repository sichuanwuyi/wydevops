
FROM --platform=_PLATFORM_ _FROM-IMAGE0_
USER root

ENV TZ=_TZ_
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV JVM_OPTS=_JVM-OPTS_
ENV JAVA_OPTS=_JAVA-OPTS_
ENV LANG=C.UTF-8

RUN mkdir -p _WORK-DIR-IN-CONTAINER_/wydevops-config

COPY ./dependencies/ ./snapshot-dependencies/ ./application/ ./spring-boot-loader/ _WORK-DIR-IN-CONTAINER_/
COPY ./wydevops-config/ _WORK-DIR-IN-CONTAINER_/wydevops-config/

EXPOSE _EXPOSE_

WORKDIR _WORK-DIR-IN-CONTAINER_

ENTRYPOINT ["sh", "-c", "java $JVM_OPTS $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]


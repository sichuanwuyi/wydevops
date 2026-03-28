docker rm -f wydevops-runner && \
docker run \
-v /mnt/d/maven-repository:/root/.m2/repository \
-v /mnt/d/apache-maven-3.9.12/conf/settings-docker.xml:/root/.m2/settings.xml \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /mnt/d/tmt_project/tmt-ignite3-server:/root/project \
-v /home/wuyi/wydevops:/root/.wydevops/wydevops \
--name wydevops-runner \
wydevops-runner:1.2.0
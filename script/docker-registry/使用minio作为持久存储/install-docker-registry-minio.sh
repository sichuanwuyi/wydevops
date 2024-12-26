#!/usr/bin/env bash

rm $(pwd)/htpasswd_file
touch $(pwd)/htpasswd_file
docker run --rm -v $(pwd)/htpasswd_file:/htpasswd_file docker.m.daocloud.io/httpd:latest htpasswd -Bbc /htpasswd_file admin admin123

kubectl create namespace docker-registry
kubectl create secret generic docker-registry-auth -n docker-registry --from-file=$(pwd)/htpasswd_file

kubectl delete -f docker-registry-minio.yaml
kubectl apply -f docker-registry-minio.yaml
#!/usr/bin/env bash
#通过以下步骤安装minio-pvc

#不需要修改
kubectl create -f provisioner.yaml
#不需要修改
kubectl create -f attacher.yaml
#不需要修改
kubectl create -f csi-s3.yaml

#minio-secret.yaml文件中需要根据具体环境进行配置。
kubectl create -f minio-secret.yaml
#不需要修改
kubectl create -f minio-storage-class.yaml
#不需要修改
kubectl create -f minio-pvc.yaml
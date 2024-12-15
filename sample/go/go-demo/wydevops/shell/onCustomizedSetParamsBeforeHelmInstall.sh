#!/usr/bin/env bash

function customizeSetParams(){
  export gDefaultRetVal
  gDefaultRetVal="deployment0.imagePullSecrets[0].name=regcred"
}

#customizeSetParams
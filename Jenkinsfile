pipeline {
  agent { label "${AGENT_LABEL}"}
  environment {
        GITHUB_USER_ID = '924b45239b2ef132f34d03d671865767'
        GITHUB_GROUP = 'tmt_china'
        JOB_NAME='wydevops'
        AGENT_LABEL = 'maven1'
        JENKINS_SCRIPT = '${BUILD_SCRIPT_ROOT}/wydevops.sh'
        IS_BUILD = 'true'
  }
  parameters {
      choice(name: 'GITHUB_BRANCH', choices: [ 'develop', 'master'], description: 'checkout git branch')
      choice(name: 'GITHUB_GROUP', choices: ['tmt_china', 'bill_wy'], description: 'checkout git group')
      choice(name: 'JOB_LANGUAGE', choices: ['shell'], description: '')
      string(name: 'AGENT_LABEL', defaultValue: 'maven1', description: 'agent label')
      string(name: 'BUILD_PATH', defaultValue: './', description: '执行编译的路径')
  }
  stages {
    stage('checkout') {
        options {
            timeout(time: 2, unit: 'MINUTES')
        }
        steps {
            git (credentialsId: "${GITHUB_USER_ID}", url: 'https://gitee.com/${GITHUB_GROUP}/${JOB_NAME}.git', branch: "${GITHUB_BRANCH}")
            script{
                currentBuild.result = 'SUCCESS'
                echo "${JOB_LANGUAGE}"
            }
        }
    }
    stage('Deploy') {
      when {
        allOf{
            expression {currentBuild.result == "SUCCESS"}
          }
      }
      steps {
        sh 'chmod -R 777 ${WORKSPACE}/script/*'
        echo "currentBuild.result: ${currentBuild.result} ${JOB_LANGUAGE}"
        sh "${WORKSPACE}/script/wydevops.sh -S 'deploy' -L ${JOB_LANGUAGE} -M 'jenkins'"
        echo 'Deploy'
      }
    }
  }
}
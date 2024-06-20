pipeline {
  agent { label "${AGENT_LABEL}"}
  environment {
        GITHUB_USER_ID = 'XXXXXXXX'
        GITHUB_GROUP = 'XXXXXX'
        AGENT_LABEL = 'maven1'
        JENKINS_SCRIPT = '${BUILD_SCRIPT_ROOT}/atom-jenkins.sh'
        IS_BUILD = 'true'
  }
  parameters {
      choice(name: 'GITHUB_BRANCH', choices: [ 'develop', 'master'], description: 'checkout git branch')
      choice(name: 'JOB_LANGUAGE', choices: ['shell', 'java', 'vue', 'c++', 'python'], description: '')
      string(name: 'GITHUB_USER_ID', defaultValue: 'd22c2382-258a-45dc-90e3-81a5142a17ce', description: 'git user')
      string(name: 'GITHUB_GROUP', defaultValue: 'atomdatatech', description: 'git group')
      string(name: 'AGENT_LABEL', defaultValue: 'maven1', description: 'agent label')
      choice(name: 'IS_BUILD', choices: ['false', 'true'], description: '是否执行编译')
      choice(name: 'SHOULD_PUBLISH', choices: ['false', 'true'], description: '是否上传制品')
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
        sh "${JENKINS_SCRIPT} -S 'deploy' -L ${JOB_LANGUAGE} -M 'jenkins'"
        echo 'Deploy'
      }
    }
  }
}
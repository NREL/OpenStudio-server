pipeline {
  agent {
    dockerfile {
      filename 'Dockerfile'
      dir 'docker/deployment'
      // set root user to access docker daemon and default region for s3 data
      args '-u root -e AWS_DEFAULT_REGION=us-east-1'
    }
  }
  stages {
    stage('Wait for Tests') {
      steps {
        sh 'cat /etc/issue'
        echo 'Checking for completion of builds, tests, and images on Docker Hub.'
        echo 'This is still to be done.'
      }
    }
    stage('You ready?') {
      steps {
        script {
          if (env.BRANCH_NAME == 'master') {
            input 'Ready to build and deploy AMI?'
          } else {
            echo 'Unable to deploy when not on master'
          }
        }
      }
    }
    stage('Build AMI') {
      steps {
        script {
          if (env.BRANCH_NAME == 'master') {
            withAWS(credentials: 'ec2NRELIS') {
                sh 'pwd'
                sh 'docker --version'
                sh 'python --version'
                sh 'packer --version'
                sh 'cd docker/deployment && python build_deploy_ami.py --verbose'
            }
          }
        }
      }
    }
  }
}

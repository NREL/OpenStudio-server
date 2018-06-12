pipeline {
  agent {
    dockerfile {
      filename 'docker/deployment/Dockerfile'
    }

  }
  stages {
    stage('Wait for Tests') {
      steps {
        echo 'Checking for completion of builds, tests, and images on Docker Hub'
      }
    }
    stage('You Ready?') {
      steps {
        input 'Ready to Build and Deploy AMI?'
      }
    }
    stage('Build AMI') {
      steps {
        echo 'Building AMI'
        sh 'docker run -it -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd):/go/run packer /bin/bash -c \'cd /go/run/docker/deployment; python build_deploy_ami.py --verbose\''
      }
    }
  }
}

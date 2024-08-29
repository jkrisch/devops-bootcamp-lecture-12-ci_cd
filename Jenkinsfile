#!/usr/bin/env groovy

library identifier: 'jenkins-shared-library@main', retriever: modernSCM(
  [$class: 'GitSCMSource',
  remote: 'https://github.com/jkrisch/jenkins-shared-library-mvn.git'
  ]
)

pipeline {   
  agent any
  tools {
    maven 'Maven'
  }
  environment {
    IMAGE_NAME = 'jaykay84/demo-app:java-maven-2.0'
  }
  stages {
    stage("build app") {
      steps {
        script {
          echo 'building application jar...'
          buildJar()
        }
      }
    }
    stage("build image") {
      steps {
        script {
          echo 'building docker image...'
          buildImage(env.IMAGE_NAME)
          dockerLogin()
          dockerPush(env.IMAGE_NAME)
        }
      }
    }

    stage("provision infra"){
        environment {
            AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY')
            AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
            TF_VAR_my_ip = credentials('MyIp')
        }
        steps{
            script{
                dir ('terraform'){
                    //tf provision
                    sh """
                        terraform init
                        terraform apply --auto-approve
                    """
                    //output the public ip adress within jenkins var
                    EC2_PUBLIC_IP = sh(
                        script: "terraform output ec2_instance_public_ip",
                        returnStdout: true
                    ).trim()                    
                }
            }
        }
    }

    stage("deploy") {
        environment{
            DOCKER_CREDS = credentials("docker-login")
        }
      steps {
        script {
            echo "Waiting for EC2 instance to initialize"
            sleep(time: 90, unit: "SECONDS")

            echo 'deploying docker image to EC2...'
            
            def shellCmd = "bash ./server-cmds.sh ${IMAGE_NAME} ${DOCKER_CREDS_USR} ${DOCKER_CREDS_PSW}"
            def ec2Instance = "ec2-user@${EC2_PUBLIC_IP}"

            sshagent(['ec2-ssh-key']) {
                sh "scp -o StrictHostKeyChecking=no server-cmds.sh ${ec2Instance}:/home/ec2-user"
                sh "scp -o StrictHostKeyChecking=no docker-compose.yaml ${ec2Instance}:/home/ec2-user"
                sh "ssh -o StrictHostKeyChecking=no ${ec2Instance} ${shellCmd}"
            }
        }
      }
    }               
  }
}

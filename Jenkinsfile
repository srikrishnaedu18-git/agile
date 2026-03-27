pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "srikrishnaedu18docker/java-app:latest"
        KUBECONFIG = "/var/jenkins_home/.kube/config"
    }


    stages {

        stage('Build') {
            steps {
                sh 'docker run --rm -v $PWD:/app -w /app maven:3.9.6-eclipse-temurin-17 mvn clean package'
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t $DOCKER_IMAGE .'
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                    echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                    docker push $DOCKER_IMAGE
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                export KUBECONFIG=/home/jenkins/.kube/config
                kubectl apply -f deployment.yaml
                kubectl apply -f service.yaml
                '''
            }
        }
        stage('Verify Deployment') {
            steps {
                sh 'kubectl get pods'
                sh 'kubectl get svc'
            }
        }
    }
}
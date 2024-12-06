pipeline {
    agent any

    environment {
        APP_NAME = "flask-hello-world"
        IMAGE_TAG = "latest"
    }

    stages {
        stage('Clone Repository') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh 'docker build -t ${APP_NAME}:${IMAGE_TAG} .'
                }
            }
        }

        stage('Run and Test Container') {
            steps {
                script {
                    sh '''
                    docker network create flask-pipeline-network || true
                    docker run -d --name test-${APP_NAME} --network flask-pipeline-network -p 5000:5000 ${APP_NAME}:${IMAGE_TAG}
                    sleep 5
                    curl -f http://localhost:5000 || (echo "Test failed: App did not start successfully!" && exit 1)
                    docker stop test-${APP_NAME} && docker rm test-${APP_NAME}
                    '''
                }
            }
        }
    }

    post {
        always {
            // Cleanup Docker resources
            echo "Cleaning up local Docker resources"
            sh '''
            docker rm $(docker ps -a -q --filter name=test-${APP_NAME}) || true
            docker rmi ${APP_NAME}:${IMAGE_TAG} || true
            '''
        }
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}

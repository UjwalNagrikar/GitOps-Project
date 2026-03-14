// Jenkinsfile
pipeline 
    agent any

    environment {
        DOCKER_USERNAME    = 'ujwalnagrikar'
        IMAGE_NAME         = 'pipeline-monitor'
        GITHUB_REPO        = 'https://github.com/ujwalnagrikar/GitOps-Project.git'
        GITHUB_REPO_NAME   = 'GitOps-Project'
    }

    stages {

 
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-credentials',
                    url: "${GITHUB_REPO}"
            }
        }

 
        stage('Set Image Tag') {
            steps {
                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        
        stage('Build Docker Image') {
            steps {
                echo '🔨 Building Docker image...'
                sh """
                    docker build -t ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} \
                                 -t ${DOCKER_USERNAME}/${IMAGE_NAME}:latest \
                                 ./app
                """
            }
        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
                        docker logout
                    """
                }
            }
        }

  
        stage('Update deployment.yaml') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-credentials',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_PASS'
                )]) {
                    sh """
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@ci.com"

                        sed -i 's|image: ${DOCKER_USERNAME}/${IMAGE_NAME}:.*|image: ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}|g' deployment.yaml

                        grep 'image:' deployment.yaml

                        git add deployment.yaml
                        git commit -m "ci: update image tag to ${IMAGE_TAG} [jenkins]" || echo "No changes"
                        git push https://${GIT_USER}:${GIT_PASS}@github.com/ujwalnagrikar/${GITHUB_REPO_NAME}.git main
                    """
                }
            }
        }


        stage('Verify Deployment') {
            steps {
                sh """
                    kubectl get pods -l app=pipeline-monitor
                    
                    kubectl get svc pipeline-monitor-service

                    
                    kubectl describe pods -l app=pipeline-monitor | grep Image:
                """
            }
        }
    }

    post {
        success {
            echo """
            Image : ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}
            Repo  : ${GITHUB_REPO}
            """
        }
        failure {
        }
        always {
            // Clean up local docker images
            sh "docker rmi ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} || true"
            sh "docker rmi ${DOCKER_USERNAME}/${IMAGE_NAME}:latest || true"
        }
    }
}
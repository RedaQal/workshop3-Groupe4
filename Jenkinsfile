pipeline {
    agent any

    environment {
        IMAGE_NAME     = 'devsecops-app'
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        CONTAINER_NAME = 'devsecops-staging'
        DOCKER_NETWORK = 'devsecops'
        SONAR_HOST_URL = 'http://sonarqube:9000'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install & Build') {
            steps {
                sh 'npm ci'
                sh 'npm run build'
            }
        }

               stage('SAST') {
            failFast false   // let both scanners finish so you get both reports even if one fails
            parallel {

                stage('SonarQube') {
                    steps {
                        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                            sh '''
                                sonar-scanner \
                                  -Dsonar.host.url="$SONAR_HOST_URL" \
                                  -Dsonar.token="$SONAR_TOKEN" \
                                  -Dsonar.qualitygate.wait=true \
                                  -Dsonar.qualitygate.timeout=300
                            '''
                        }
                    }
                }

                stage('Semgrep') {
                    steps {
                        // --error makes semgrep exit with code 1 when it finds anything
                        sh '''
                            semgrep scan \
                              --config p/default \
                              --config p/nodejs \
                              --config p/owasp-top-ten \
                              --metrics=off \
                              --error \
                              --exclude node_modules --exclude .next \
                              --json-output=semgrep-report.json \
                              --sarif-output=semgrep.sarif \
                              .
                        '''
                    }
                }
            }
        }
        stage('SCA') {
            steps {
                withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                    sh '''
                        dependency-check.sh \
                          --project "devsecops-workshop" \
                          --scan . \
                          --exclude "**/.next/**" \
                          --exclude "**/.scannerwork/**" \
                          --data /var/jenkins_home/dependency-check-data \
                          --nvdApiKey "$NVD_API_KEY" \
                          --format HTML --format JSON \
                          --out dependency-check-report \
                          --failOnCVSS 7
                    '''
                }
            }
        }
        stage('Docker Build') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .'
            }
        }

        stage('Deploy Staging') {
            steps {
                sh '''
                    docker rm -f ${CONTAINER_NAME} || true
                    docker run -d \
                      --name ${CONTAINER_NAME} \
                      --network ${DOCKER_NETWORK} \
                      -p 3001:3000 \
                      ${IMAGE_NAME}:${IMAGE_TAG}

                    echo "Attente du démarrage de l'application..."
                    for i in $(seq 1 20); do
                      if curl -sf http://${CONTAINER_NAME}:3000/ > /dev/null; then
                        echo "Staging OK -> http://localhost:3001"
                        exit 0
                      fi
                      sleep 3
                    done
                    echo "Le staging n'a pas démarré"
                    docker logs ${CONTAINER_NAME}
                    exit 1
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'semgrep-report.json,semgrep.sarif,dependency-check-report/**', allowEmptyArchive: true
        }
    }
}

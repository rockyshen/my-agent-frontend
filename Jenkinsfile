pipeline {
    agent any

    triggers {
        githubPush()
    }

    options {
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
    }

    environment {
        PROJECT_DIR = '/opt/my-agent-frontend'
    }

    stages {
        stage('Pull & Deploy') {
            steps {
                sh '''#!/bin/bash
                    set -euo pipefail
                    git config --global --add safe.directory /opt/my-agent-frontend
                    cd "$PROJECT_DIR"
                    git fetch origin main
                    git reset --hard origin/main
                    bash deploy/build-pi.sh
                '''
            }
        }

        stage('Smoke') {
            steps {
                sh '''#!/bin/bash
                    set -euo pipefail
                    for i in $(seq 1 6); do
                      if curl -sf --max-time 10 http://127.0.0.1:8086/ | grep -qi 'html'; then
                        echo "Frontend smoke passed on attempt $i"
                        exit 0
                      fi
                      sleep 5
                    done
                    echo "Frontend smoke failed"
                    exit 1
                '''
            }
        }
    }

    post {
        failure {
            echo 'Deploy failed. Check build logs and /opt/my-agent-frontend/dist'
        }
    }
}

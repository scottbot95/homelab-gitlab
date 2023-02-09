pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh 'nix build .#prebuild'
            }
        }
    }
}
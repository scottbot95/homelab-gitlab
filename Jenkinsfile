pipeline {
  agent any

  stages {
    stage('Build') {
      steps {
        sh 'nix build .#prebuild'
      }
    }
    stage('Approve Changes') {
      steps {
        sh 'nix run .#plan -- -out ./plan.tf'
        input 'Deploy changes?'
      }
    }
    stage('Deploy') {
      steps {
        sh 'nix run .#apply -- ./plan.tf'
      }
    }
  }
}
#!/bin/bash
# Install dependencies
sudo apt-get install jq
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
chmod +x AWSCLIV2.pkg
sudo installer -pkg AWSCLIV2.pkg -target /
chmod +x kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
kubectl version --client

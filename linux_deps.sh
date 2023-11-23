#!/bin/bash
# Install dependencies
if ! command -v helm &> /dev/null
then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
if ! command -v jq &> /dev/null
then
    sudo apt-get install jq
fi
if ! command -v kubectl &> /dev/null
then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    kubectl version --client
fi

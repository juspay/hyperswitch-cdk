#!/bin/bash

if ! command -v node &> /dev/null
then
    echo "node could not be found. Please install Node.js 18 or above."
    exit 1
fi
version=$(node -v | cut -d'.' -f1 | tr -d 'v')
if [ "$version" -lt 18 ]
then
    echo "Invalid Node.js version. Expected 18 or above, but got $version."
    exit 1
fi
if aws --version; then
    echo "##########################################"
    echo AWS CLI installed
    echo "##########################################"
else
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
fi
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found. Please rerun \`sh install.sh\` with Sudo access"
    exit 1
fi
sudo npm install -g aws-cdk
cdk --version
npm install

os=$(uname)
if [ "$os" = "Linux" ]; then
    sh linux_deps.sh
elif [ "$os" = "Darwin" ]; then
    sh mac_deps.sh
else
    echo "Unsupported operating system."
    exit 1
fi


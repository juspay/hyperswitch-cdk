#! /usr/bin/env bash
set -uo pipefail

if ! command -v brew &> /dev/null
then
    echo "Homebrew could not be found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if ! command -v helm &> /dev/null
then
    brew install helm
    brew link helm
fi
if ! command -v jq &> /dev/null
then
    brew install jq
    brew link jq
fi
if ! command -v kubectl &> /dev/null
then
    brew install kubectl
fi
# Check and Install AWS CLI
if ! command -v aws &> /dev/null
then
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
fi

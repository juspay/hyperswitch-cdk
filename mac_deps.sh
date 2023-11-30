#!/bin/bash
if ! command -v brew &> /dev/null
then
    echo "Homebrew could not be found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if ! command -v helm &> /dev/null
then
    brew install helm
fi
if ! command -v jq &> /dev/null
then
    brew install jq
fi
if ! command -v kubectl &> /dev/null
then
    brew install kubectl
fi

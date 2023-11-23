#!/bin/bash
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
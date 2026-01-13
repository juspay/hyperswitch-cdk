#!/bin/bash

# Hyperswitch Image Pull Diagnostic Script
# Run this if you encounter ImagePullBackOff errors

set -e

echo "=========================================="
echo "Hyperswitch ImagePullBackOff Diagnostics"
echo "=========================================="
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ ERROR: kubectl is not configured or cluster is not accessible"
    echo "Run: aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name hs-eks-cluster"
    exit 1
fi

echo "✅ kubectl is configured"
echo ""

# Check for ImagePullBackOff pods
echo "📦 Checking for pods with ImagePullBackOff..."
FAILING_PODS=$(kubectl get pods -A | grep -i "ImagePullBackOff\|ErrImagePull" || echo "")

if [ -z "$FAILING_PODS" ]; then
    echo "✅ No pods with ImagePullBackOff found"
else
    echo "❌ Found pods with image pull issues:"
    echo "$FAILING_PODS"
    echo ""

    # Get details of first failing pod
    FIRST_POD=$(echo "$FAILING_PODS" | head -1 | awk '{print $2}')
    FIRST_NAMESPACE=$(echo "$FAILING_PODS" | head -1 | awk '{print $1}')

    echo "📝 Detailed info for pod: $FIRST_POD in namespace: $FIRST_NAMESPACE"
    kubectl describe pod $FIRST_POD -n $FIRST_NAMESPACE | grep -A 10 "Events:"
    echo ""
fi

# Check ECR repositories
echo "📦 Checking ECR repositories..."
REGION=${AWS_DEFAULT_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

REQUIRED_REPOS=(
    "juspaydotin/hyperswitch-router"
    "juspaydotin/hyperswitch-producer"
    "juspaydotin/hyperswitch-consumer"
    "juspaydotin/hyperswitch-control-center"
    "grafana/grafana"
    "grafana/loki"
    "bitnami/metrics-server"
    "istio/proxyv2"
    "istio/pilot"
)

echo "Checking required ECR repositories..."
for repo in "${REQUIRED_REPOS[@]}"; do
    if aws ecr describe-repositories --repository-names "$repo" --region $REGION &> /dev/null; then
        IMAGE_COUNT=$(aws ecr list-images --repository-name "$repo" --region $REGION --query 'length(imageIds)' --output text)
        echo "✅ $repo (images: $IMAGE_COUNT)"
    else
        echo "❌ MISSING: $repo"
    fi
done
echo ""

# Check node IAM permissions
echo "🔑 Checking node IAM permissions..."
NODE_ROLE=$(aws eks describe-nodegroup --cluster-name hs-eks-cluster --nodegroup-name hs-nodegroup --region $REGION --query 'nodegroup.nodeRole' --output text 2>/dev/null || echo "")

if [ -z "$NODE_ROLE" ]; then
    echo "⚠️  Could not retrieve node role"
else
    echo "Node Role: $NODE_ROLE"
    ROLE_NAME=$(echo $NODE_ROLE | awk -F'/' '{print $NF}')

    if aws iam list-attached-role-policies --role-name $ROLE_NAME | grep -q "AmazonEC2ContainerRegistryReadOnly"; then
        echo "✅ ECR read permission attached"
    else
        echo "❌ MISSING: AmazonEC2ContainerRegistryReadOnly policy"
        echo "   Fix: aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    fi
fi
echo ""

# Check CodeBuild status
echo "🏗️  Checking CodeBuild image mirroring status..."
BUILD_IDS=$(aws codebuild list-builds-for-project --project-name ECRImageTransfer --region $REGION --query 'ids[0]' --output text 2>/dev/null || echo "")

if [ "$BUILD_IDS" != "None" ] && [ -n "$BUILD_IDS" ]; then
    BUILD_STATUS=$(aws codebuild batch-get-builds --ids "$BUILD_IDS" --region $REGION --query 'builds[0].buildStatus' --output text)
    echo "Latest build status: $BUILD_STATUS"

    if [ "$BUILD_STATUS" != "SUCCEEDED" ]; then
        echo "⚠️  Image mirroring may not be complete"
        echo "   Check logs: aws codebuild batch-get-builds --ids $BUILD_IDS --region $REGION --query 'builds[0].logs.deepLink'"
    fi
else
    echo "⚠️  No CodeBuild history found"
fi
echo ""

# Check node readiness
echo "🖥️  Checking node status..."
kubectl get nodes
echo ""

# Summary
echo "=========================================="
echo "📋 Diagnostic Summary"
echo "=========================================="
echo ""
echo "Common fixes for ImagePullBackOff:"
echo ""
echo "1. CHECK FOR DOUBLE PREFIX ISSUE:"
echo "   Look for images like: docker.juspay.io/ecr/123.dkr.ecr.region.amazonaws.com/image"
echo "   This means global.imageRegistry is set incorrectly"
echo "   Fix: Ensure global.imageRegistry is empty string \"\" in Helm values"
echo ""
echo "2. Ensure CodeBuild completed successfully (check above)"
echo ""
echo "3. Verify all ECR repositories exist (check above)"
echo ""
echo "4. Check node IAM role has ECR read permission (check above)"
echo ""
echo "5. Manually pull image to test:"
echo "   kubectl run test --image=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/grafana/grafana --rm -it --restart=Never"
echo ""
echo "6. Check pod events for image path:"
echo "   kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 5 'Failed'"
echo ""
echo "7. Force delete and recreate pod:"
echo "   kubectl delete pod <POD_NAME> -n <NAMESPACE>"
echo ""
echo "8. Check Helm values for imageRegistry:"
echo "   helm get values hypers-v1 -n hyperswitch | grep imageRegistry"
echo "   helm get values loki -n loki | grep imageRegistry"
echo ""

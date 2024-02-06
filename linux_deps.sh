#! /usr/bin/env bash
set -uo pipefail

# Function to install jq based on the Linux distribution
install_jq() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y jq
                ;;
            centos|rhel|fedora)
                sudo yum install -y jq
                ;;
            sles|opensuse)
                sudo zypper install -y jq
                ;;
            arch)
                sudo pacman -S --noconfirm jq
                ;;
            alpine)
                sudo apk add jq
                ;;
            *)
                echo "Unsupported Linux Distribution for jq installation"
                exit 1
                ;;
        esac
    else
        echo "/etc/os-release not found. Cannot determine Linux distribution for jq installation."
        exit 1
    fi
}

# Install Helm
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install jq
if ! command -v jq &> /dev/null; then
    install_jq
fi

# Install node
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    node -v
fi

# Install rust
if ! command -v rust &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source $HOME/.cargo/env
    rustc --version
    cargo --version
fi

# Function to install kubectl
install_kubectl() {
    local arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            arch="amd64"
            ;;
        arm64)
            arch="arm64"
            ;;
        *)
            echo "Unsupported architecture: $arch"
            echo "Please install kubectl manually and rerun the script"
            exit 1
            ;;
    esac

    local kubectl_url="https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$arch/kubectl"
    curl -LO "$kubectl_url"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    kubectl version --client
}

# Install kubectl
if ! command -v kubectl &> /dev/null; then
    install_kubectl
fi

# Install AWS CLI
install_aws_cli() {
    local arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            arch="x86_64"
            ;;
        arm|arm64)
            arch="aarch64"
            ;;
        *)
            echo "Unsupported architecture: $arch"
            echo "Please install AWS CLI manually and rerun the script"
            exit 1
            ;;
    esac
    local download_url="https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip"
    curl "$download_url" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
}

if ! command -v aws &> /dev/null; then
    install_aws_cli
fi

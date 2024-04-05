#! /usr/bin/env bash
 
source ./bash/utils.sh
echo
printf "${bold}Installing Dependencies...${reset}\n"
echo

# Check for Node.js
echo "Checking for Node.js..."
if ! command -v node &>/dev/null; then
    echo "Node.js could not be found. Please install node js 18 or above."
    exit 1
fi

# Verify Node.js version
version=$(node -v | cut -d'.' -f1 | tr -d 'v')
if [ "$version" -lt 18 ]; then
    echo "Invalid Node.js version. Expected 18 or above, but got $version."
    exit 1
fi
echo "Node.js version is valid."

# Install AWS CDK
echo "Installing AWS CDK..."
npm install -g aws-cdk &
show_loader "Installing AWS CDK..."
echo "AWS CDK is installed successfully."

# Check for AWS CDK
if ! command -v cdk &>/dev/null; then
    echo "AWS CDK could not be found. Please rerun 'bash install.sh' with Sudo access and ensure the command is available within the \$PATH"
    exit 1
fi

# Determine OS and run respective dependency script
os=$(uname)
case "$os" in
"Linux")
    echo "Detecting operating system: Linux"
    (
        bash linux_deps.sh &
        show_loader "Running Linux dependencies script..."
    )
    ;;
"Darwin")
    echo "Detecting operating system: macOS"
    (
        bash mac_deps.sh &
        show_loader "Running macOS dependencies script..."
    )
    ;;
*)
    echo "Unsupported operating system."
    exit 1
    ;;
esac

# Check if AWS CLI installation was successful
if ! command -v aws &>/dev/null; then
    echo "AWS CLI could not be found. Please rerun 'bash install.sh' with Sudo access and ensure the command is available within the $PATH"
    exit 1
fi

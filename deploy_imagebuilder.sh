# Setting up color and style variables
bold=$(tput bold)
blue=$(tput setaf 4)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
reset=$(tput sgr0)
white=$(tput setaf 7)
term_width=$(tput cols)
box_width=60
padding="$(printf '%*s' $(( (term_width - box_width) / 2 )) '')"
box_line="$(printf '%*s' $box_width '')"
box_line="${box_line// /-}"

# Function to display error messages in red
display_error() {
    echo "${bold}${red}$1${reset}"
}

validate_ami() {
    output=$(aws ec2 describe-images --image-ids "$1" --query 'Images')
    if [ -z "$output" ]; then
        return 1
    else
        return 0
    fi
}

get_user_ami_id() {
    while true; do
        echo "Please enter the ID of the base image"
        read -s AMI_ID
        if validate_ami "$AMI_ID"; then
            AMI_OPTIONS="-c $AMI_ID"
            break
        fi
    done
}

get_user_choice() {
    while true; do
        read -r -p "Enter your choice [1-2]: " BASE_IMAGE_TYPE
        case $BASE_IMAGE_TYPE in
            1) echo "Hardened Amazon Linux Image Selected"; get_user_ami_id; break;;
            2) echo "Normal Amazon Linux Image Selected"; break;;
            *) echo "Invalid choice. Please enter 1 or 2.";;
        esac
    done
}

# Function to display a simple loading animation
show_loader() {
    local message=$1
    local pid=$!
    local delay=0.3
    local spinstr='|/-\\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r%s [%c]  " "$message" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%s [Done]   \n" "$message"
}

# Function to show installation options
show_install_options() {
    echo
    echo "${bold}Choose the base image type:${reset}"
    echo "${bold}${blue}1.${reset}${green}Hardened base Amazon Linux ${reset}"
    echo "${bold}${blue}2.${reset}${green}Normal Amazon Linux Image${reset}"
    echo
}
show_install_options
get_user_choice

# Check for Node.js
echo "Checking for Node.js..."
if ! command -v node &> /dev/null; then
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
npm install -g aws-cdk & show_loader "Installing AWS CDK..."
echo "AWS CDK is installed successfully."

# Check for AWS CDK
if ! command -v cdk &> /dev/null; then
    echo "AWS CDK could not be found. Please rerun 'bash install.sh' with Sudo access and ensure the command is available within the \$PATH"
    exit 1
fi

# Determine OS and run respective dependency script
os=$(uname)
case "$os" in
  "Linux")
    echo "Detecting operating system: Linux"
    (bash linux_deps.sh & show_loader "Running Linux dependencies script...")
    ;;
  "Darwin")
    echo "Detecting operating system: macOS"
    (bash mac_deps.sh & show_loader "Running macOS dependencies script...")
    ;;
  *)
    echo "Unsupported operating system."
    exit 1
    ;;
esac

# Check if AWS CLI installation was successful
if ! command -v aws &> /dev/null; then
    echo "AWS CLI could not be found. Please rerun 'bash install.sh' with Sudo access and ensure the command is available within the $PATH"
    exit 1
fi

echo "Dependency installation completed."
echo

AMI_OPTIONS=""

# Checking for AWS credentials
if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_SESSION_TOKEN" ]]; then
    display_error "Missing AWS credentials. Please configure the AWS CLI with your credentials."
    exit 1
else
    echo "${bold}${green}AWS credentials detected successfully.${reset}"
fi

# Trying to retrieve AWS account owner's details
if ! AWS_ACCOUNT_DETAILS_JSON=$(aws sts get-caller-identity 2>&1); then
    display_error "Unable to obtain AWS caller identity: $AWS_ACCOUNT_DETAILS_JSON"
    display_error "Check if your AWS credentials are expired and you have appropriate permissions."
    exit 1
fi

# Extracting and displaying account details
AWS_ACCOUNT_ID=$(echo "$AWS_ACCOUNT_DETAILS_JSON" | jq -r '.Account')
AWS_USER_ID=$(echo "$AWS_ACCOUNT_DETAILS_JSON" | jq -r '.UserId')
AWS_ARN=$(echo "$AWS_ACCOUNT_DETAILS_JSON" | jq -r '.Arn')
AWS_ROLE=$(aws sts get-caller-identity --query 'Arn' --output text | cut -d '/' -f 2)

# Function to print a line with padding
print_line() {
    echo "${padding}${blue}${white}$1${reset}"
}

# Displaying AWS account information in a "box"
echo "${padding}${box_line}"
echo
print_line "${bold}AWS Account Information:${reset}"
echo
print_line "Account ID: ${bold}$AWS_ACCOUNT_ID${reset}"
print_line "User ID: ${bold}$AWS_USER_ID${reset}"
print_line "Role: ${bold}$AWS_ROLE${reset}"
echo
echo "${padding}${box_line}"


# Ask consent to proceed with the aws account
while true; do
    read -r -p "Do you want to proceed with the above AWS account? [y/n]: " yn
    case $yn in
        [Yy]* ) echo "Proceeding with AWS account $AWS_ACCOUNT_ID"; break;;
        [Nn]* ) echo "Exiting..."; exit;;
        * ) echo "Please answer yes or no [y/n].";;
    esac
done

echo
echo "${blue}##########################################${reset}"
echo "${blue}    Checking neccessary permissions${reset}"
echo "${blue}##########################################${reset}"
echo

check_root_user() {
  AWS_ARN=$(aws sts get-caller-identity --output json | jq -r .Arn )
  if [[ $AWS_ARN == *":root"* ]]; then
    echo "ROOT user is not recommended. Please create a new user with AdministratorAccess and use their Access Token."
    exit 1
  fi
}

REQUIRED_POLICIES=("AdministratorAccess") # Add other necessary policies to this array
# Check if the current user is a root user
echo "Verifying that you're not using the AWS root account..."
echo "(For security reasons, it's best to avoid using the root account.)"
(check_root_user) & show_loader "Verifying root user status"

check_iam_policies() {
  USER_POLICIES=$(aws iam list-attached-role-policies --role-name "$AWS_ROLE" --output json | jq -r '.AttachedPolicies[].PolicyName')
  for policy in "${REQUIRED_POLICIES[@]}"; do
    if ! echo "$USER_POLICIES" | grep -q "$policy"; then
      echo "Required policy $policy is not attached to your user. Please attach this policy."
      exit 1
    fi
  done
  echo "All necessary permissions are in place."
}

# Check for specific IAM policies
echo "Checking for necessary IAM policies..."
(check_iam_policies) & show_loader "Verifying IAM policies"

check_default_vpc() {
    echo `aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[*].VpcId'` >> /dev/null

    if [ $? -ne 0 ]; then
        echo
        echo "${green}No default VPC found. Creating one...${reset}"
        echo
        aws ec2 create-default-vpc
    fi
}

(check_default_vpc) & show_loader "Checking if default VPC exist or not"

npm install
cdk bootstrap aws://"$AWS_ACCOUNT_ID"/"$AWS_DEFAULT_REGION" -c aws_arn="$AWS_ARN" -c stack=imagebuilder
cdk deploy --require-approval never -c stack=imagebuilder $AMI_OPTIONS

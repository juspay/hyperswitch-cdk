# HyperSwitch Full Stack Deployment

This project contains a script for deploying a full stack of HyperSwitch on AWS using the AWS Cloud Development Kit (CDK). The components installed by this script include:

- App Server
- Scheduler Services
- Admin Control Center
- Demo App with SDK Integration
- Card Vault
- Monitoring Services
- Automatically build and host SDK (Hyperloader.js)
- Jump Servers

## Installation

There are two ways to install the HyperSwitch Full Stack:

### 1. Single-Click Deployment

Click the button below to deploy the stack directly to AWS:

&emsp;&emsp; <a href="https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=HyperswitchBootstrap&templateURL=https://hyperswitch-synth.s3.eu-central-1.amazonaws.com/production.yaml"><img src="./images/aws_button.png" height="35"></a>

You will able to see the Hyperswitch services in the Hyperswitch Stack Output section once stack is deployed

Follow below steps to unlock card vault if you have opted for Card Vault.

1. Goto AWS console > CloudFormation > Stacks > HyperswitchBootstrap > Resources
2. Click on HyperswitchCDKBootstrapEC2 instance starting with physical id `i-{{random_id}}`
3. Open the instance and click on connect and login to the instance
4. Follow next steps [here](#card_vault)

### 2. Terminal Deployment

#### Prerequisites

Before you can use this script, you need to have the following installed:

- Git
- Node.js and npm

You also need to have an AWS account and configure your AWS credentials.

1. Clone this repository:

```bash
git clone https://github.com/juspay/hyperswitch-cdk.git
cd hyperswitch-cdk
```

2. Set your AWS credentials and region:

```bash
export AWS_DEFAULT_REGION=<Your AWS_REGION> // e.g., export AWS_DEFAULT_REGION=us-east-2
export AWS_ACCESS_KEY_ID=<Your Access_Key_Id> // e.g., export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=<Your Secret_Access_Key> // e.g., export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_SESSION_TOKEN="<Your AWS_SESSION_TOKEN>" //optional
```

3. Run the installation script:
    Execute <b>only one</b> of them based on your need.

    <details>
      <summary><b>Install all the services provided by hyperswitch</b></summary>
      <pre>sh install.sh</pre>
    </details>
    <details>
      <summary><b>Install only card vault as a seperate service</b></summary>
      <pre>sh install-locker.sh</pre>
    </details>
    <details>
      <summary><b>Standalone deployment script to deploy Hyperswitch on AWS quickly</b></summary>
      <pre>curl https://raw.githubusercontent.com/juspay/hyperswitch/main/aws/hyperswitch_aws_setup.sh | bash</pre>
  </details>


# <a name="card_vault"></a>Unlock Card Vault

If you are creating a card vault, you will need to unlock it so that it can start saving/retrieving cards. The CDK script creates an external and internal jump for security purposes, meaning you can only access the Card vault via the internal jump server. Follow the steps below to unlock the card vault:

1. Please check if you have configured AWS Access keys before running the below command

```bash
curl https://raw.githubusercontent.com/juspay/hyperswitch-cdk/main/locker.sh | bash
```

2. Run below command in the external jump server. This will log you into internal jump server

```bash
  sh external_jump.sh
```

3. Run below command in the internal jump server. This will log you into locker server

```bash
  sh internal_jump.sh
```

4. Run below command in the locker server. This will prompt for key1 and key2 that you created while creating master key for locker

```bash
  sh unlock_locker.sh
```

### More Information

For more information about each component and the full stack deployment, please refer to the [HyperSwitch Open Source Documentation](https://opensource.hyperswitch.io/hyperswitch-open-source/deploy-hyperswitch-on-aws/deploy-app-server/full-stack-deployment).

### Support

If you encounter any issues or need further assistance, please create an issue in this repository.

### Todo

- [ ] Networking
  - [x] VPC
  - [ ] Subnets
  - [ ] NAT
  - [ ] Route Table
  - [ ] IGW
- [ ] Load Balancers
- [ ] Auto Scaling Groups
- [ ] Launch Templates
- [ ] RDS
- [ ] ElastiCache
- [ ] S3
- [ ] EKS
- [ ] Service Endpoints

### Decisions

- [ ] How should we have the subnet distribution?
  1. Similar to how we currently have in production

### Subnet design

We can consist of 4 Subnets

1. Public Incoming - (consisting of 1 subnet per AZ)
2. DMZ - (consisting of 1 subnet per AZ) (non-public)
3. Application - (consisting of 1 subnet per AZ) (isolated)
4. Storage Layer - (consisting of 1 subnet per AZ) (isolated)
5. Outbound - (consisting of 1 subnet per AZ) (connected to igw)

#### Structure

- api-public (exist in 1)
- envoy (exist in 2)
- external jump (exists in 2)
- EKS exists in (3)
- Internal Jump (3)
- squid (4)

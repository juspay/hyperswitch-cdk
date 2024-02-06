# HyperSwitch Full Stack Deployment Guide

This guide outlines the process for deploying a comprehensive HyperSwitch stack on AWS, leveraging the power and flexibility of the AWS Cloud Development Kit (CDK). Follow our step-by-step [installation instructions](#installation) to get HyperSwitch up and running efficiently.

## Table of Contents
- [Installation](#installation)
- [App Server](#app-server)
- [Scheduler Services](#scheduler-services)
- [Admin Control Center](#admin-control-center)
- [Demo App with SDK Integration](#demo-app-with-sdk-integration)
- [Card Vault](#card-vault)
- [Monitoring Services](#monitoring-services)
- [Automatically Build and Host SDK (Hyperloader.js)](#automatically-build-and-host-sdk)
- [Jump Servers](#jump-servers)
- [Image Builder](#image-builder)

### App Server
The cornerstone of the HyperSwitch architecture, the App Server facilitates backend operations. Built in Rust, HyperSwitch is an innovative, open-source payment switch offering a unified API for global payment ecosystem access in over 130 countries. [Learn more](https://github.com/juspay/hyperswitch).

### Scheduler Services
These services are responsible for the scheduling and execution of tasks, ensuring timely operations across the HyperSwitch stack.

### Admin Control Center
Manage and monitor your HyperSwitch environment with ease using the Admin Control Center, a unified dashboard for comprehensive control. [Learn more](https://github.com/juspay/hyperswitch-control-center).

### Demo App with SDK Integration
Explore the capabilities of HyperSwitch through our Demo App, which demonstrates the seamless integration of the HyperSwitch SDK.

### Card Vault
Our Card Vault provides a secure repository for storing sensitive card information, ensuring data safety and compliance.

### Monitoring Services
Dedicated to maintaining the health and performance of the HyperSwitch stack, these services ensure your system remains robust and reliable.

### Automatically Build and Host SDK (Hyperloader.js)
Hyperloader.js simplifies SDK deployment, offering automatic build and hosting capabilities for the HyperSwitch SDK. [Learn more](https://github.com/juspay/hyperswitch-web)

### Jump Servers
Enhance your security posture with Jump Servers, designed to provide secure access to the HyperSwitch stack.

## Installation

#### Prerequisites

Before you can use this script, you need to have the following installed:

- Git
- Node.js and npm
- AWS account with Administrator access

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
      <pre>bash install.sh</pre>
    </details>
    <details>
      <summary><b>Install only card vault as a seperate service</b></summary>
      <pre>bash install-locker.sh</pre>
    </details>
    <details>
      <summary><b>Install only Image builder as a seperate service</b></summary>
      <pre>bash deploy_imagebuilder.sh</pre>
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

# Image Builder (Outgoing and Incoming Proxy)

The imagebuilder component builds images for outgoing and incoming proxy(Squid and Envoy). Optionally you can choose to have hardened base image. You can buy the base image from [here](https://aws.amazon.com/marketplace/pp/prodview-53aklkzclj3wi?sr=0-1&ref_=beagle&applicationId=AWSMPContessa).

Currently supported platforms:
- Amazon Linux 2

## Deploying

```bash 
   bash deploy_image_builder.sh
```

### More Information

For more information about each component and the full stack deployment, please refer to the [HyperSwitch Open Source Documentation](https://opensource.hyperswitch.io/hyperswitch-open-source/deploy-hyperswitch-on-aws/deploy-app-server/full-stack-deployment).

### Support

If you encounter any issues or need further assistance, please create an issue in this repository.
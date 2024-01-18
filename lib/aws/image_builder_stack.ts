import * as cdk from "aws-cdk-lib";
import * as image_builder from "aws-cdk-lib/aws-imagebuilder"
import * as iam from "aws-cdk-lib/aws-iam";
import { MachineImage } from 'aws-cdk-lib/aws-ec2';

import { Vpc } from './networking';
import { Construct } from "constructs";
import { ImageBuilderConfig, VpcConfig } from "./config";
import { Bucket } from "aws-cdk-lib/aws-s3";
import { BucketDeployment, Source } from "aws-cdk-lib/aws-s3-deployment";
import { readFileSync } from "fs";

export class ImageBuilderStack extends cdk.Stack {
    constructor(scope: Construct, config: ImageBuilderConfig) {
        super(scope, config.name, {
            // env: {
            //   account: process.env.CDK_DEFAULT_ACCOUNT,
            //   region: process.env.CDK_DEFAULT_REGION
            // },
            stackName: config.name,
        });

        let vpcConfig: VpcConfig = {
            name: "imagebuilder-vpc",
            availabilityZones: [process.env.CDK_DEFAULT_REGION + "a", process.env.CDK_DEFAULT_REGION + "b"]
        };

        let vpc = new Vpc(this, vpcConfig);
        let role = new iam.Role(this, "StationRole", { roleName: "StationRole", assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com") })

        role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
        role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("EC2InstanceProfileForImageBuilder"))

        const base_image_arn = MachineImage.latestAmazonLinux2().getImage(this).imageId;

        const component = new image_builder.CfnComponent(this, "install_squid_component", {
            name: "HyperswitchSquidImageBuilder",
            description: "Image builder for squid",
            platform: "Linux",
            version: "1.0.1",
            data: readFileSync("./components/squid.yml").toString(),
        })
        let instance_profile = new iam.CfnInstanceProfile(this, "SquidStationProfile", { instanceProfileName: "SquidStationInstanceProfile", roles: ["StationRole"] })

        const squid_recipe = new image_builder.CfnImageRecipe(this, "SquidImageRecipe", {
            name: "SquidImageRecipe",
            version: "1.0.3",
            components: [
                { "componentArn": component.attrArn }
            ],
            parentImage: base_image_arn
        })

        let squid_infra_config = new image_builder.CfnInfrastructureConfiguration(this, "SquidInfraConfig", {
            name: "SquidInfraConfig",
            instanceTypes: ["t3.medium"],
            instanceProfileName: "SquidStationInstanceProfile"
        })
        squid_infra_config.addDependency(instance_profile)

        let pipeline = new image_builder.CfnImagePipeline(this, "SquidImagePipeline", {
            name: "SquidImagePipeLine",
            imageRecipeArn: squid_recipe.attrArn,
            infrastructureConfigurationArn: squid_infra_config.attrArn
        })

        pipeline.addDependency(squid_infra_config)

        const envoy_component = new image_builder.CfnComponent(this, "install_envoy_component", {
            name: "HyperswitchEnvoyImageBuilder",
            description: "Image builder for Envoy",
            platform: "Linux",
            version: "1.0.1",
            data: readFileSync("./components/envoy.yml").toString(),
        })

        const envoy_recipe = new image_builder.CfnImageRecipe(this, "EnvoyImageRecipe", {
            name: "EnvoyImageRecipe",
            version: "1.0.3",
            components: [
                { "componentArn": envoy_component.attrArn }
            ],
            parentImage: base_image_arn
        })

        let envoy_instance_profile = new iam.CfnInstanceProfile(this, "EnvoyStationProfile", { instanceProfileName: "EnvoyStationInstanceProfile", roles: ["StationRole"] })

        let envoy_infra_config = new image_builder.CfnInfrastructureConfiguration(this, "EnvoyInfraConfig", {
            name: "EnvoyInfraConfig",
            instanceTypes: ["t3.medium"],
            instanceProfileName: "EnvoyStationInstanceProfile"
        })
        envoy_infra_config.addDependency(envoy_instance_profile)

        let envoy_pipeline = new image_builder.CfnImagePipeline(this, "EnvoyImagePipeline", {
            name: "EnvoyImagePipeLine",
            imageRecipeArn: envoy_recipe.attrArn,
            infrastructureConfigurationArn: envoy_infra_config.attrArn
        })

        envoy_pipeline.addDependency(envoy_infra_config)

    }
}

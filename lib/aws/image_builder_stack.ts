import * as cdk from "aws-cdk-lib";
import * as codebuild from "aws-cdk-lib/aws-codebuild";
import * as image_builder from "aws-cdk-lib/aws-imagebuilder"
import * as iam from "aws-cdk-lib/aws-iam";
import * as ec2 from 'aws-cdk-lib/aws-ec2';

import { Construct } from "constructs";
import { ImageBuilderConfig } from "./config";
import { Bucket } from "aws-cdk-lib/aws-s3";
import { BucketDeployment, Source } from "aws-cdk-lib/aws-s3-deployment";

export class ImageBuilderStack extends cdk.Stack {
    constructor(scope: Construct, config: ImageBuilderConfig) {
        super(scope, config.name, {
            // env: {
            //   account: process.env.CDK_DEFAULT_ACCOUNT,
            //   region: process.env.CDK_DEFAULT_REGION
            // },
            stackName: config.name,
        });

        const base_image_arn = codebuild.LinuxBuildImage.AMAZON_LINUX_2_5.imageId;

        // Upload images to S3
        const bucket = new Bucket(this, "hyperswitch_image_components", { enforceSSL: true });

        const source = Source.asset('./components')
        new BucketDeployment(this, "hyperswitch_component_deployment", {
            sources: [source],
            destinationBucket: bucket
        })

        // Squid Image Pipeline
        const bucket_url = 's3://hyperswitch_image_components/components'
        const squid_uri = bucket_url + 'squid.yml'

        const component = new image_builder.CfnComponent(this, "install_squid_component", {
            name: "HyperswitchSquidImageBuilder",
            description: "Image builder for squid",
            platform: "Linux",
            version: "1.0.1",
            uri: squid_uri
        })

        let role = new iam.Role(this, "SquidStationRole", { roleName: "SquidStationRole", assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com") })

        role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
        role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("EC2InstanceProfileForImageBuilder"))

        let instance_profile = new iam.CfnInstanceProfile(this, "SquidStationProfile", { instanceProfileName: "SquidStationInstanceProfile", roles: ["SquidStationRole"] })

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


        // Envoy Image Pipeline
        const envoy_uri = bucket_url + 'envoy.yml'

        const envoy_component = new image_builder.CfnComponent(this, "install_envoy_component", {
            name: "HyperswitchSquidImageBuilder",
            description: "Image builder for squid",
            platform: "Linux",
            version: "1.0.1",
            uri: envoy_uri
        })

        const envoy_recipe = new image_builder.CfnImageRecipe(this, "EnvoyImageRecipe", {
            name: "EnvoyImageRecipe",
            version: "1.0.3",
            components: [
                { "componentArn": envoy_component.attrArn }
            ],
            parentImage: base_image_arn
        })

        let envoy_role = new iam.Role(this, "EnvoyStationRole", { roleName: "EnvoyStationRole", assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com") })

        envoy_role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
        envoy_role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("EC2InstanceProfileForImageBuilder"))

        let envoy_instance_profile = new iam.CfnInstanceProfile(this, "EnvoyStationProfile", { instanceProfileName: "EnvoyStationInstanceProfile", roles: ["EnvoyStationRole"] })

        let envoy_infra_config = new image_builder.CfnInfrastructureConfiguration(this, "EnvoyInfraConfig", {
            name: "EnvoyInfraConfig",
            instanceTypes: ["t3.medium"],
            instanceProfileName: "EnvoyStationInstanceProfile"
        })
        squid_infra_config.addDependency(envoy_instance_profile)

        let envoy_pipeline = new image_builder.CfnImagePipeline(this, "EnvoyImagePipeline", {
            name: "EnvoyImagePipeLine",
            imageRecipeArn: envoy_recipe.attrArn,
            infrastructureConfigurationArn: envoy_infra_config.attrArn
        })

        envoy_pipeline.addDependency(envoy_infra_config)

    }
}

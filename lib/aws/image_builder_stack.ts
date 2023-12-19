import * as cdk from "aws-cdk-lib";

import * as image_builder from "aws-cdk-lib/aws-imagebuilder"
import * as iam from "aws-cdk-lib/aws-iam";

import { Construct } from "constructs";
import { Config } from "./config";
import { Bucket } from "aws-cdk-lib/aws-s3";
import { BucketDeployment, Source } from "aws-cdk-lib/aws-s3-deployment";

export class ImageBuilderStack extends cdk.Stack {
    constructor(scope: Construct, config: Config, base_image_arn: string) {
        super(scope, config.stack.name, {
            // env: {
            //   account: process.env.CDK_DEFAULT_ACCOUNT,
            //   region: process.env.CDK_DEFAULT_REGION
            // },
            stackName: config.stack.name,
        });

        // Upload images to S3
        const bucket = new Bucket(scope, "hyperswitch_image_components", { enforceSSL: true });

        const source = Source.asset('./components')
        new BucketDeployment(scope, "hyperswitch_component_deployment", {
            sources: [source],
            destinationBucket: bucket
        })

        // Squid Image Pipeline
        const bucket_url = 's3://hyperswitch-component-bucket/components'
        const squid_uri = bucket_url + 'squid.yml'

        const component = new image_builder.CfnComponent(scope, "install_squid_component", {
            name: "HyperswitchSquidImageBuilder",
            description: "Image builder for squid",
            platform: "Linux",
            version: "1.0.1",
            uri: squid_uri
        })

        let role = new iam.Role(scope, "SquidStationRole", { roleName: "SquidStationRole", assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com") })

        role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
        role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("EC2InstanceProfileForImageBuilder"))

        let instance_profile = new iam.CfnInstanceProfile(scope, "SquidStationProfile", { instanceProfileName: "SquidStationInstanceProfile", roles: ["SquidStationRole"] })

        const squid_recipe = new image_builder.CfnImageRecipe(scope, "SquidImageRecipe", {
            name: "SquidImageRecipe",
            version: "1.0.3",
            components: [
                { "componentArn": component.attrArn }
            ],
            parentImage: base_image_arn
        })

        let squid_infra_config = new image_builder.CfnInfrastructureConfiguration(scope, "SquidInfraConfig", {
            name: "SquidInfraConfig",
            instanceTypes: ["t3.medium"],
            instanceProfileName: "SquidInfraConfigName"
        })
        squid_infra_config.addDependency(instance_profile)

        let pipeline = new image_builder.CfnImagePipeline(scope, "SquidImagePipeline", {
            name: "SquidImagePipeLine",
            imageRecipeArn: squid_recipe.attrArn,
            infrastructureConfigurationArn: squid_infra_config.attrArn
        })

        pipeline.addDependency(squid_infra_config)


        // Envoy Image Pipeline
        const envoy_uri = bucket_url + 'envoy.yml'

        const envoy_component = new image_builder.CfnComponent(scope, "install_squid_component", {
            name: "HyperswitchSquidImageBuilder",
            description: "Image builder for squid",
            platform: "Linux",
            version: "1.0.1",
            uri: envoy_uri
        })

        const envoy_recipe = new image_builder.CfnImageRecipe(scope, "EnvoyImageRecipe", {
            name: "EnvoyImageRecipe",
            version: "1.0.3",
            components: [
                { "componentArn": envoy_component.attrArn }
            ],
            parentImage: base_image_arn
        })

        let envoy_role = new iam.Role(scope, "EnvoyStationRole", { roleName: "EnvoyStationRole", assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com") })

        envoy_role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
        envoy_role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("EC2InstanceProfileForImageBuilder"))

        let envoy_instance_profile = new iam.CfnInstanceProfile(scope, "EnvoyStationProfile", { instanceProfileName: "EnvoyStationInstanceProfile", roles: ["EnvoyStationRole"] })

        let envoy_infra_config = new image_builder.CfnInfrastructureConfiguration(scope, "EnvoyInfraConfig", {
            name: "EnvoyInfraConfig",
            instanceTypes: ["t3.medium"],
            instanceProfileName: "EnvoyInfraConfigName"
        })
        squid_infra_config.addDependency(envoy_instance_profile)

        let envoy_pipeline = new image_builder.CfnImagePipeline(scope, "EnvoyImagePipeline", {
            name: "EnvoyImagePipeLine",
            imageRecipeArn: envoy_recipe.attrArn,
            infrastructureConfigurationArn: envoy_infra_config.attrArn
        })

        envoy_pipeline.addDependency(envoy_infra_config)

    }
}

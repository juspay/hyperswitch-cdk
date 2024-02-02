import * as cdk from "aws-cdk-lib";
import * as image_builder from "aws-cdk-lib/aws-imagebuilder"
import * as iam from "aws-cdk-lib/aws-iam";

import { Vpc } from './networking';
import { Construct } from "constructs";
import { ImageBuilderConfig, VpcConfig } from "./config";
import { MachineImage } from 'aws-cdk-lib/aws-ec2';

import { readFileSync } from "fs";

type ImageBuilderProperties = {
    pipeline_name: string;
    recipe_name: string;
    profile_name: string;
    comp_name: string;
    comp_id: string;
    infra_config_name: string;
    baseimageArn: string;
    description: string;
    compFilePath: string;
}

function CreateImagePipeline(
    stack: ImageBuilderStack,
    role: iam.Role,
    props: ImageBuilderProperties,
) {
    const component = new image_builder.CfnComponent(stack, props.comp_id, {
        name: props.comp_name,
        description: props.description,
        platform: "Linux",
        version: "1.0.1",
        data: readFileSync(props.compFilePath).toString(),
    })
    let instance_profile = new iam.CfnInstanceProfile(stack, props.profile_name, { instanceProfileName: props.profile_name, roles: [role.roleName] })

    const squid_recipe = new image_builder.CfnImageRecipe(stack, props.recipe_name, {
        name: props.recipe_name,
        version: "1.0.3",
        components: [
            { "componentArn": component.attrArn }
        ],
        parentImage: props.baseimageArn,
    })

    let squid_infra_config = new image_builder.CfnInfrastructureConfiguration(stack, props.infra_config_name, {
        name: props.infra_config_name,
        instanceTypes: ["t3.medium"],
        instanceProfileName: props.profile_name,
    })
    squid_infra_config.addDependency(instance_profile)

    let pipeline = new image_builder.CfnImagePipeline(stack, props.pipeline_name, {
        name: props.pipeline_name,
        imageRecipeArn: squid_recipe.attrArn,
        infrastructureConfigurationArn: squid_infra_config.attrArn
    })

    pipeline.addDependency(squid_infra_config)
}

export class ImageBuilderStack extends cdk.Stack {
    constructor(scope: Construct, config: ImageBuilderConfig) {
        super(scope, config.name, {
            stackName: config.name,
        });

        let vpcConfig: VpcConfig = {
            name: "imagebuilder-vpc",
            maxAzs: 2,
        };

        let vpc = new Vpc(this, vpcConfig);
        let role = new iam.Role(this, "StationRole", { roleName: "StationRole", assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com") })

        role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore"))
        role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("EC2InstanceProfileForImageBuilder"))

        const base_image_id = config.ami_id || MachineImage.latestAmazonLinux2().getImage(this).imageId

        let squid_properties = {
            pipeline_name: "SquidImagePipeline",
            recipe_name: "SquidImageRecipe",
            profile_name: "SquidStationInstanceProfile",
            comp_name: "HyperswitchSquidImageBuilder",
            comp_id: "install_squid_component",
            infra_config_name: "SquidInfraConfig",
            baseimageArn: base_image_id,
            description: "Image builder for squid",
            compFilePath: "./components/squid.yml",
        };

        CreateImagePipeline(
            this,
            role,
            squid_properties,
        )

        let envoy_properties = {
            pipeline_name: "EnvoyImagePipeline",
            recipe_name: "EnvoyImageRecipe",
            profile_name: "EnvoyStationProfile",
            comp_name: "HyperswitchEnvoyImageBuilder",
            comp_id: "install_envoy_component",
            infra_config_name: "EnvoyInfraConfig",
            baseimageArn: base_image_id,
            description: "Image builder for Envoy",
            compFilePath: "./components/envoy.yml",
        };

        CreateImagePipeline(
            this,
            role,
            envoy_properties,
        )
    }
}

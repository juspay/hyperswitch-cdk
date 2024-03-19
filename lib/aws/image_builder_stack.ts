import * as cdk from "aws-cdk-lib";
import * as image_builder from "aws-cdk-lib/aws-imagebuilder"
import * as iam from "aws-cdk-lib/aws-iam";

import { Function, Runtime, Code } from "aws-cdk-lib/aws-lambda";
import { LambdaSubscription } from 'aws-cdk-lib/aws-sns-subscriptions';
import { Vpc } from './networking';
import { Topic } from 'aws-cdk-lib/aws-sns';
import { Construct } from "constructs";
import { ImageBuilderConfig, VpcConfig } from "./config";
import { aws_logs as logs } from 'aws-cdk-lib';
import { MachineImage, SubnetType, SecurityGroup } from 'aws-cdk-lib/aws-ec2';

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
    snsTopicArn: string;
    subnetId: string;
    sgId: string;

}

type RecordLambdaProperties = {
    name: string;
    id: string;
    role: iam.Role;
    ssm_key: string;
    topic: Topic,
}

function CreateImagePipeline(
    stack: ImageBuilderStack,
    role: iam.Role,
    props: ImageBuilderProperties,
): string {
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
        snsTopicArn: props.snsTopicArn,
        subnetId: props.subnetId,
        securityGroupIds: [props.sgId]
    })
    squid_infra_config.addDependency(instance_profile)

    let pipeline = new image_builder.CfnImagePipeline(stack, props.pipeline_name, {
        name: props.pipeline_name,
        imageRecipeArn: squid_recipe.attrArn,
        infrastructureConfigurationArn: squid_infra_config.attrArn
    })

    pipeline.addDependency(squid_infra_config)
    return pipeline.attrArn

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

        const envoy_channel = new Topic(this, 'ImgBuilderNotificationTopicEnvoy', {});
        const squid_channel = new Topic(this, 'ImgBuilderNotificationTopicSquid', {});
        const base_channel = new Topic(this, 'ImgBuilderNotificationTopicBase', {});

        let vpc = new Vpc(this, vpcConfig);

        let subnetId = vpc.vpc.selectSubnets({ subnetType: SubnetType.PUBLIC }).subnetIds[0];
        let ib_SG = new SecurityGroup(this, 'image-server-sg', {
            vpc: vpc.vpc,
            allowAllOutbound: true,
            description: 'security group for a image builder server',
        });

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
            sgId: ib_SG.securityGroupId,
            subnetId: subnetId,
            snsTopicArn: squid_channel.topicArn,
        };

        let envoy_arn = CreateImagePipeline(
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
            sgId: ib_SG.securityGroupId,
            subnetId: subnetId,
            snsTopicArn: envoy_channel.topicArn,
        };

        let squid_arn = CreateImagePipeline(
            this,
            role,
            envoy_properties,
        )


        let base_properties = {
            pipeline_name: "BaseImagePipeline",
            recipe_name: "BaseImageRecipe",
            profile_name: "BaseStationProfile",
            comp_name: "HyperswitchBaseImageBuilder",
            comp_id: "install_base_component",
            infra_config_name: "BaseInfraConfig",
            baseimageArn: base_image_id,
            description: "Image builder for Base Image",
            compFilePath: "./components/base.yml",
            sgId: ib_SG.securityGroupId,
            subnetId: subnetId,
            snsTopicArn: base_channel.topicArn,
        };

        let base_arn = CreateImagePipeline(
            this,
            role,
            base_properties,
        )

        const start_ib_code = readFileSync(
            "lib/aws/lambda/start_ib.py",
        ).toString();


        const lambda_policy = new iam.PolicyDocument({
            statements: [
                new iam.PolicyStatement({
                    effect: iam.Effect.ALLOW,
                    actions: ['imagebuilder:StartImagePipelineExecution'],
                    resources: [
                        `arn:aws:imagebuilder:${cdk.Stack.of(this).region}:${cdk.Stack.of(this).account
                        }:image/*`,
                        `arn:aws:imagebuilder:${cdk.Stack.of(this).region}:${cdk.Stack.of(this).account
                        }:image-pipeline/*`,
                    ],
                }),
                new iam.PolicyStatement({
                    effect: iam.Effect.ALLOW,
                    actions: ['ssm:*'],
                    resources: ["*"],
                }),
            ],
        });

        const lambda_role = new iam.Role(this, "hyperswitch-ib-lambda-role", {
            assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
            inlinePolicies: {
                "ib-start-role": lambda_policy,
            },
        });

        const ib_lambda = new Function(this, "hyperswitch-ib-lambda", {
            functionName: "HyperswitchIbStartLambda",
            runtime: Runtime.PYTHON_3_9,
            handler: "index.lambda_handler",
            code: Code.fromInline(start_ib_code),
            timeout: cdk.Duration.minutes(15),
            role: lambda_role,
            environment: {
                envoy_image_pipeline_arn: envoy_arn,
                squid_image_pipeline_arn: squid_arn,
                base_image_pipeline_arn: base_arn,
            },
        });


        const triggerIbStart = new cdk.CustomResource(
            this,
            "HyperswitchIbStart",
            {
                serviceToken: ib_lambda.functionArn,
            },
        );

        addRecordLambda(this, {
            id: "hyperswitch-record-amid-squid",
            name: "HyperswitchRecordAmiIdSquid",
            role: lambda_role,
            topic: squid_channel,
            ssm_key: "squid_image_ami",
        })

        addRecordLambda(this, {
            id: "hyperswitch-record-amid-envoy",
            name: "HyperswitchRecordAmiIdEnvoy",
            role: lambda_role,
            topic: envoy_channel,
            ssm_key: "envoy_image_ami",
        })

        addRecordLambda(this, {
            id: "hyperswitch-record-amid-base",
            name: "HyperswitchRecordAmiIdBase",
            role: lambda_role,
            topic: base_channel,
            ssm_key: "base_image_ami",
        })
    }
}


function addRecordLambda(stack: cdk.Stack, props: RecordLambdaProperties) {
    const record_amid_code = readFileSync(
        "lib/aws/lambda/record_ami.py"
    ).toString();

    let ib_record_function = new Function(stack, props.id, {
        functionName: props.name,
        runtime: Runtime.PYTHON_3_9,
        handler: "index.lambda_handler",
        code: Code.fromInline(record_amid_code),
        timeout: cdk.Duration.minutes(15),
        role: props.role,
        environment: {
            IMAGE_SSM_NAME: props.ssm_key,
        },
    });

    props.topic.addSubscription(new LambdaSubscription(ib_record_function))
}

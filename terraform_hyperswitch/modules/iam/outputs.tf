output "image_builder_ec2_role_arn" {
  description = "ARN of the IAM role for EC2 Image Builder instances."
  value       = aws_iam_role.image_builder_ec2_role[0].arn
  depends_on  = [aws_iam_role.image_builder_ec2_role]
}

output "image_builder_ec2_instance_profile_name" {
  description = "Name of the IAM instance profile for EC2 Image Builder instances."
  value       = aws_iam_instance_profile.image_builder_ec2_profile[0].name
  depends_on  = [aws_iam_instance_profile.image_builder_ec2_profile]
}

output "eks_nodegroup_role_arn" {
  description = "ARN of the IAM role for EKS Node Groups."
  value       = aws_iam_role.eks_nodegroup_role[0].arn
  depends_on  = [aws_iam_role.eks_nodegroup_role]
}

output "eks_hyperswitch_service_account_role_arn" {
  description = "ARN of the IAM role for the Hyperswitch EKS service account."
  value       = aws_iam_role.eks_hyperswitch_app_sa_role[0].arn
  depends_on  = [aws_iam_role.eks_hyperswitch_app_sa_role]
}

output "eks_grafana_loki_service_account_role_arn" {
  description = "ARN of the IAM role for the Grafana/Loki EKS service account."
  value       = aws_iam_role.eks_grafana_loki_sa_role[0].arn
  depends_on  = [aws_iam_role.eks_grafana_loki_sa_role]
}

output "lambda_general_role_arn" {
  description = "ARN of the general IAM role for Lambda functions."
  value       = aws_iam_role.lambda_general_role[0].arn
  depends_on  = [aws_iam_role.lambda_general_role]
}

output "lambda_codebuild_trigger_role_arn" {
  description = "ARN of the IAM role for Lambda function that triggers CodeBuild."
  value       = aws_iam_role.lambda_codebuild_trigger_role[0].arn
  depends_on  = [aws_iam_role.lambda_codebuild_trigger_role]
}

output "codebuild_ecr_role_arn" {
  description = "ARN of the IAM role for CodeBuild ECR image transfer."
  value       = aws_iam_role.codebuild_ecr_role[0].arn
  depends_on  = [aws_iam_role.codebuild_ecr_role]
}

output "external_jump_ec2_role_arn" {
  description = "ARN of the IAM role for the external jump EC2 instance."
  value       = aws_iam_role.external_jump_ec2_role[0].arn
  depends_on  = [aws_iam_role.external_jump_ec2_role]
}

output "external_jump_ec2_instance_profile_name" {
  description = "Name of the IAM instance profile for the external jump EC2 instance."
  value       = aws_iam_instance_profile.external_jump_ec2_profile[0].name
  depends_on  = [aws_iam_instance_profile.external_jump_ec2_profile]
}

output "locker_ec2_role_arn" {
  description = "ARN of the IAM role for the Locker EC2 instance."
  value       = aws_iam_role.locker_ec2_role[0].arn
  depends_on  = [aws_iam_role.locker_ec2_role]
}

output "locker_ec2_instance_profile_name" {
  description = "Name of the IAM instance profile for the Locker EC2 instance."
  value       = aws_iam_instance_profile.locker_ec2_profile[0].name
  depends_on  = [aws_iam_instance_profile.locker_ec2_profile]
}

output "envoy_ec2_role_arn" {
  description = "ARN of the IAM role for Envoy EC2 instances."
  value       = aws_iam_role.envoy_ec2_role[0].arn
  depends_on  = [aws_iam_role.envoy_ec2_role]
}

output "envoy_ec2_instance_profile_name" {
  description = "Name of the IAM instance profile for Envoy EC2 instances."
  value       = aws_iam_instance_profile.envoy_ec2_profile[0].name
  depends_on  = [aws_iam_instance_profile.envoy_ec2_profile]
}

output "squid_ec2_role_arn" {
  description = "ARN of the IAM role for Squid EC2 instances."
  value       = aws_iam_role.squid_ec2_role[0].arn
  depends_on  = [aws_iam_role.squid_ec2_role]
}

output "squid_ec2_instance_profile_name" {
  description = "Name of the IAM instance profile for Squid EC2 instances."
  value       = aws_iam_instance_profile.squid_ec2_profile[0].name
  depends_on  = [aws_iam_instance_profile.squid_ec2_profile]
}

output "eks_cluster_role_arn" {
  description = "ARN of the IAM role for the EKS cluster."
  value       = aws_iam_role.eks_cluster_role[0].arn
  depends_on  = [aws_iam_role.eks_cluster_role]
}

output "internal_jump_ec2_role_arn" {
  description = "ARN of the IAM role for the EKS internal jump EC2 instance."
  value       = aws_iam_role.internal_jump_ec2_role[0].arn
  depends_on  = [aws_iam_role.internal_jump_ec2_role]
}

output "internal_jump_ec2_instance_profile_name" {
  description = "Name of the IAM instance profile for the EKS internal jump EC2 instance."
  value       = aws_iam_instance_profile.internal_jump_ec2_profile[0].name
  depends_on  = [aws_iam_instance_profile.internal_jump_ec2_profile]
}

output "keymanager_ec2_role_arn" {
  description = "ARN of the IAM role for the Keymanager EC2 instance."
  value       = aws_iam_role.keymanager_ec2_role[0].arn
  depends_on  = [aws_iam_role.keymanager_ec2_role]
}

output "keymanager_ec2_instance_profile_name" {
  description = "Name of the IAM instance profile for the Keymanager EC2 instance."
  value       = aws_iam_instance_profile.keymanager_ec2_profile[0].name
  depends_on  = [aws_iam_instance_profile.keymanager_ec2_profile]
}

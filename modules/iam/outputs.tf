output "instance_profile_name" {
  description = "The IAM instance profile name"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "instance_profile_arn" {
  description = "The IAM instance profile ARN"
  value       = aws_iam_instance_profile.ec2_profile.arn
}

output "role_arn" {
  description = "The IAM role ARN"
  value       = aws_iam_role.ec2_role.arn
}

output "vpc_id" {
  description = "ID of the created Virtual Private Cloud"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet where the application server resides"
  value       = module.vpc.public_subnet_id
}

output "security_group_id" {
  description = "ID of the web security group"
  value       = module.security_groups.web_security_group_id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2_app.instance_id
}

output "instance_public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = module.ec2_app.instance_public_ip
}

output "application_url" {
  description = "HTTP URL to access the deployed web application"
  value       = "http://${module.ec2_app.instance_public_ip}"
}

output "ssh_command" {
  description = "Example command to SSH into the provisioned instance"
  value       = module.ec2_app.private_key_path != null ? "ssh -i ${module.ec2_app.private_key_path} ec2-user@${module.ec2_app.instance_public_ip}" : "ssh ec2-user@${module.ec2_app.instance_public_ip}"
}

output "ssm_session_command" {
  description = "AWS Systems Manager (SSM) zero-open-port connection command (Production Standard)"
  value       = "aws ssm start-session --target ${module.ec2_app.instance_id} --region ${var.aws_region}"
}

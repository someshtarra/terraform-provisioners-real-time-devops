output "instance_id" {
  description = "The EC2 instance ID"
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "The public IPv4 address of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "instance_private_ip" {
  description = "The private IPv4 address of the EC2 instance"
  value       = aws_instance.app.private_ip
}

output "instance_arn" {
  description = "The ARN of the EC2 instance"
  value       = aws_instance.app.arn
}

output "key_pair_name" {
  description = "The name of the SSH key pair used"
  value       = local.effective_key_name
}

output "private_key_path" {
  description = "Path to the generated private key file (if auto-generated)"
  value       = var.key_name == null ? local_sensitive_file.private_key_pem[0].filename : null
}

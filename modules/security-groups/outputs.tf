output "web_security_group_id" {
  description = "The security group ID assigned to the web server"
  value       = aws_security_group.web.id
}

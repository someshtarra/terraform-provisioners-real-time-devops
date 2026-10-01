variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "Allowed CIDR blocks for SSH access (port 22)"
  type        = list(string)
}

variable "app_port" {
  description = "Application port (HTTP/custom app port)"
  type        = number
  default     = 80
}

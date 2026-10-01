variable "aws_region" {
  description = "The AWS region where resources will be provisioned."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Target deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project identifier used in naming conventions and resource tagging."
  type        = string
  default     = "terraform-provisioners-guide"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated Virtual Private Cloud (VPC)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public tier subnet (NAT Gateway / Bastion / Public ALB)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private tier subnet where compute workloads run in enterprise patterns."
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "AWS Availability Zone for single-AZ demonstration deployments."
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type sizing for the target workload."
  type        = string
  default     = "t3.micro"
}

variable "ssh_allowed_cidrs" {
  description = "List of ingress CIDR blocks permitted for SSH (port 22) administration."
  type        = list(string)
  default     = ["0.0.0.0/0"] # In production: replace with office VPN CIDR or Bastion IP
}

variable "app_port" {
  description = "TCP port exposed by the web/application server."
  type        = number
  default     = 80
}

variable "provisioning_mode" {
  description = "Demonstration provisioning strategy: 'provisioners' (file/remote-exec) or 'user-data' (production immutable pattern)."
  type        = string
  default     = "provisioners"

  validation {
    condition     = contains(["provisioners", "user-data"], var.provisioning_mode)
    error_message = "provisioning_mode must be either 'provisioners' or 'user-data'."
  }
}

variable "key_name" {
  description = "Optional name of an existing AWS Key Pair. If left null, a TLS key pair will be automatically generated."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be launched"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the instance"
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "provisioning_mode" {
  description = "Provisioning mode: 'provisioners' or 'user-data'"
  type        = string
  default     = "provisioners"
}

variable "key_name" {
  description = "Existing key pair name. If null, a key pair is automatically created."
  type        = string
  default     = null
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 80
}

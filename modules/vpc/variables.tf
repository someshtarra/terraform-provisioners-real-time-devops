variable "vpc_cidr" {
  description = "CIDR range for the Virtual Private Cloud"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR range for the public subnet"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR range for the private subnet"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

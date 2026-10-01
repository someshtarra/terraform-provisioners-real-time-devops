variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ssh_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

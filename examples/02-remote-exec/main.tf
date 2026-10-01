# ==============================================================================
# Example 02: remote-exec Provisioner Deep-Dive
# ==============================================================================
# The remote-exec provisioner invokes scripts or inline commands directly
# on the remote resource over an SSH or WinRM connection.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type        = string
  description = "Name of an existing AWS Key Pair in your AWS account"
}

variable "private_key_path" {
  type        = string
  description = "Local path to the SSH private key (.pem file)"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Simple default VPC lookup for standalone demonstration
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "ssh_demo" {
  name        = "remote-exec-demo-sg"
  description = "Allow inbound SSH for remote-exec demo"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Scope down to your IP in production!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "remote_demo" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ssh_demo.id]

  # Connection block defines the connection parameters for remote-exec
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key_path)
    host        = self.public_ip
    timeout     = "5m"
    agent       = false
  }

  # Pattern A: Inline commands
  provisioner "remote-exec" {
    inline = [
      "echo '=== Step 1: System info ==='",
      "uname -a",
      "uptime",
      "echo '=== Step 2: Creating application directories ==='",
      "sudo mkdir -p /var/log/custom-app",
      "sudo chown ec2-user:ec2-user /var/log/custom-app"
    ]

    on_failure = fail
  }

  tags = {
    Name = "terraform-remote-exec-demo"
  }
}

output "instance_ip" {
  value = aws_instance.remote_demo.public_ip
}

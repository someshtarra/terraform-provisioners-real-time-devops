# ==============================================================================
# Example 03: file Provisioner Deep-Dive
# ==============================================================================
# The file provisioner copies files or entire directories from the machine
# running Terraform to the newly created remote resource.
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

variable "key_name" {
  type        = string
  description = "Name of existing AWS Key Pair"
}

variable "private_key_path" {
  type        = string
  description = "Local path to SSH private key (.pem file)"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "ssh_file_sg" {
  name        = "file-provisioner-demo-sg"
  description = "Allow inbound SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "file_demo" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ssh_file_sg.id]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key_path)
    host        = self.public_ip
    timeout     = "5m"
  }

  # Pattern 1: Upload a single configuration file
  provisioner "file" {
    source      = "${path.module}/configs/sample.conf"
    destination = "/tmp/sample.conf"
  }

  # Pattern 2: Upload an entire directory of assets
  provisioner "file" {
    source      = "${path.module}/configs"
    destination = "/tmp/app_configs"
  }

  # Pattern 3: Render and upload an in-memory string directly without creating a local file
  provisioner "file" {
    content     = "DEPLOYED_AT=${timestamp()}\nNODE_ID=${self.id}\nREGION=${var.aws_region}"
    destination = "/tmp/build_metadata.env"
  }

  # Enterprise Pattern: Moving from /tmp to /etc using remote-exec and sudo
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/sample-app",
      "sudo cp /tmp/sample.conf /etc/sample-app/sample.conf",
      "sudo chmod 0644 /etc/sample-app/sample.conf",
      "echo 'File provisioner demonstration completed successfully.'"
    ]
  }

  tags = {
    Name = "terraform-file-provisioner-demo"
  }
}

output "instance_ip" {
  value = aws_instance.file_demo.public_ip
}

# ==============================================================================
# Example 04: Combining Provisioners with null_resource & Triggers
# ==============================================================================
# In production Terraform engineering, coupling provisioners directly into
# the `aws_instance` block is considered an anti-pattern because any provisioner
# failure marks the EC2 instance as TAINTED, causing destruction on next apply.
#
# By encapsulating provisioners inside `null_resource`, the infrastructure
# lifecycle is decoupled from the software bootstrap lifecycle.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
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
  description = "Path to SSH private key"
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

resource "aws_security_group" "combined_demo_sg" {
  name        = "combined-provisioner-demo-sg"
  description = "Security group for combined provisioner demo"
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

# 1. Base EC2 instance (Pure Infrastructure Layer)
resource "aws_instance" "cluster_node" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.combined_demo_sg.id]

  tags = {
    Name = "terraform-combined-cluster-node"
  }
}

# 2. Decoupled Provisioner Layer
resource "null_resource" "node_configuration" {
  # Triggers specify when this provisioner should re-run!
  # If the instance is replaced or if the configuration payload changes,
  # Terraform will re-execute this block without touching the instance.
  triggers = {
    instance_id = aws_instance.cluster_node.id
    config_hash = md5("v1.0.0-release")
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key_path)
    host        = aws_instance.cluster_node.public_ip
    timeout     = "5m"
  }

  # File provisioner: Upload configuration
  provisioner "file" {
    content     = "CLUSTER_NODE_ID=${aws_instance.cluster_node.id}\nVERSION=1.0.0"
    destination = "/tmp/node_env.conf"
  }

  # Remote-exec provisioner: Configure system
  provisioner "remote-exec" {
    inline = [
      "echo 'Applying configuration to node...'",
      "cat /tmp/node_env.conf",
      "echo 'Node bootstrap complete.'"
    ]
  }

  # Local-exec provisioner: Notify orchestration engine
  provisioner "local-exec" {
    command = "echo 'Node ${aws_instance.cluster_node.id} (${aws_instance.cluster_node.public_ip}) successfully bootstrapped.' >> /tmp/bootstrap_nodes.log"
  }

  depends_on = [aws_instance.cluster_node]
}

output "node_ip" {
  value = aws_instance.cluster_node.public_ip
}

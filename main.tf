# ==============================================================================
# Terraform Provisioners Guide - Root Orchestration
# ==============================================================================
# This root configuration instantiates modular infrastructure:
# 1. Dedicated VPC, Subnets, Route Tables & Internet Gateway
# 2. Strict Security Groups (SSH & Web traffic)
# 3. IAM Role & Instance Profile (SSM Agent & CloudWatch)
# 4. EC2 Application Server with Provisioners / Cloud-init
# ==============================================================================

module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}

module "security_groups" {
  source = "./modules/security-groups"

  vpc_id            = module.vpc.vpc_id
  project_name      = var.project_name
  environment       = var.environment
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  app_port          = var.app_port
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

module "ec2_app" {
  source = "./modules/ec2-app"

  project_name         = var.project_name
  environment          = var.environment
  subnet_id            = module.vpc.public_subnet_id
  security_group_ids   = [module.security_groups.web_security_group_id]
  iam_instance_profile = module.iam.instance_profile_name
  instance_type        = var.instance_type
  provisioning_mode    = var.provisioning_mode
  key_name             = var.key_name
  app_port             = var.app_port
}

# ==============================================================================
# Root-Level Local-Exec Provisioner Example: Dynamic Inventory Generation
# ==============================================================================
# In hybrid production environments, local-exec is often used to generate
# dynamic Ansible inventory files or notify webhook endpoints upon completion.
# ==============================================================================
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/configs/inventory.ini.tpl", {
    instance_ip   = module.ec2_app.instance_public_ip
    ssh_user      = "ec2-user"
    key_file_path = module.ec2_app.private_key_path != null ? module.ec2_app.private_key_path : "~/.ssh/id_rsa"
    environment   = var.environment
  })
  filename        = "${path.module}/inventory.ini"
  file_permission = "0644"
}
module "dev_infrastructure" {
  source = "../../"

  environment       = "dev"
  aws_region        = var.aws_region
  instance_type     = "t3.micro"
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  provisioning_mode = "provisioners"
}

output "dev_application_url" {
  value = module.dev_infrastructure.application_url
}

output "dev_instance_public_ip" {
  value = module.dev_infrastructure.instance_public_ip
}

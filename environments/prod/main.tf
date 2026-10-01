module "prod_infrastructure" {
  source = "../../"

  environment       = "prod"
  aws_region        = var.aws_region
  instance_type     = "t3.small"
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  provisioning_mode = "user-data" # Production Standard: Zero provisioners, native cloud-init
}

output "prod_application_url" {
  value = module.prod_infrastructure.application_url
}

output "prod_instance_id" {
  value = module.prod_infrastructure.instance_id
}

output "prod_ssm_session_command" {
  value = module.prod_infrastructure.ssm_session_command
}

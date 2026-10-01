# ==============================================================================
# Example 05: Destroy-Time Provisioners (`when = destroy`)
# ==============================================================================
# Destroy-time provisioners run BEFORE a resource is destroyed.
#
# CRITICAL TERRAFORM RULE:
# In a destroy-time provisioner, expressions cannot refer to other resources or
# to dynamically generated attributes of `self` that require a provider refresh.
# You MUST pass necessary values into the `triggers` block of a `null_resource`!
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

variable "service_name" {
  type    = string
  default = "payment-gateway-worker"
}

variable "consul_endpoint" {
  type    = string
  default = "https://httpbin.org/post"
}

resource "null_resource" "service_registration" {
  triggers = {
    service_name    = var.service_name
    consul_endpoint = var.consul_endpoint
    registered_at   = timestamp()
  }

  # Creation-Time Provisioner
  provisioner "local-exec" {
    command = "echo 'REGISTER: Service ${self.triggers.service_name} registered into service discovery at ${self.triggers.registered_at}' >> lifecycle.log"
  }

  # Destroy-Time Provisioner
  # Executed when running `terraform destroy` or when this resource is replaced.
  provisioner "local-exec" {
    when    = destroy
    command = "echo 'DEREGISTER: Service ${self.triggers.service_name} removed from service discovery' >> lifecycle.log"

    # BEST PRACTICE: Always use on_failure = continue on destroy provisioners
    # to avoid deadlocking the deletion of your cloud infrastructure if an external
    # endpoint is unavailable!
    on_failure = continue
  }
}

output "registration_status" {
  value = "Service ${var.service_name} managed with creation and destroy lifecycle hooks."
}

# ==============================================================================
# Example 01: local-exec Provisioner Deep-Dive
# ==============================================================================
# The local-exec provisioner invokes a process on the machine running Terraform
# (e.g., your laptop, a Jenkins agent, or GitHub Actions runner), NOT on the
# remote resource.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "notification_webhook" {
  type    = string
  default = "https://httpbin.org/post"
}

# 1. Basic command execution with local environment variables
resource "null_resource" "log_deployment_event" {
  provisioner "local-exec" {
    command = "echo '[$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")] Deployed environment: $DEPLOY_ENV' >> local_audit.log"

    environment = {
      DEPLOY_ENV = var.environment
    }
  }
}

# 2. Specifying custom interpreter (e.g., Python / Bash) and working directory
resource "null_resource" "python_data_generator" {
  provisioner "local-exec" {
    command     = "import json, os; print(json.dumps({'status': 'ready', 'env': os.getenv('DEPLOY_ENV')}))"
    interpreter = ["python3", "-c"]
    working_dir = path.module

    environment = {
      DEPLOY_ENV = var.environment
    }
  }
}

# 3. Graceful failure handling with on_failure = continue
resource "null_resource" "notify_slack_webhook" {
  provisioner "local-exec" {
    # Simulates sending a webhook notification; does not abort apply if offline
    command = "curl -s -X POST -H 'Content-Type: application/json' -d '{\"text\":\"Deployment complete\"}' ${var.notification_webhook} || true"

    on_failure = continue
  }
}

output "audit_log_message" {
  value = "Deployment audit logged to local_audit.log"
}

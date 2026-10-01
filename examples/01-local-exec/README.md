# Example 01: `local-exec` Provisioner

## Overview

The `local-exec` provisioner runs commands **locally on the system executing Terraform** (such as your workstation, a Jenkins agent, or a GitHub Actions runner), rather than inside the target cloud resource.

## Common Production Use Cases

1. **Triggering Configuration Management**: Running `ansible-playbook -i inventory.ini site.yml` after servers are provisioned.
2. **Local Metadata Storage**: Writing public IPs, instance IDs, or DNS records to local inventory files or CI pipeline artifacts.
3. **Webhook Notifications**: Sending completion events to Slack, Microsoft Teams, or PagerDuty.
4. **Local CLI Orchestration**: Invoking external CLI tools (e.g., `aws`, `kubectl`, `vault`, `helm`) that have no native Terraform provider or require local bridging.

## Execution Syntax

```hcl
resource "null_resource" "example" {
  provisioner "local-exec" {
    command     = "echo 'Deployment finished' >> deploy.log"
    working_dir = path.module
    interpreter = ["/bin/bash", "-c"]
    environment = {
      APP_ENV = "production"
    }
    on_failure  = continue
  }
}
```

## Running This Example

```bash
cd examples/01-local-exec
terraform init
terraform apply -auto-approve
cat local_audit.log
terraform destroy -auto-approve
```

# Example 04: Combining Provisioners with `null_resource` & Triggers

## Why Decouple Provisioners?

In Terraform, if an inline provisioner inside an `aws_instance` fails, Terraform marks the instance as **tainted**. On the next `terraform apply`, Terraform forces the **destruction and recreation** of the entire VM.

In production environments, this can lead to unexpected outages, lost data on ephemeral drives, and slow feedback loops.

## The `null_resource` Solution

By separating the provisioners into a `null_resource` (or `terraform_data` in Terraform 1.4+):
1. **Isolated Lifecycle**: If the script fails, only the `null_resource` is marked tainted—the underlying cloud EC2 instance stays alive!
2. **Re-execution Control**: Using the `triggers` map (e.g., `filemd5()` or version strings), you can selectively re-run provisioning commands whenever local configs change.

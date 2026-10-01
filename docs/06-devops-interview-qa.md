# 06. Real-Time Production DevOps Interview Questions & Answers

*Curated by Senior DevOps Engineers with 8–10+ years of enterprise cloud experience.*

---

### Q1: What are Terraform Provisioners, and why does HashiCorp explicitly advise against them in production?
**Answer:**
Terraform Provisioners (`local-exec`, `remote-exec`, `file`) are mechanisms to execute scripts or file transfers to configure servers during creation or destruction.

HashiCorp considers them a **last resort** because:
1. **Breaks Declarative Model**: Terraform manages state declaratively. Shell scripts inside provisioners are imperative and non-idempotent.
2. **Untracked State**: Terraform has no visibility into what happens inside the OS. Changes made by scripts are invisible to `terraform plan` and cannot be audited for drift.
3. **The Tainted Trap**: Any non-zero exit code marks the entire cloud resource as **tainted**, forcing Terraform to destroy and recreate the instance on the next apply.
4. **Security Vulnerability**: `remote-exec` requires open SSH (port 22) or WinRM (port 5986) access and distribution of private keys, violating zero-trust architecture.

---

### Q2: What is the exact difference between `local-exec` and `remote-exec`?
**Answer:**
* **`local-exec`**: Runs a process **locally** on the machine or CI/CD agent executing Terraform (e.g. laptop, Jenkins agent, GitHub runner). It does not require network access to the remote VM. Common uses: running `ansible-playbook`, invoking AWS CLI commands, generating dynamic inventory files, or sending Slack webhooks.
* **`remote-exec`**: Connects directly to the **remote cloud resource** over SSH or WinRM and runs commands or scripts inside the target guest OS. Requires inbound firewall access, valid credentials, and an active SSH/WinRM daemon.

---

### Q3: What happens if a creation-time provisioner fails? What is a "tainted" resource?
**Answer:**
If a creation-time provisioner fails with default settings (`on_failure = fail`), Terraform halts execution and marks the resource as **tainted** in the state file (`"tainted": true`).

On the subsequent `terraform apply`:
1. Terraform destroys the tainted resource.
2. Terraform creates a brand new replacement resource from scratch.
3. Terraform attempts to execute all provisioners again.

To recover without destroying a working VM:
```bash
terraform untaint module.ec2_app.aws_instance.app
```

---

### Q4: How do you prevent an EC2 instance from being tainted if a bootstrap script fails?
**Answer:**
By decoupling the provisioner from the core resource using `null_resource` (or `terraform_data` in Terraform 1.4+):
```hcl
resource "aws_instance" "web" {
  # Pure infrastructure definition without provisioners
}

resource "null_resource" "web_provisioner" {
  triggers = {
    instance_id = aws_instance.web.id
  }

  connection {
    host = aws_instance.web.public_ip
    # ...
  }

  provisioner "remote-exec" {
    inline = ["sudo ./bootstrap.sh"]
  }

  depends_on = [aws_instance.web]
}
```
If the script fails, only `null_resource.web_provisioner` is tainted. The underlying EC2 instance remains intact.

---

### Q5: How do destroy-time provisioners differ from creation-time provisioners? What critical limitation applies to them?
**Answer:**
Destroy-time provisioners run **before** the resource is deleted (`when = destroy`). They are typically used to deregister nodes from load balancers or revoke licenses.

**Critical Limitation**: Destroy provisioners cannot reference dynamic attributes of other resources or attributes of `self` that are computed by cloud providers (such as `self.public_ip` or `aws_instance.web.id`).
**Solution**: You must pass dynamic attributes into the `triggers` block of a `null_resource`, and access them using `self.triggers.<attribute>`:
```hcl
resource "null_resource" "cluster_deregistration" {
  triggers = {
    node_ip = aws_instance.app.public_ip
  }

  provisioner "remote-exec" {
    when = destroy
    inline = ["curl -X POST https://consul/deregister?ip=${self.triggers.node_ip}"]
    on_failure = continue # Prevents blocking deletion if consul is down!
  }
}
```

---

### Q6: Can you run Terraform provisioners on an EC2 instance located in a private subnet with no public IP?
**Answer:**
Yes, by configuring a **Bastion Host (Jumpbox)** in the `connection` block:
```hcl
connection {
  type                = "ssh"
  user                = "ec2-user"
  private_key         = file("keys/app.pem")
  host                = self.private_ip # Target private IP
  bastion_host        = "bastion.example.com" # Public IP / DNS of Bastion
  bastion_user        = "ec2-user"
  bastion_private_key = file("keys/bastion.pem")
}
```
However, in enterprise architectures, teams replace SSH bastions entirely with **AWS Systems Manager (SSM) Session Manager** or **EC2 User Data**, eliminating the need for open SSH access.

---

### Q7: What is the architectural difference between Terraform, cloud-init (user_data), Ansible, and Packer?
**Answer:**
* **Terraform**: Infrastructure provisioning (VPC, Subnets, Security Groups, IAM, EC2 instances, RDS).
* **Packer**: Immutable image builder (pre-baking OS, patches, software, and dependencies into an AMI before deployment).
* **cloud-init / user_data**: Machine bootstrapping (runs automatically on first boot to fetch instance identity, decrypt secrets, and start local services).
* **Ansible**: Configuration management and orchestration across mutable fleets.

**Enterprise Production Pattern**:
Use **Packer** to bake the Golden AMI $\rightarrow$ Use **Terraform** to provision the cloud infrastructure $\rightarrow$ Use **cloud-init** for minimal runtime parameter injection $\rightarrow$ Use **AWS SSM** for ongoing compliance and maintenance.

---

### Q8: What is the purpose of the `triggers` argument in `null_resource`?
**Answer:**
A `null_resource` does not create any physical infrastructure. Without `triggers`, its provisioners run only **once** when the resource is first added to state.
The `triggers` argument takes an arbitrary map of strings. Whenever any value inside `triggers` changes, Terraform forces the recreation of the `null_resource`, thereby re-running its provisioners:
```hcl
resource "null_resource" "deploy_app" {
  triggers = {
    config_hash = filemd5("${path.module}/configs/app.conf")
    script_hash = filemd5("${path.module}/scripts/deploy.sh")
  }
  # Re-runs whenever app.conf or deploy.sh changes on disk!
}
```

---

### Q9: If an engineer logs into an EC2 server via SSH and edits the Nginx configuration, will `terraform plan` detect configuration drift?
**Answer:**
**No.**
Terraform manages and tracks only cloud infrastructure metadata (EC2 instance state, security group rules, volume attachments, IAM roles). It has no agent inside the guest operating system and does not track OS files or software packages.
To detect in-guest configuration drift, teams use **Ansible check mode (`--check`)**, **Puppet/Chef agents**, or enforce **Immutable Infrastructure** (where SSH access is disabled and updates are performed by rolling out new AMIs).

---

### Q10: How do you handle Terraform state locking in production, and how do you resolve a stuck lock?
**Answer:**
In AWS environments, state locking is handled using an **Amazon DynamoDB** table with a primary hash key `LockID`.
When an apply begins, Terraform creates an item with `LockID = <state-path-hash>`. Other applies attempting to run receive `ConditionalCheckFailedException`.

If a CI/CD job crashes without releasing the lock:
1. Verify no pipeline is running.
2. Obtain the Lock ID from the error message.
3. Execute:
```bash
terraform force-unlock <LOCK_ID>
```

---

### Q11: What security risk does `local-exec` introduce in CI/CD pipelines?
**Answer:**
`local-exec` executes arbitrary shell commands with the privileges of the user running Terraform on the CI agent.
Risks:
1. **Supply Chain Attacks**: A malicious module from the public Terraform registry can execute arbitrary code inside `local-exec` (e.g. exfiltrating CI environment variables, AWS tokens, or GitHub secrets).
2. **Runner Inconsistency**: Scripts might depend on local binaries (`jq`, `curl`, `aws-cli`) that exist on developer laptops but are missing from minimal CI container images.

---

### Q12: How would you design a zero-downtime deployment on AWS without Terraform provisioners?
**Answer:**
1. Bake the application release into an **AMI** using Packer in the CI pipeline.
2. Create an **AWS Launch Template** referencing the new AMI.
3. Update the **Auto Scaling Group** using an **Instance Refresh** policy:
   * Minimum healthy percentage: 100%
   * Warmup time: 300s
4. Application Load Balancer health checks verify new instances before draining and terminating old instances.
5. Zero SSH keys, zero provisioners, fully automated, automated rollback on health probe failure.

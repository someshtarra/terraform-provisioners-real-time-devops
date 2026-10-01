# 03. Resource Lifecycle, State Management & Security Architecture

## 1. Resource Lifecycle State Machine

When Terraform executes `terraform apply`, every resource with an attached provisioner passes through an explicit state machine:

```mermaid
stateDiagram-v2
    [*] --> Planned: terraform plan
    Planned --> CloudAPICalling: terraform apply
    CloudAPICalling --> CloudCreated: Cloud Provider API OK
    
    state ProvisioningPhase {
        CloudCreated --> Connecting: connection {} block (SSH/WinRM)
        Connecting --> ProvisionerExecuting: Handshake Established
        Connecting --> ConnectionTimeout: Timeout (e.g. 5m exceeded)
        
        ProvisionerExecuting --> ScriptSuccess: Exit Code 0
        ProvisionerExecuting --> ScriptFailure: Exit Code != 0
    }

    ScriptSuccess --> ResourceCreated: Saved to Terraform State
    ConnectionTimeout --> ResourceTainted: Marked TAINTED in State
    ScriptFailure --> CheckFailureMode
    
    state CheckFailureMode <<choice>>
    CheckFailureMode --> ResourceCreated: on_failure = continue
    CheckFailureMode --> ResourceTainted: on_failure = fail (Default)

    ResourceCreated --> [*]: Available in Production
    ResourceTainted --> DestroyAndRecreate: Next terraform apply
```

---

## 2. The "Tainted" Resource Trap

When a provisioner fails with `on_failure = fail`, Terraform marks the resource as **tainted** (`"tainted": true` in JSON state).

### What Happens Next?
On the subsequent `terraform apply`:
1. Terraform notes that the resource is tainted.
2. Terraform issues an API call to **destroy the tainted cloud resource** (terminates the EC2 instance, discards attached non-persistent storage).
3. Terraform creates a **brand new instance** from scratch and re-runs all provisioners.

### Recovering from Tainted State in Production

```bash
# In Modern Terraform (v0.15.2+):
# Inspect state
terraform state list

# Untaint a resource without recreating it (if you manually resolved the issue)
terraform apply -replace="aws_instance.app"    # Explicit replacement
# Or if state allows:
terraform untaint module.ec2_app.aws_instance.app
```

> [!CAUTION]
> In an Auto Scaling Group or Production Database, recreating an instance because of a failed logging script can cause production outages. This is the primary reason senior DevOps architects wrap provisioners in a `null_resource` or migrate entirely to `user_data` / Packer.

---

## 3. Remote State Management: S3 & DynamoDB Locking

Storing Terraform state (`terraform.tfstate`) locally on a developer's laptop is dangerous:
- State contains sensitive data (private keys, generated passwords, IP addresses).
- Multiple team members running applies simultaneously can corrupt state files (race condition).
- Loss of laptop disk destroys infrastructure state tracking.

### Production Backend Architecture

```mermaid
flowchart TD
    subgraph CI_or_DevOps["DevOps Engineers & CI/CD Pipelines"]
        Dev1["Engineer Workstation"]
        Jenkins["Jenkins Pipeline"]
        GHA["GitHub Actions Runner"]
    end

    subgraph AWS_Cloud["AWS Enterprise Infrastructure"]
        DDB["Amazon DynamoDB Table\n(terraform-locks)\nState Locking via LockID"]
        S3["Amazon S3 Bucket\n(terraform-state-prod)\nAES-256 / KMS Encrypted\nVersioning Enabled"]
    end

    Dev1 -->|"1. Acquire Mutex Lock"| DDB
    Jenkins -->|"1. Acquire Mutex Lock"| DDB
    GHA -->|"1. Acquire Mutex Lock"| DDB

    Dev1 -->|"2. Read / Write State"| S3
    Jenkins -->|"2. Read / Write State"| S3
    GHA -->|"2. Read / Write State"| S3
```

### Complete S3 Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket         = "corp-production-terraform-state-us-east-1"
    key            = "compute/web-servers/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "corp-terraform-state-locks"
    encrypt        = true
  }
}
```

---

## 4. AWS Networking & SSH Security Hardening

To run `remote-exec` or `file` provisioners on an AWS EC2 instance, the network path between Terraform and the instance must be open on port 22.

```mermaid
flowchart LR
    subgraph PublicSubnet["Public Subnet (Tier 1)"]
        IGW["Internet Gateway"]
        NAT["NAT Gateway"]
        Bastion["SSH Bastion Host\n(Optional)"]
    end

    subgraph PrivateSubnet["Private Subnet (Tier 2 - Enterprise Standard)"]
        EC2["EC2 Workload\n(No Public IPv4)"]
        SSM["AWS Systems Manager\n(SSM Agent)"]
    end

    IGW --> Bastion
    Bastion -->|"SSH Port 22\n(Internal VPC CIDR)"| EC2
    EC2 -->|"Outbound Updates via NAT"| NAT
    NAT --> IGW
    SSM -->|"Zero Inbound Ports\nTLS Port 443 Outbound"| IGW
```

### Enterprise Security Best Practices

1. **Never Allow `0.0.0.0/0` on Port 22**:
   - Ingress CIDRs must be restricted to enterprise VPN endpoints (`198.51.100.25/32`) or corporate IP ranges.
2. **IMDSv2 Enforcement**:
   - Set `http_tokens = "required"` and `http_put_response_hop_limit = 1` to prevent SSRF vulnerabilities from leaking AWS IAM credentials.
3. **IAM Instance Profiles (Least Privilege)**:
   - Attach IAM roles directly to instances using `aws_iam_instance_profile`. Avoid storing static AWS Access Keys (`AWS_ACCESS_KEY_ID`) on instances or inside provisioner scripts.

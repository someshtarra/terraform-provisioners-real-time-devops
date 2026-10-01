# Example 02: `remote-exec` Provisioner

## Overview

The `remote-exec` provisioner connects to a target compute instance over SSH (Linux) or WinRM (Windows) and runs commands or shell scripts remotely.

## Supported Modes

1. **`inline`**: A list of command strings executed in sequence.
2. **`script`**: A path to a local shell script uploaded to a temporary path on the remote host and executed.
3. **`scripts`**: A list of paths to local scripts executed in sequence.

> **Note:** `inline`, `script`, and `scripts` are mutually exclusive within a single `remote-exec` block.

## Connection Block

Every `remote-exec` and `file` provisioner requires a `connection` block. This can be placed directly within the resource or inside the provisioner block itself.

```hcl
connection {
  type        = "ssh"        # "ssh" or "winrm"
  user        = "ec2-user"
  private_key = file("~/.ssh/id_rsa")
  host        = self.public_ip
  timeout     = "5m"
}
```

## Production Cautions

- Requires inbound network access (SSH port 22 or WinRM port 5986), which violates zero-trust enterprise security policies.
- If package installation or network updates fail during execution, Terraform marks the entire resource as **tainted**, destroying and recreating the virtual machine on the next `terraform apply`.

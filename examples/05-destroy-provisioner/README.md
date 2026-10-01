# Example 05: Destroy-Time Provisioners

## Overview

By default, provisioners run during resource creation (`when = create`). By adding `when = destroy`, the provisioner runs **before the resource is destroyed**.

## Common Use Cases

1. **Deregistration**: Removing an EC2 instance from Consul, Eureka, or an external load balancer.
2. **License Revocation**: Deactivating a node-locked third-party software license.
3. **Flushing Buffers**: Exporting local logs or state to S3 before terminating a server.

## Golden Rule for Destroy Provisioners

In a destroy-time provisioner, expressions **cannot** reference attributes of other resources or dynamic computed attributes. 

```hcl
# WRONG (Fails during terraform destroy):
provisioner "local-exec" {
  when    = destroy
  command = "echo ${aws_instance.app.public_ip}" # ERROR!
}

# CORRECT (Using self.triggers):
resource "null_resource" "cleanup" {
  triggers = {
    public_ip = aws_instance.app.public_ip
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo ${self.triggers.public_ip}"
  }
}
```

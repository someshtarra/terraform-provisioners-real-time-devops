# ==============================================================================
# Dynamic AMI Discovery (Amazon Linux 2023)
# ==============================================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# Automated SSH Key Pair Generation (Zero Manual Secrets)
# ==============================================================================
resource "tls_private_key" "ssh_key" {
  count     = var.key_name == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  count      = var.key_name == null ? 1 : 0
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = tls_private_key.ssh_key[0].public_key_openssh

  tags = {
    Name = "${var.project_name}-${var.environment}-key"
  }
}

resource "local_sensitive_file" "private_key_pem" {
  count           = var.key_name == null ? 1 : 0
  content         = tls_private_key.ssh_key[0].private_key_pem
  filename        = "${path.root}/generated_keys/${var.project_name}-${var.environment}.pem"
  file_permission = "0600"
}

locals {
  effective_key_name    = var.key_name != null ? var.key_name : aws_key_pair.generated_key[0].key_name
  effective_private_key = var.key_name == null ? tls_private_key.ssh_key[0].private_key_pem : fileexists("${path.root}/keys/${var.key_name}.pem") ? file("${path.root}/keys/${var.key_name}.pem") : ""
}

# ==============================================================================
# EC2 Application Server Resource
# ==============================================================================
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile
  key_name               = local.effective_key_name

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = {
      Name = "${var.project_name}-${var.environment}-root-vol"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-server"
    Environment = var.environment
    Role        = "Web-Application"
    Provisioner = var.provisioning_mode
  }

  # ----------------------------------------------------------------------------
  # PRODUCTION PATTERN (When provisioning_mode == "user-data")
  # Uses cloud-init to bootstrap the instance natively without SSH ports open
  # ----------------------------------------------------------------------------
  user_data = var.provisioning_mode == "user-data" ? templatefile("${path.root}/scripts/bootstrap.sh", {
    app_port    = var.app_port
    environment = var.environment
  }) : null
}

# ==============================================================================
# Decoupled Provisioner Resource (null_resource)
# ==============================================================================
# Enterprise Pattern: Placing provisioners inside null_resource (or terraform_data)
# rather than directly inside aws_instance prevents the EC2 instance from being
# TAINTED and re-created if a temporary script failure occurs.
# ==============================================================================
resource "null_resource" "instance_provisioner" {
  count = var.provisioning_mode == "provisioners" ? 1 : 0

  triggers = {
    instance_id = aws_instance.app.id
    config_hash = filemd5("${path.root}/configs/nginx.conf")
    script_hash = filemd5("${path.root}/scripts/bootstrap.sh")
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = local.effective_private_key
    host        = aws_instance.app.public_ip
    timeout     = "5m"
    agent       = false
  }

  # 1. File Provisioner: Copy Nginx configuration file
  provisioner "file" {
    source      = "${path.root}/configs/nginx.conf"
    destination = "/tmp/nginx.conf"
    on_failure  = fail
  }

  # 2. File Provisioner: Copy Linux bootstrap script
  provisioner "file" {
    source      = "${path.root}/scripts/bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
    on_failure  = fail
  }

  # 3. Remote-exec Provisioner: Execute script and verify web server health
  provisioner "remote-exec" {
    inline = [
      "echo '=== Step 1: Setting executable permissions ==='",
      "chmod +x /tmp/bootstrap.sh",
      "echo '=== Step 2: Executing Linux bootstrap script ==='",
      "sudo /tmp/bootstrap.sh",
      "echo '=== Step 3: Verifying HTTP response ==='",
      "curl -s -f http://localhost:${var.app_port} || exit 1",
      "echo '=== Remote provisioning succeeded ==='"
    ]
    on_failure = fail
  }

  # 4. Local-exec Provisioner: Write deployment audit record to local CI runner log
  provisioner "local-exec" {
    command = "echo '[$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")] SUCCESS: Provisioned instance ${aws_instance.app.id} at ${aws_instance.app.public_ip}' >> ${path.root}/deployment_audit.log"

    environment = {
      INSTANCE_ID = aws_instance.app.id
      PUBLIC_IP   = aws_instance.app.public_ip
      ENV_NAME    = var.environment
    }

    on_failure = continue
  }

  depends_on = [aws_instance.app]
}

# ==============================================================================
# Destroy-Time Provisioner (null_resource)
# ==============================================================================
# Demonstrates running cleanup operations BEFORE an EC2 instance is terminated.
# IMPORTANT: In destroy provisioners, `aws_instance.app.*` is not directly accessible.
# Attributes MUST be accessed via `self.triggers.*`.
# ==============================================================================
resource "null_resource" "destroy_cleanup" {
  count = var.provisioning_mode == "provisioners" ? 1 : 0

  triggers = {
    instance_id = aws_instance.app.id
    public_ip   = aws_instance.app.public_ip
    environment = var.environment
    private_key = local.effective_private_key
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = self.triggers.private_key
    host        = self.triggers.public_ip
    timeout     = "3m"
    agent       = false
  }

  # Creation-time dummy log
  provisioner "remote-exec" {
    inline = [
      "echo 'Registration marker created on instance ${self.triggers.instance_id}' > /tmp/registered.txt"
    ]
  }

  # Destroy-time execution: Deregister node / clean logs
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "echo 'Deregistering node ${self.triggers.instance_id} before termination...'",
      "sudo systemctl stop nginx || true",
      "echo 'Deregistration confirmed.'"
    ]
    on_failure = continue
  }

  # Local-exec destroy cleanup
  provisioner "local-exec" {
    when       = destroy
    command    = "echo '[$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")] DESTROY: Decommissioned instance ${self.triggers.instance_id}' >> ${path.root}/deployment_audit.log"
    on_failure = continue
  }

  depends_on = [aws_instance.app]
}

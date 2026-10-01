resource "aws_security_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-sg"
  description = "Security group for application server with SSH and HTTP ingress"
  vpc_id      = var.vpc_id

  # Ingress: SSH (port 22)
  ingress {
    description = "SSH administrative access (required for remote-exec provisioners)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  # Ingress: Application HTTP
  ingress {
    description = "HTTP application ingress traffic"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Full outbound access for package installations (yum/apt), OS updates, and AWS APIs
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-sg"
  }
}

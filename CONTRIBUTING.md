# Contributing to Terraform Provisioners Guide

Thank you for your interest in contributing to this guide! We welcome contributions that help improve clarity, security, and real-world production accuracy.

## Contribution Guidelines

1. **Code Formatting**: Ensure all Terraform files pass `terraform fmt -check -recursive`.
2. **Static Validation**: Verify all configurations pass `terraform validate`.
3. **No Hardcoded Secrets**: Never commit AWS credentials, private keys (`.pem`), or account numbers.
4. **Production Architecture Focus**: When illustrating provisioners, clearly articulate why HashiCorp recommends them as a *last resort* and provide corresponding cloud-native production alternatives (e.g., Packer, cloud-init, SSM, Ansible).

## Pull Request Process

1. Fork the repository and create your feature branch (`git checkout -b feature/improvement`).
2. Commit your changes with conventional commit messages (`feat:`, `fix:`, `docs:`).
3. Test using `make validate` and `make fmt`.
4. Open a Pull Request with a clear description of the problem solved.

# Example 03: `file` Provisioner

## Overview

The `file` provisioner copies files, templates, or entire directory trees from the local machine executing Terraform to a remote host over SSH or WinRM.

## Three Supported Usage Patterns

1. **Single File**: Specify `source = "local/path/app.conf"` and `destination = "/tmp/app.conf"`.
2. **Directory**: Specify `source = "local/config_dir"` and `destination = "/tmp/target_dir"`.
3. **In-Memory Content**: Use `content = "KEY=VALUE"` to stream dynamically generated strings without writing a file to local disk first.

## Real-World Production Gotchas

- **Permissions Limitation**: The SSH user (`ec2-user`, `ubuntu`, etc.) does not have root permissions by default. You cannot upload directly to `/etc/` or `/var/www/`. You **must** upload to `/tmp/` first and use `remote-exec` with `sudo` to move and chown the file.
- **Directory Trailing Slashes**: In Terraform `file` provisioners:
  - If `source` has a trailing slash (`configs/`), Terraform copies the *contents* of the directory.
  - If `source` lacks a trailing slash (`configs`), Terraform copies the directory itself.

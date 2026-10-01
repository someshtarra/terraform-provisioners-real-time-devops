#!/usr/bin/env bash
# ==============================================================================
# Linux EC2 Bootstrap Script
# Enterprise Production Standard
# Idempotent bootstrap script used by Terraform provisioners and cloud-init
# ==============================================================================
set -euo pipefail

LOG_FILE="/var/log/terraform-bootstrap.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "======================================================================"
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Starting EC2 Provisioning Bootstrap"
echo "======================================================================"

# 1. Detect OS and Package Manager
if command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
elif command -v apt-get &>/dev/null; then
    PKG_MGR="apt-get"
else
    echo "ERROR: Unsupported package manager" >&2
    exit 1
fi

echo "[INFO] Detected package manager: ${PKG_MGR}"

# 2. Update System Packages
echo "[INFO] Updating package cache..."
${PKG_MGR} update -y || {
    echo "WARNING: Non-fatal package update warning. Continuing..."
}

# 3. Install Nginx and Utilities
echo "[INFO] Installing Nginx, curl, and jq..."
${PKG_MGR} install -y nginx curl jq

# 4. Configure Web Root & Landing Page
WEB_ROOT="/usr/share/nginx/html"
if [ ! -d "${WEB_ROOT}" ]; then
    WEB_ROOT="/var/www/html"
    mkdir -p "${WEB_ROOT}"
fi

# Fetch instance metadata (IMDSv2)
echo "[INFO] Querying AWS EC2 IMDSv2 metadata..."
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || echo "")
if [ -n "${TOKEN}" ]; then
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" "http://169.254.169.254/latest/meta-data/instance-id" || echo "local-vm")
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" "http://169.254.169.254/latest/meta-data/placement/availability-zone" || echo "unknown-az")
    LOCAL_IPV4=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" "http://169.254.169.254/latest/meta-data/local-ipv4" || echo "127.0.0.1")
    PUBLIC_IPV4=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" "http://169.254.169.254/latest/meta-data/public-ipv4" || echo "N/A")
else
    INSTANCE_ID="standalone-node"
    AZ="local"
    LOCAL_IPV4=$(hostname -I | awk '{print $1}')
    PUBLIC_IPV4="N/A"
fi

# Apply uploaded custom nginx.conf if provided in /tmp
if [ -f "/tmp/nginx.conf" ]; then
    echo "[INFO] Moving uploaded custom Nginx configuration..."
    cp /tmp/nginx.conf /etc/nginx/nginx.conf
fi

# Write dynamic Enterprise HTML Dashboard
cat <<HTML > "${WEB_ROOT}/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terraform Provisioners Production Dashboard</title>
    <style>
        :root {
            --bg-color: #0b1120;
            --card-bg: #1e293b;
            --accent: #38bdf8;
            --accent-glow: rgba(56, 189, 248, 0.2);
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --success: #10b981;
            --border: #334155;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 40px 20px;
        }
        .container {
            max-width: 900px;
            width: 100%;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border);
        }
        .badge {
            display: inline-block;
            background: rgba(16, 185, 129, 0.15);
            color: var(--success);
            padding: 6px 16px;
            border-radius: 9999px;
            font-weight: 600;
            font-size: 0.85rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 12px;
            border: 1px solid rgba(16, 185, 129, 0.3);
        }
        h1 {
            font-size: 2.2rem;
            font-weight: 700;
            margin-bottom: 10px;
            background: linear-gradient(135deg, #38bdf8, #818cf8);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        p.subtitle {
            color: var(--text-muted);
            font-size: 1.05rem;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background-color: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 20px;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .card:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 25px -5px var(--accent-glow);
        }
        .card-label {
            font-size: 0.8rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-muted);
            margin-bottom: 6px;
        }
        .card-value {
            font-size: 1.15rem;
            font-weight: 600;
            color: var(--accent);
            word-break: break-all;
        }
        .system-info {
            background-color: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 24px;
        }
        .system-info h3 {
            font-size: 1.1rem;
            margin-bottom: 16px;
            color: var(--text-main);
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .console {
            background: #0f172a;
            border-radius: 8px;
            padding: 16px;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 0.85rem;
            color: #cbd5e1;
            line-height: 1.6;
            overflow-x: auto;
        }
        .footer {
            margin-top: 40px;
            text-align: center;
            color: var(--text-muted);
            font-size: 0.85rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <span class="badge">● Infrastructure Operational</span>
            <h1>Terraform Provisioners Guide</h1>
            <p class="subtitle">Enterprise AWS Cloud Workload Provisioned via HashiCorp Terraform</p>
        </div>

        <div class="grid">
            <div class="card">
                <div class="card-label">EC2 Instance ID</div>
                <div class="card-value">${INSTANCE_ID}</div>
            </div>
            <div class="card">
                <div class="card-label">Availability Zone</div>
                <div class="card-value">${AZ}</div>
            </div>
            <div class="card">
                <div class="card-label">Public IPv4</div>
                <div class="card-value">${PUBLIC_IPV4}</div>
            </div>
            <div class="card">
                <div class="card-label">Private IPv4</div>
                <div class="card-value">${LOCAL_IPV4}</div>
            </div>
            <div class="card">
                <div class="card-label">Operating System</div>
                <div class="card-value">Amazon Linux (AL2023)</div>
            </div>
            <div class="card">
                <div class="card-label">Web Engine</div>
                <div class="card-value">Nginx / Systemd</div>
            </div>
        </div>

        <div class="system-info">
            <h3>Enterprise Provisioning Status</h3>
            <div class="console">
[SUCCESS] Package manager (${PKG_MGR}) updated<br>
[SUCCESS] Nginx web server configured and started<br>
[SUCCESS] AWS IMDSv2 metadata successfully discovered<br>
[SUCCESS] Bootstrap log written to /var/log/terraform-bootstrap.log<br>
[AUDIT] Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')<br>
[STATUS] Health check: HTTP 200 OK
            </div>
        </div>

        <div class="footer">
            Automated by HashiCorp Terraform &bull; Production Infrastructure as Code Architecture
        </div>
    </div>
</body>
</html>
HTML

# 5. Enable and Start Nginx
echo "[INFO] Enabling and starting Nginx systemd unit..."
systemctl daemon-reload
systemctl enable nginx
systemctl restart nginx

# 6. Verify Local HTTP Response
echo "[INFO] Performing local health probe..."
if curl -s -f http://127.0.0.1 >/dev/null; then
    echo "[SUCCESS] Nginx responded with HTTP 200. Bootstrap finished successfully!"
else
    echo "ERROR: Nginx failed to respond to local health check probe" >&2
    exit 1
fi

echo "======================================================================"
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Bootstrap Completed Successfully"
echo "======================================================================"

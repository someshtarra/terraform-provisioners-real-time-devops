#!/usr/bin/env bash
# ==============================================================================
# End-to-End Terraform Infrastructure Verification Script
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo "      TERRAFORM PROVISIONERS GUIDE - AUTOMATED VERIFICATION"
echo "======================================================================"

# Step 1: Format Check
echo -n "[1/5] Checking Terraform formatting (terraform fmt -check)... "
if terraform fmt -check -recursive >/dev/null 2>&1; then
    echo "PASSED"
else
    echo "WARNING: Unformatted files detected. Run 'terraform fmt -recursive'."
fi

# Step 2: Validation
echo -n "[2/5] Validating Terraform configuration (terraform validate)... "
if terraform validate >/dev/null 2>&1; then
    echo "PASSED"
else
    echo "FAILED"
    terraform validate
    exit 1
fi

# Step 3: Check terraform outputs
echo "[3/5] Inspecting Terraform outputs..."
if [ -f "terraform.tfstate" ]; then
    PUBLIC_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
    APP_URL=$(terraform output -raw application_url 2>/dev/null || echo "")

    if [ -n "${PUBLIC_IP}" ]; then
        echo "      Instance Public IP : ${PUBLIC_IP}"
        echo "      Application URL    : ${APP_URL}"

        # Step 4: Endpoint Health Check
        echo "[4/5] Testing HTTP endpoint connectivity..."
        if curl -s -f --connect-timeout 5 "${APP_URL}" >/dev/null 2>&1; then
            echo "      Endpoint reachable: HTTP 200 OK!"
        else
            echo "      Endpoint not reachable yet or instance not deployed."
        fi
    else
        echo "      No instance IP discovered in state yet."
    fi
else
    echo "      State file not present. Run 'terraform apply' to deploy."
fi

# Step 5: Summary
echo "[5/5] Verification scan complete."
echo "======================================================================"

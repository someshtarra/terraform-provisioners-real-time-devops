#!/usr/bin/env bash
# ==============================================================================
# Automated CI/CD Pipeline Deployment Wrapper
# ==============================================================================
set -euo pipefail

ENV="${1:-dev}"
ACTION="${2:-plan}"

echo "======================================================================"
echo "[CI/CD] Environment: ${ENV} | Action: ${ACTION}"
echo "======================================================================"

export TF_IN_AUTOMATION="true"

# 1. Format Check
echo "[STEP 1] Formatting code..."
terraform fmt -recursive

# 2. Validation
echo "[STEP 2] Validating syntax..."
terraform init -backend=false
terraform validate

# 3. Backend Init
echo "[STEP 3] Initializing with backend..."
terraform init

# 4. Action
case "${ACTION}" in
    plan)
        echo "[STEP 4] Generating plan..."
        terraform plan -var="environment=${ENV}" -out=tfplan
        ;;
    apply)
        echo "[STEP 4] Applying infrastructure..."
        terraform apply -auto-approve -var="environment=${ENV}"
        echo "[STEP 5] Running verification..."
        ./scripts/deploy_verification.sh
        ;;
    destroy)
        echo "[STEP 4] Destroying infrastructure..."
        terraform destroy -auto-approve -var="environment=${ENV}"
        ;;
    *)
        echo "Unknown action: ${ACTION}. Choose: plan | apply | destroy"
        exit 1
        ;;
esac

echo "[CI/CD] Execution completed successfully."

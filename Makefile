# ==============================================================================
# Makefile - Terraform Provisioners Guide
# ==============================================================================
.PHONY: help init fmt validate plan apply apply-userdata verify destroy clean

SHELL := /bin/bash

help: ## Show this help menu
	@echo "Terraform Provisioners Guide - Available Commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform providers and backend
	terraform init

fmt: ## Check and format all Terraform files recursively
	terraform fmt -recursive

validate: ## Validate syntax and configuration integrity
	terraform validate

plan: ## Generate speculative execution plan
	terraform plan -out=tfplan

apply: ## Deploy infrastructure using Terraform Provisioners
	terraform apply -var="provisioning_mode=provisioners" -auto-approve

apply-userdata: ## Deploy infrastructure using Production-Standard EC2 User-Data
	terraform apply -var="provisioning_mode=user-data" -auto-approve

verify: ## Run health check and connectivity verification tests
	./scripts/deploy_verification.sh

destroy: ## Destroy all provisioned cloud infrastructure
	terraform destroy -auto-approve

clean: ## Clean local cache, plan files, and generated audit logs
	rm -f tfplan publicip.txt inventory.ini deployment_audit.log
	rm -rf generated_keys
	@echo "Clean completed."

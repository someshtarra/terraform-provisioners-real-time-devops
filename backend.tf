# ==============================================================================
# Remote State Management - S3 Bucket & DynamoDB State Locking
# ==============================================================================
# In production, local state is strictly forbidden. State files must be stored in
# an encrypted S3 bucket with versioning and DynamoDB locking to prevent concurrent
# plan/apply race conditions.
#
# PREREQUISITES FOR UNCOMMENTING S3 BACKEND:
# 1. Create S3 Bucket: `aws s3api create-bucket --bucket my-terraform-state-bucket --region us-east-1`
# 2. Enable Versioning: `aws s3api put-bucket-versioning --bucket my-terraform-state-bucket --versioning-configuration Status=Enabled`
# 3. Create DynamoDB Table: `aws dynamodb create-table --table-name terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-1`
# ==============================================================================

terraform {
  # For local sandbox/demo testing, Terraform uses the local backend by default.
  # To enable remote production state, uncomment the block below and run:
  # `terraform init -migrate-state`

  # backend "s3" {
  #   bucket         = "YOUR-ENTERPRISE-TERRAFORM-STATE-BUCKET"
  #   key            = "provisioners-guide/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

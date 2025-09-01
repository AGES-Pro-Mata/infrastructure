#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROVIDER="aws"
ACTION="save"  # save or load
STORAGE_TYPE="s3"  # s3, azure, or github

# Help function
function show_help {
    echo -e "${BLUE}Usage: ./save-terraform-state.sh [OPTIONS]${NC}"
    echo -e "Save or load Terraform state from a persistent storage location for Pro-Mata project"
    echo ""
    echo -e "Options:"
    echo -e "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo -e "  -a, --action      Action to perform (save or load), default: save"
    echo -e "  -s, --storage     Storage type (s3, azure, or github), default: s3"
    echo -e "  -e, --environment Environment (dev, staging, prod), default: dev"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Examples:"
    echo -e "  ./save-terraform-state.sh --provider aws --action save --storage s3 --environment prod"
    echo -e "  ./save-terraform-state.sh --provider azure --action load --storage azure --environment dev"
    echo -e "  ./save-terraform-state.sh --provider aws --action save --storage github --environment staging"
}

# Default environment
ENVIRONMENT="dev"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -s|--storage)
            STORAGE_TYPE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
case $ENVIRONMENT in
    dev|staging|prod)
        ;;
    *)
        echo -e "${RED}Invalid environment: ${ENVIRONMENT}. Must be 'dev', 'staging', or 'prod'.${NC}"
        exit 1
        ;;
esac

# Store the absolute path to the project root directory
PROJECT_ROOT=$(pwd)

# Set terraform directory based on provider and environment
if [[ "$PROVIDER" == "aws" ]]; then
    TERRAFORM_DIR="environments/${ENVIRONMENT}/aws"
elif [[ "$PROVIDER" == "azure" ]]; then
    TERRAFORM_DIR="environments/${ENVIRONMENT}/azure"
else
    echo -e "${RED}Invalid provider: ${PROVIDER}. Must be 'aws' or 'azure'.${NC}"
    exit 1
fi

# Full path to terraform state
TERRAFORM_STATE_PATH="${PROJECT_ROOT}/${TERRAFORM_DIR}/terraform.tfstate"
TERRAFORM_STATE_BACKUP_PATH="${PROJECT_ROOT}/${TERRAFORM_DIR}/terraform.tfstate.backup"

# Debug info
echo -e "${YELLOW}Pro-Mata Infrastructure - Terraform State Management${NC}"
echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}"
echo -e "${YELLOW}Provider: ${PROVIDER}${NC}"
echo -e "${YELLOW}Action: ${ACTION}${NC}"
echo -e "${YELLOW}Storage: ${STORAGE_TYPE}${NC}"
echo -e "${YELLOW}Using state file: ${TERRAFORM_STATE_PATH}${NC}"

if [[ -f "${TERRAFORM_STATE_PATH}" ]]; then
    echo -e "${GREEN}State file exists${NC}"
    # Show state file info
    STATE_SIZE=$(stat -f%z "${TERRAFORM_STATE_PATH}" 2>/dev/null || stat -c%s "${TERRAFORM_STATE_PATH}" 2>/dev/null || echo "unknown")
    STATE_MODIFIED=$(stat -f%Sm "${TERRAFORM_STATE_PATH}" 2>/dev/null || stat -c%y "${TERRAFORM_STATE_PATH}" 2>/dev/null || echo "unknown")
    echo -e "${BLUE}  Size: ${STATE_SIZE} bytes${NC}"
    echo -e "${BLUE}  Last modified: ${STATE_MODIFIED}${NC}"
else
    echo -e "${RED}State file does not exist at: ${TERRAFORM_STATE_PATH}${NC}"
    if [[ -d "${PROJECT_ROOT}/${TERRAFORM_DIR}" ]]; then
        echo -e "${YELLOW}Contents of ${TERRAFORM_DIR}:${NC}"
        ls -la "${PROJECT_ROOT}/${TERRAFORM_DIR}/"
    else
        echo -e "${RED}Terraform directory does not exist: ${PROJECT_ROOT}/${TERRAFORM_DIR}${NC}"
    fi
fi

# Set storage configuration based on provider and environment
if [[ "$PROVIDER" == "aws" ]]; then
    # Load environment variables if they exist
    ENV_FILE="${PROJECT_ROOT}/environments/${ENVIRONMENT}/.env.${ENVIRONMENT}"
    if [[ -f "$ENV_FILE" ]]; then
        echo -e "${YELLOW}Loading environment variables from: ${ENV_FILE}${NC}"
        source "$ENV_FILE"
    elif [[ -f "${PROJECT_ROOT}/.env" ]]; then
        echo -e "${YELLOW}Loading environment variables from: ${PROJECT_ROOT}/.env${NC}"
        source "${PROJECT_ROOT}/.env"
    fi
    
    # Pro-Mata specific AWS configuration
    BUCKET_NAME="pro-mata-terraform-state-${ENVIRONMENT}-${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'unknown')}"
    BUCKET_REGION="${AWS_REGION:-us-east-1}"
    STATE_FILE_KEY="terraform-state/${ENVIRONMENT}/${TERRAFORM_DIR}/terraform.tfstate"
    
elif [[ "$PROVIDER" == "azure" ]]; then
    # Pro-Mata specific Azure configuration
    STORAGE_ACCOUNT="promata${ENVIRONMENT}tfstate"
    CONTAINER_NAME="terraform-state"
    BLOB_NAME="${ENVIRONMENT}/${TERRAFORM_DIR}/terraform.tfstate"
fi

# GitHub-based storage variables - Pro-Mata specific
GITHUB_REPO="pro-mata/pro-mata-infra"
GITHUB_BRANCH="terraform-state-${ENVIRONMENT}"
GITHUB_TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"

# Check if we're in a GitHub Actions environment
if [[ -n "$GITHUB_ACTIONS" ]]; then
    echo -e "${YELLOW}Running in GitHub Actions environment${NC}"
    GITHUB_TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"
fi

# Function to create AWS S3 storage for state
function create_aws_s3_backend {
    echo -e "${YELLOW}Checking if S3 bucket exists: ${BUCKET_NAME}${NC}"
    
    if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" --region "${BUCKET_REGION}" 2>/dev/null; then
        echo -e "${YELLOW}Creating S3 bucket for Pro-Mata Terraform state: ${BUCKET_NAME}${NC}"
        
        # Create bucket with proper region handling
        if [[ "$BUCKET_REGION" == "us-east-1" ]]; then
            aws s3api create-bucket \
                --bucket "${BUCKET_NAME}" \
                --region "${BUCKET_REGION}"
        else
            aws s3api create-bucket \
                --bucket "${BUCKET_NAME}" \
                --region "${BUCKET_REGION}" \
                --create-bucket-configuration LocationConstraint="${BUCKET_REGION}"
        fi
        
        # Enable versioning on the bucket
        aws s3api put-bucket-versioning \
            --bucket "${BUCKET_NAME}" \
            --versioning-configuration Status=Enabled
        
        # Add bucket encryption
        aws s3api put-bucket-encryption \
            --bucket "${BUCKET_NAME}" \
            --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
        
        # Add bucket policy to prevent accidental deletion
        cat > /tmp/bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PreventAccidentalDeletion",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:DeleteBucket",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}"
        }
    ]
}
EOF
        aws s3api put-bucket-policy \
            --bucket "${BUCKET_NAME}" \
            --policy file:///tmp/bucket-policy.json
        rm /tmp/bucket-policy.json
        
        # Add lifecycle policy to manage old versions
        cat > /tmp/lifecycle-policy.json << EOF
{
    "Rules": [
        {
            "ID": "TerraformStateLifecycle",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "terraform-state/"
            },
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 90
            },
            "AbortIncompleteMultipartUpload": {
                "DaysAfterInitiation": 7
            }
        }
    ]
}
EOF
        aws s3api put-bucket-lifecycle-configuration \
            --bucket "${BUCKET_NAME}" \
            --lifecycle-configuration file:///tmp/lifecycle-policy.json
        rm /tmp/lifecycle-policy.json
        
        echo -e "${GREEN}S3 bucket created and configured for Pro-Mata${NC}"
    else
        echo -e "${GREEN}S3 bucket already exists${NC}"
    fi
}

# Function to create Azure Storage for state
function create_azure_storage_backend {
    echo -e "${YELLOW}Checking if Azure Storage Account exists: ${STORAGE_ACCOUNT}${NC}"
    
    RESOURCE_GROUP="pro-mata-terraform-state-${ENVIRONMENT}"
    
    if ! az storage account show --name "${STORAGE_ACCOUNT}" --resource-group "${RESOURCE_GROUP}" &>/dev/null; then
        echo -e "${YELLOW}Creating Azure Resource Group and Storage Account for Pro-Mata Terraform state${NC}"
        
        # Create resource group
        az group create --name "${RESOURCE_GROUP}" --location "eastus2" --tags "Project=Pro-Mata" "Environment=${ENVIRONMENT}" "Purpose=TerraformState"
        
        # Create storage account
        az storage account create \
            --name "${STORAGE_ACCOUNT}" \
            --resource-group "${RESOURCE_GROUP}" \
            --location "eastus2" \
            --sku "Standard_LRS" \
            --encryption-services "blob" \
            --https-only true \
            --min-tls-version "TLS1_2" \
            --allow-blob-public-access false \
            --tags "Project=Pro-Mata" "Environment=${ENVIRONMENT}" "Purpose=TerraformState"
        
        echo -e "${GREEN}Storage Account created for Pro-Mata${NC}"
    else
        echo -e "${GREEN}Storage Account already exists${NC}"
    fi
    
    # Create container if it doesn't exist
    if ! az storage container exists \
        --name "${CONTAINER_NAME}" \
        --account-name "${STORAGE_ACCOUNT}" \
        --auth-mode login --query exists -o tsv | grep -q "true"; then
        
        az storage container create \
            --name "${CONTAINER_NAME}" \
            --account-name "${STORAGE_ACCOUNT}" \
            --auth-mode login \
            --public-access off
        
        echo -e "${GREEN}Storage container created${NC}"
    fi
}

# Function to set up GitHub-based storage
function setup_github_storage {
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}GitHub CLI not found. Please install gh CLI first.${NC}"
        echo -e "${BLUE}Visit: https://cli.github.com/manual/installation${NC}"
        exit 1
    fi
    
    # Authenticate with GitHub if token is provided
    if [[ -n "$GITHUB_TOKEN" ]]; then
        echo "${GITHUB_TOKEN}" | gh auth login --with-token
    else
        echo -e "${YELLOW}No GitHub token provided. Make sure you're authenticated with gh CLI.${NC}"
    fi
    
    # Check if the branch exists
    if ! gh api repos/${GITHUB_REPO}/branches/${GITHUB_BRANCH} &>/dev/null; then
        echo -e "${YELLOW}Creating ${GITHUB_BRANCH} branch in the Pro-Mata repository${NC}"
        
        # Create a temporary directory
        TEMP_DIR=$(mktemp -d)
        cd "${TEMP_DIR}"
        
        # Clone the repository
        if ! gh repo clone "${GITHUB_REPO}" .; then
            echo -e "${RED}Failed to clone repository. Check your permissions.${NC}"
            cd "${PROJECT_ROOT}"
            rm -rf "${TEMP_DIR}"
            exit 1
        fi
        
        # Create a new orphan branch for storing terraform state
        git checkout --orphan "${GITHUB_BRANCH}"
        git rm -rf . 2>/dev/null || true
        
        cat > README.md << EOF
# Pro-Mata Terraform State Files - ${ENVIRONMENT}

This branch contains Terraform state files for the Pro-Mata project.

**Environment**: ${ENVIRONMENT}
**Provider**: ${PROVIDER}
**Created**: $(date)

## ⚠️ Important Notes

- This branch contains sensitive infrastructure state information
- Do not manually edit files in this branch
- State files are automatically managed by the deployment pipeline
- Only authorized deployment processes should access these files

## Structure

\`\`\`
terraform/
├── aws/          # AWS Terraform states (prod)
└── azure/        # Azure Terraform states (dev/staging)
\`\`\`
EOF
        
        git add README.md
        git config --local user.email "terraform-state@promata.com.br"
        git config --local user.name "Pro-Mata Terraform State"
        git commit -m "Initialize terraform-state branch for ${ENVIRONMENT}"
        git push origin "${GITHUB_BRANCH}"
        
        cd "${PROJECT_ROOT}"
        rm -rf "${TEMP_DIR}"
        
        echo -e "${GREEN}Created terraform-state branch for Pro-Mata ${ENVIRONMENT}${NC}"
    else
        echo -e "${GREEN}Terraform state branch already exists${NC}"
    fi
}

# Save Terraform state to the selected storage
function save_terraform_state {
    if [[ ! -f "${TERRAFORM_STATE_PATH}" ]]; then
        echo -e "${RED}State file doesn't exist at ${TERRAFORM_STATE_PATH}${NC}"
        echo -e "${YELLOW}Run 'terraform init' and 'terraform plan' first.${NC}"
        exit 1
    fi
    
    case $STORAGE_TYPE in
        "s3")
            create_aws_s3_backend
            
            echo -e "${YELLOW}Saving Pro-Mata Terraform state to S3: s3://${BUCKET_NAME}/${STATE_FILE_KEY}${NC}"
            
            # Add metadata to the upload
            aws s3 cp "${TERRAFORM_STATE_PATH}" "s3://${BUCKET_NAME}/${STATE_FILE_KEY}" \
                --metadata "Environment=${ENVIRONMENT},Provider=${PROVIDER},Project=Pro-Mata,SavedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            
            if [[ -f "${TERRAFORM_STATE_BACKUP_PATH}" ]]; then
                aws s3 cp "${TERRAFORM_STATE_BACKUP_PATH}" "s3://${BUCKET_NAME}/${STATE_FILE_KEY}.backup" \
                    --metadata "Environment=${ENVIRONMENT},Provider=${PROVIDER},Project=Pro-Mata,Type=Backup"
            fi
            
            echo -e "${GREEN}Pro-Mata state saved to S3 successfully${NC}"
            echo -e "${BLUE}Location: s3://${BUCKET_NAME}/${STATE_FILE_KEY}${NC}"
            ;;
            
        "azure")
            create_azure_storage_backend
            
            echo -e "${YELLOW}Saving Pro-Mata Terraform state to Azure Blob Storage: ${STORAGE_ACCOUNT}/${CONTAINER_NAME}/${BLOB_NAME}${NC}"
            
            az storage blob upload \
                --account-name "${STORAGE_ACCOUNT}" \
                --container-name "${CONTAINER_NAME}" \
                --name "${BLOB_NAME}" \
                --file "${TERRAFORM_STATE_PATH}" \
                --auth-mode login \
                --metadata "Environment=${ENVIRONMENT}" "Provider=${PROVIDER}" "Project=Pro-Mata" "SavedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                --overwrite
            
            if [[ -f "${TERRAFORM_STATE_BACKUP_PATH}" ]]; then
                az storage blob upload \
                    --account-name "${STORAGE_ACCOUNT}" \
                    --container-name "${CONTAINER_NAME}" \
                    --name "${BLOB_NAME}.backup" \
                    --file "${TERRAFORM_STATE_BACKUP_PATH}" \
                    --auth-mode login \
                    --metadata "Environment=${ENVIRONMENT}" "Provider=${PROVIDER}" "Project=Pro-Mata" "Type=Backup" \
                    --overwrite
            fi
            
            echo -e "${GREEN}Pro-Mata state saved to Azure Blob Storage successfully${NC}"
            echo -e "${BLUE}Location: ${STORAGE_ACCOUNT}/${CONTAINER_NAME}/${BLOB_NAME}${NC}"
            ;;
            
        "github")
            setup_github_storage
            
            echo -e "${YELLOW}Saving Pro-Mata Terraform state to GitHub${NC}"
            
            # Create a temporary directory
            TEMP_DIR=$(mktemp -d)
            
            # Clone the repository and switch to the terraform-state branch
            echo -e "${YELLOW}Cloning repository and checking out ${GITHUB_BRANCH} branch...${NC}"
            cd "${TEMP_DIR}"
            
            if ! gh repo clone "${GITHUB_REPO}" . -- -q; then
                echo -e "${RED}Failed to clone repository${NC}"
                cd "${PROJECT_ROOT}"
                rm -rf "${TEMP_DIR}"
                exit 1
            fi
            
            git checkout "${GITHUB_BRANCH}" -q 2>/dev/null || git checkout -b "${GITHUB_BRANCH}" -q
            
            # Create directory structure if it doesn't exist
            mkdir -p "${TERRAFORM_DIR}"
            
            # Copy the state file from the source directory to the temporary directory
            echo -e "${YELLOW}Copying Pro-Mata state files to repository...${NC}"
            cp -v "${TERRAFORM_STATE_PATH}" "${TERRAFORM_DIR}/" || {
                echo -e "${RED}Failed to copy state file${NC}"
                cd "${PROJECT_ROOT}"
                rm -rf "${TEMP_DIR}"
                exit 1
            }
            
            if [[ -f "${TERRAFORM_STATE_BACKUP_PATH}" ]]; then
                cp -v "${TERRAFORM_STATE_BACKUP_PATH}" "${TERRAFORM_DIR}/" || echo "Failed to copy backup file"
            fi
            
            # Add commit info
            cat > "${TERRAFORM_DIR}/state-info.txt" << EOF
Environment: ${ENVIRONMENT}
Provider: ${PROVIDER}
Project: Pro-Mata
Saved At: $(date)
State File Size: $(stat -f%z "${TERRAFORM_STATE_PATH}" 2>/dev/null || stat -c%s "${TERRAFORM_STATE_PATH}" 2>/dev/null || echo "unknown") bytes
EOF
            
            # Add and commit the changes
            git add "${TERRAFORM_DIR}" || {
                echo -e "${RED}Failed to add files${NC}"
                cd "${PROJECT_ROOT}"
                rm -rf "${TEMP_DIR}"
                exit 1
            }
            
            git config --local user.email "terraform-state@promata.com.br"
            git config --local user.name "Pro-Mata Terraform State"
            
            if git commit -m "Update Pro-Mata Terraform state for ${ENVIRONMENT}/${TERRAFORM_DIR} - $(date)" -q; then
                echo "Changes committed successfully"
            else
                echo "No changes to commit"
            fi
            
            # Push the changes
            if git push origin "${GITHUB_BRANCH}" -q; then
                echo -e "${GREEN}Pro-Mata state saved to GitHub successfully${NC}"
                echo -e "${BLUE}Branch: ${GITHUB_BRANCH}${NC}"
            else
                echo -e "${RED}Failed to push to GitHub${NC}"
                cd "${PROJECT_ROOT}"
                rm -rf "${TEMP_DIR}"
                exit 1
            fi
            
            # Return to original directory and clean up
            cd "${PROJECT_ROOT}"
            rm -rf "${TEMP_DIR}"
            ;;
            
        *)
            echo -e "${RED}Invalid storage type: ${STORAGE_TYPE}${NC}"
            exit 1
            ;;
    esac
}

# Load Terraform state from the selected storage
function load_terraform_state {
    case $STORAGE_TYPE in
        "s3")
            echo -e "${YELLOW}Loading Pro-Mata Terraform state from S3: s3://${BUCKET_NAME}/${STATE_FILE_KEY}${NC}"
            
            # Check if the state file exists in S3
            if aws s3 ls "s3://${BUCKET_NAME}/${STATE_FILE_KEY}" &>/dev/null; then
                # Create the directory structure if it doesn't exist
                mkdir -p "${PROJECT_ROOT}/${TERRAFORM_DIR}"
                
                # Download the state file
                aws s3 cp "s3://${BUCKET_NAME}/${STATE_FILE_KEY}" "${TERRAFORM_STATE_PATH}"
                
                # Check if there's a backup and download it too
                if aws s3 ls "s3://${BUCKET_NAME}/${STATE_FILE_KEY}.backup" &>/dev/null; then
                    aws s3 cp "s3://${BUCKET_NAME}/${STATE_FILE_KEY}.backup" "${TERRAFORM_STATE_BACKUP_PATH}"
                fi
                
                echo -e "${GREEN}Pro-Mata state loaded from S3 successfully${NC}"
            else
                echo -e "${RED}Pro-Mata Terraform state not found in S3${NC}"
                echo -e "${YELLOW}Expected location: s3://${BUCKET_NAME}/${STATE_FILE_KEY}${NC}"
                exit 1
            fi
            ;;
            
        "azure")
            echo -e "${YELLOW}Loading Pro-Mata Terraform state from Azure Blob Storage: ${STORAGE_ACCOUNT}/${CONTAINER_NAME}/${BLOB_NAME}${NC}"
            
            RESOURCE_GROUP="pro-mata-terraform-state-${ENVIRONMENT}"
            
            # Check if the blob exists
            if az storage blob exists --account-name "${STORAGE_ACCOUNT}" --container-name "${CONTAINER_NAME}" --name "${BLOB_NAME}" --auth-mode login --query exists -o tsv | grep -q "true"; then
                # Create the directory structure if it doesn't exist
                mkdir -p "${PROJECT_ROOT}/${TERRAFORM_DIR}"
                
                # Download the state file
                az storage blob download \
                    --account-name "${STORAGE_ACCOUNT}" \
                    --container-name "${CONTAINER_NAME}" \
                    --name "${BLOB_NAME}" \
                    --file "${TERRAFORM_STATE_PATH}" \
                    --auth-mode login
                
                # Check if there's a backup and download it too
                if az storage blob exists --account-name "${STORAGE_ACCOUNT}" --container-name "${CONTAINER_NAME}" --name "${BLOB_NAME}.backup" --auth-mode login --query exists -o tsv | grep -q "true"; then
                    az storage blob download \
                        --account-name "${STORAGE_ACCOUNT}" \
                        --container-name "${CONTAINER_NAME}" \
                        --name "${BLOB_NAME}.backup" \
                        --file "${TERRAFORM_STATE_BACKUP_PATH}" \
                        --auth-mode login
                fi
                
                echo -e "${GREEN}Pro-Mata state loaded from Azure Blob Storage successfully${NC}"
            else
                echo -e "${RED}Pro-Mata Terraform state not found in Azure Blob Storage${NC}"
                echo -e "${YELLOW}Expected location: ${STORAGE_ACCOUNT}/${CONTAINER_NAME}/${BLOB_NAME}${NC}"
                exit 1
            fi
            ;;
            
        "github")
            echo -e "${YELLOW}Loading Pro-Mata Terraform state from GitHub${NC}"
            
            # Create a temporary directory
            TEMP_DIR=$(mktemp -d)
            
            # Clone the repository and checkout the terraform-state branch
            echo -e "${YELLOW}Cloning repository and checking out ${GITHUB_BRANCH} branch...${NC}"
            cd "${TEMP_DIR}"
            
            if ! gh repo clone "${GITHUB_REPO}" . -- -q -b "${GITHUB_BRANCH}" 2>/dev/null; then
                echo -e "${RED}Failed to clone terraform-state branch. Make sure it exists and you have access.${NC}"
                echo -e "${YELLOW}Expected branch: ${GITHUB_BRANCH}${NC}"
                cd "${PROJECT_ROOT}"
                rm -rf "${TEMP_DIR}"
                exit 1
            fi
            
            # Check if the state file exists
            if [[ -f "${TERRAFORM_DIR}/terraform.tfstate" ]]; then
                # Create the directory structure if it doesn't exist
                mkdir -p "${PROJECT_ROOT}/${TERRAFORM_DIR}"
                
                # Copy the state file
                echo -e "${YELLOW}Copying Pro-Mata state files from repository...${NC}"
                cp -v "${TERRAFORM_DIR}/terraform.tfstate" "${TERRAFORM_STATE_PATH}"
                
                if [[ -f "${TERRAFORM_DIR}/terraform.tfstate.backup" ]]; then
                    cp -v "${TERRAFORM_DIR}/terraform.tfstate.backup" "${TERRAFORM_STATE_BACKUP_PATH}"
                fi
                
                # Show state info if available
                if [[ -f "${TERRAFORM_DIR}/state-info.txt" ]]; then
                    echo -e "${BLUE}State Information:${NC}"
                    cat "${TERRAFORM_DIR}/state-info.txt"
                fi
                
                cd "${PROJECT_ROOT}"
                rm -rf "${TEMP_DIR}"
                
                echo -e "${GREEN}Pro-Mata state loaded from GitHub successfully${NC}"
            else
                echo -e "${RED}Pro-Mata Terraform state not found in GitHub repository${NC}"
                echo -e "${YELLOW}Expected location: ${GITHUB_BRANCH}/${TERRAFORM_DIR}/terraform.tfstate${NC}"
                cd "${PROJECT_ROOT}"
                rm -rf "${TEMP_DIR}"
                exit 1
            fi
            ;;
            
        *)
            echo -e "${RED}Invalid storage type: ${STORAGE_TYPE}${NC}"
            exit 1
            ;;
    esac
}

# Perform the requested action
case $ACTION in
    "save")
        save_terraform_state
        ;;
    "load")
        load_terraform_state
        ;;
    *)
        echo -e "${RED}Invalid action: ${ACTION}. Must be 'save' or 'load'.${NC}"
        show_help
        exit 1
        ;;
esac

echo -e "${GREEN}Pro-Mata Terraform state operation completed successfully!${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT} | Provider: ${PROVIDER} | Storage: ${STORAGE_TYPE}${NC}"

exit 0
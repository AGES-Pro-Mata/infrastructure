#!/bin/bash
# ============================================================================
# Setup Terraform Backend
# Cria S3 bucket e DynamoDB table para Terraform state
# Region: sa-east-1 (São Paulo)
# ============================================================================

set -e

# Configurações
BUCKET_NAME="promata-terraform-state"
DYNAMODB_TABLE="promata-terraform-locks"
REGION="sa-east-1"

echo "🚀 Configurando Terraform Backend em ${REGION}..."

# Verificar se AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não encontrado. Instale: https://aws.amazon.com/cli/"
    exit 1
fi

# Verificar credenciais AWS
echo "✅ Verificando credenciais AWS..."
aws sts get-caller-identity --region ${REGION} || {
    echo "❌ Falha ao autenticar com AWS"
    exit 1
}

# Criar S3 Bucket
echo "📦 Criando S3 bucket: ${BUCKET_NAME}..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3api create-bucket \
        --bucket ${BUCKET_NAME} \
        --region ${REGION} \
        --create-bucket-configuration LocationConstraint=${REGION}

    echo "✅ Bucket criado"
else
    echo "ℹ️  Bucket já existe"
fi

# Habilitar versionamento
echo "📝 Habilitando versionamento..."
aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled \
    --region ${REGION}

# Habilitar criptografia
echo "🔒 Habilitando criptografia AES256..."
aws s3api put-bucket-encryption \
    --bucket ${BUCKET_NAME} \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }' \
    --region ${REGION}

# Bloquear acesso público
echo "🔐 Bloqueando acesso público..."
aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region ${REGION}

# Criar DynamoDB table para locks
echo "🔑 Criando DynamoDB table para locks..."
if aws dynamodb describe-table --table-name ${DYNAMODB_TABLE} --region ${REGION} 2>&1 | grep -q 'ResourceNotFoundException'; then
    aws dynamodb create-table \
        --table-name ${DYNAMODB_TABLE} \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region ${REGION} \
        --tags Key=Project,Value=promata Key=ManagedBy,Value=terraform

    echo "✅ DynamoDB table criada"

    # Aguardar table estar ativa
    echo "⏳ Aguardando table ficar ativa..."
    aws dynamodb wait table-exists --table-name ${DYNAMODB_TABLE} --region ${REGION}
else
    echo "ℹ️  DynamoDB table já existe"
fi

# Habilitar Point-in-Time Recovery
echo "💾 Habilitando Point-in-Time Recovery..."
aws dynamodb update-continuous-backups \
    --table-name ${DYNAMODB_TABLE} \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region ${REGION} 2>/dev/null || echo "ℹ️  PITR já habilitado ou não disponível"

echo ""
echo "✅ Terraform Backend configurado com sucesso!"
echo ""
echo "📋 Informações:"
echo "   Bucket: s3://${BUCKET_NAME}"
echo "   Region: ${REGION}"
echo "   DynamoDB: ${DYNAMODB_TABLE}"
echo ""
echo "🔧 Próximo passo:"
echo "   cd iac/aws"
echo "   terraform init"

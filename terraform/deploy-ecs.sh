#!/bin/bash

set -e
cd "$(dirname "$0")"

echo "Deploying to AWS ECS..."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# load .env
if [ -f ../.env ]; then
    echo -e "${YELLOW}Loading .env...${NC}"
    source ../.env
fi

command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI not found${NC}"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker not found${NC}"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform not found${NC}"; exit 1; }

echo -e "${YELLOW}Validating AWS credentials...${NC}"
aws sts get-caller-identity >/dev/null 2>&1 || { echo -e "${RED}Credenciais AWS inválidas${NC}"; exit 1; }
echo -e "${GREEN}✓ Credenciais válidas${NC}"

# terraform
echo -e "${YELLOW}Creating infra...${NC}"
terraform init
terraform apply -auto-approve

FLASK_REPO=$(terraform output -raw ecr_flask_repository_url)
NGINX_REPO=$(terraform output -raw ecr_nginx_repository_url)
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo -e "${GREEN}ECR created!${NC}"

# ECR login
echo -e "${YELLOW}🔐 Logging in ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
echo -e "${GREEN}Login successful!${NC}"

# build and push flask
echo -e "${YELLOW}Building Flask...${NC}"
cd ..
docker build -t flask-app:latest -f Dockerfile .
docker tag flask-app:latest $FLASK_REPO:latest
docker push $FLASK_REPO:latest
echo -e "${GREEN}✓ Flask pushed${NC}"

# build and push nginx
echo -e "${YELLOW}Building Nginx...${NC}"
docker build -t nginx-proxy:latest -f Dockerfile.nginx .
docker tag nginx-proxy:latest $NGINX_REPO:latest
docker push $NGINX_REPO:latest
echo -e "${GREEN}Nginx pushed${NC}"

cd terraform

# deployment
echo -e "${YELLOW}Updating ECS Service...${NC}"
aws ecs update-service \
  --cluster flask-app-cluster \
  --service flask-app-service \
  --force-new-deployment \
  --region $AWS_REGION >/dev/null
echo -e "${GREEN}Deployment started!${NC}"

# wait
echo -e "${YELLOW}Waiting deployment...${NC}"
aws ecs wait services-stable \
  --cluster flask-app-cluster \
  --services flask-app-service \
  --region $AWS_REGION

ALB_URL=$(terraform output -raw alb_url)

echo ""
echo -e "${GREEN}Deploy successful!${NC}"
echo ""
echo -e "${GREEN}URL:${NC} $ALB_URL"

#!/bin/bash
# Script to update the application, without need to recreate infra

set -e
cd "$(dirname "$0")"

echo "Updating app..."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -f ../.env ]; then
    source ../.env
fi

AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

FLASK_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/flask-app"
NGINX_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/nginx-proxy"

UPDATE_FLASK=true
UPDATE_NGINX=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --nginx-only)
            UPDATE_FLASK=false
            UPDATE_NGINX=true
            shift
            ;;
        --both)
            UPDATE_FLASK=true
            UPDATE_NGINX=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# login ECR
echo -e "${YELLOW}Login ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

cd ..

# build flask
if [ "$UPDATE_FLASK" = true ]; then
    echo -e "${YELLOW}Building Flask...${NC}"
    docker build -t flask-app:latest -f Dockerfile .
    docker tag flask-app:latest $FLASK_REPO:latest
    docker push $FLASK_REPO:latest
    echo -e "${GREEN}✓ Flask atualizado${NC}"
fi

# build nginx
if [ "$UPDATE_NGINX" = true ]; then
    echo -e "${YELLOW}Building Nginx...${NC}"
    docker build -t nginx-proxy:latest -f Dockerfile.nginx .
    docker tag nginx-proxy:latest $NGINX_REPO:latest
    docker push $NGINX_REPO:latest
    echo -e "${GREEN}✓ Nginx atualizado${NC}"
fi

cd terraform

# deployment
echo -e "${YELLOW}Deploying...${NC}"
aws ecs update-service \
  --cluster flask-app-cluster \
  --service flask-app-service \
  --force-new-deployment \
  --region $AWS_REGION >/dev/null

echo -e "${GREEN}Deployment started${NC}"
echo ""
echo "How to use:"
echo "   ./update-app.sh              # Update Flask"
echo "   ./update-app.sh --both       # Update Flask and Nginx"
echo "   ./update-app.sh --nginx-only # Update Nginx"

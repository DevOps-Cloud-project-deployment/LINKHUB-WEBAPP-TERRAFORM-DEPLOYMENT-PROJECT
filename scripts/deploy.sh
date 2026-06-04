cat > deploy.sh << 'EOF'
#!/bin/bash

# ============================================
# DEPLOY.SH - Deployment Script for LinkHub
# Deploys the application to AWS
# ============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🚀 LINKHUB DEPLOYMENT SCRIPT${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI first.${NC}"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform first.${NC}"
    exit 1
fi

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 not found. Please install Python3 first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All dependencies found${NC}"

# Step 1: Deploy infrastructure with Terraform
echo -e "\n${YELLOW}📦 Step 1: Deploying AWS infrastructure...${NC}"
cd ../terraform

terraform init
terraform plan
terraform apply -auto-approve

# Get server IP from Terraform output
SERVER_IP=$(terraform output -raw server_ip 2>/dev/null || echo "")
if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}❌ Failed to get server IP${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Infrastructure deployed at: $SERVER_IP${NC}"

# Step 2: Wait for server to be ready
echo -e "\n${YELLOW}⏳ Step 2: Waiting for server to be ready...${NC}"
sleep 30

# Step 3: Copy backend code to server
echo -e "\n${YELLOW}📁 Step 3: Copying backend code to server...${NC}"
cd ../backend

# Create tar archive
tar -czf ../backend.tar.gz .

# Copy to server
scp -i ../terraform/linkhub-key.pem ../backend.tar.gz ec2-user@$SERVER_IP:/home/ec2-user/

# Step 4: Install and start backend on server
echo -e "\n${YELLOW}🚀 Step 4: Installing backend on server...${NC}"
ssh -i ../terraform/linkhub-key.pem ec2-user@$SERVER_IP << 'ENDSSH'
    # Extract backend code
    cd /home/ec2-user
    tar -xzf backend.tar.gz
    rm backend.tar.gz
    
    # Install Python dependencies
    pip3 install -r requirements.txt
    
    # Create .env file
    cat > .env << 'EOF'
FLASK_ENV=production
SECRET_KEY=production-secret-key-change-this
DB_HOST=localhost
DB_PORT=5432
DB_NAME=linkhub
DB_USER=postgres
DB_PASSWORD=changeme
EOF
    
    # Start the application
    sudo systemctl restart linkhub || true
    sudo systemctl enable linkhub || true
    
    echo "✅ Backend deployed successfully"
ENDSSH

# Step 5: Cleanup
echo -e "\n${YELLOW}🧹 Step 5: Cleaning up...${NC}"
rm -f ../backend.tar.gz

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "📍 Server IP: $SERVER_IP"
echo -e "🌐 API URL: http://$SERVER_IP:5000"
echo -e "🔑 SSH Command: ssh -i ../terraform/linkhub-key.pem ec2-user@$SERVER_IP"
echo -e "${GREEN}========================================${NC}"
EOF

chmod +x deploy.sh
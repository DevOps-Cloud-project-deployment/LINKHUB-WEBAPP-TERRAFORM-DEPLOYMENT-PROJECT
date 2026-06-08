#!/bin/bash
# ============================================
# SETUP-LINKHUB.SH - Automated deployment script
# Run this after `terraform apply` to fully deploy LinkHub
# ============================================

set -e  # Stop on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🚀 LINKHUB DEPLOYMENT SCRIPT${NC}"
echo -e "${GREEN}========================================${NC}"

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${YELLOW}📁 Project root: $PROJECT_ROOT${NC}"

# Get EC2 IP from Terraform
echo -e "${YELLOW}📍 Getting EC2 IP address...${NC}"
cd terraform
IP=$(terraform output -raw server_ip 2>/dev/null)

if [ -z "$IP" ]; then
    echo -e "${RED}❌ Failed to get server IP. Run 'terraform apply' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ EC2 IP: $IP${NC}"

# Find the PEM key file
PEM_FILE=$(ls -1 *.pem 2>/dev/null | head -1)
if [ -z "$PEM_FILE" ]; then
    echo -e "${RED}❌ No PEM key file found in terraform folder${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Using key: $PEM_FILE${NC}"

# Step 1: SSH and setup backend
echo -e "${YELLOW}🔧 Setting up backend on EC2...${NC}"
ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ec2-user@$IP << 'ENDSSH'
    echo "Installing Python and pip..."
    sudo yum install python3 python3-pip -y > /dev/null 2>&1
    
    echo "Installing Flask..."
    sudo pip3 install flask flask-cors > /dev/null 2>&1
    
    echo "Creating API file..."
    cat > /home/ec2-user/app.py << 'EOF'
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route('/')
def home():
    return jsonify({"message": "LinkHub API is running!", "status": "healthy"})

@app.route('/health')
def health():
    return "OK", 200

@app.route('/api/signup', methods=['POST'])
def signup():
    data = request.get_json()
    return jsonify({"message": f"User {data.get('email')} created!", "token": "test-token"}), 201

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    return jsonify({"message": "Login successful!", "token": "test-token"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

    # Kill any existing process on port 5000
    sudo kill -9 $(sudo lsof -t -i :5000) 2>/dev/null || true
    
    echo "Starting API server..."
    cd /home/ec2-user
    python3 app.py > /dev/null 2>&1 &
    
    echo "Creating frontend directory..."
    mkdir -p /home/ec2-user/frontend
ENDSSH

echo -e "${GREEN}✅ Backend setup complete!${NC}"

# Step 2: Upload frontend files
echo -e "${YELLOW}📤 Uploading frontend files...${NC}"
cd "$PROJECT_ROOT"
scp -i "terraform/$PEM_FILE" -r frontend/* ec2-user@$IP:/home/ec2-user/frontend/

echo -e "${GREEN}✅ Frontend uploaded!${NC}"

# Step 3: Update API URLs and start web server
echo -e "${YELLOW}🔧 Configuring frontend and starting web server...${NC}"
ssh -i "terraform/$PEM_FILE" ec2-user@$IP << ENDSSH
    cd /home/ec2-user/frontend
    
    echo "Updating API URLs to http://$IP:5000..."
    sed -i "s|http://localhost:5000|http://$IP:5000|g" dashboard.html 2>/dev/null || true
    sed -i "s|http://localhost:5000|http://$IP:5000|g" signup.html 2>/dev/null || true
    sed -i "s|http://localhost:5000|http://$IP:5000|g" login.html 2>/dev/null || true
    
    # Kill existing web server
    sudo pkill -f "http.server" 2>/dev/null || true
    
    echo "Starting web server on port 80..."
    sudo python3 -m http.server 80 --directory /home/ec2-user/frontend/ > /dev/null 2>&1 &
    
    echo "Waiting for servers to start..."
    sleep 3
    
    # Test API
    echo "Testing API..."
    curl -s http://localhost:5000/health
ENDSSH

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "🌐 Your LinkHub is LIVE at: ${YELLOW}http://$IP${NC}"
echo -e "🔌 API endpoint: ${YELLOW}http://$IP:5000${NC}"
echo -e "🔑 SSH command: ${YELLOW}ssh -i terraform/$PEM_FILE ec2-user@$IP${NC}"
echo -e "${GREEN}========================================${NC}"
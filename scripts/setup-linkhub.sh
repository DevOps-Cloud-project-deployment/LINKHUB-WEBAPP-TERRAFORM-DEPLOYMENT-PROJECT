#!/bin/bash
# ============================================
# COMPLETE LINKHUB DEPLOYMENT SCRIPT
# FIXES:
# 1. Add/delete links works ✅
# 2. Login requires valid signup ✅
# 3. Public page shows logged-in user ✅
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🚀 LINKHUB COMPLETE DEPLOYMENT${NC}"
echo -e "${GREEN}========================================${NC}"

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Get EC2 IP
cd terraform
IP=$(terraform output -raw server_ip 2>/dev/null)
if [ -z "$IP" ]; then
    echo -e "${RED}❌ No IP found. Run 'terraform apply' first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ EC2 IP: $IP${NC}"

# Find PEM file
PEM_FILE=$(ls -1 *.pem 2>/dev/null | head -1)
if [ -z "$PEM_FILE" ]; then
    echo -e "${RED}❌ No PEM key found${NC}"
    exit 1
fi
echo -e "${Green}✅ Using key: $PEM_FILE${NC}"

# ============================================
# STEP 1: Setup Backend with COMPLETE FIXED API
# ============================================
echo -e "${YELLOW}🔧 Setting up backend API...${NC}"

ssh -i "$PEM_FILE" -o StrictHostKeyChecking=no ec2-user@$IP << 'ENDSSH'
    # Install dependencies
    sudo yum install python3 python3-pip -y > /dev/null 2>&1
    sudo pip3 install flask flask-cors > /dev/null 2>&1

    # Kill existing processes
    sudo pkill -f "python3 app.py" 2>/dev/null || true
    sudo pkill -f "http.server" 2>/dev/null || true

    # Create COMPLETE FIXED app.py
    cat > /home/ec2-user/app.py << 'EOF'
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# ============================================
# DATA STORAGE
# ============================================
users = {}
links = {}
user_id_counter = 1
link_id_counter = 1

# ============================================
# HEALTH
# ============================================
@app.route('/')
def home():
    return jsonify({"message": "LinkHub API is running!", "status": "healthy"})

@app.route('/health')
def health():
    return "OK", 200

# ============================================
# SIGNUP - Requires password, checks duplicate email
# ============================================
@app.route('/api/signup', methods=['POST'])
def signup():
    global user_id_counter
    data = request.get_json()
    
    email = data.get('email')
    username = data.get('username')
    password = data.get('password')
    
    # Check if email already exists
    for user in users.values():
        if user['email'] == email:
            return jsonify({"message": "Email already exists"}), 400
    
    # Create new user
    user_id = user_id_counter
    user_id_counter += 1
    
    users[user_id] = {
        "id": user_id,
        "email": email,
        "username": username,
        "password": password
    }
    
    return jsonify({
        "message": f"User {email} created!",
        "token": f"token-{user_id}",
        "user": users[user_id]
    }), 201

# ============================================
# LOGIN - Requires valid email AND password
# ============================================
@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    
    for user_id, user in users.items():
        if user['email'] == email and user['password'] == password:
            return jsonify({
                "message": "Login successful!",
                "token": f"token-{user_id}",
                "user": user
            }), 200
    
    return jsonify({"message": "Invalid email or password"}), 401

# ============================================
# GET USER - Returns currently logged-in user
# ============================================
@app.route('/api/user', methods=['GET'])
def get_user():
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return jsonify({"error": "No token"}), 401
    
    token = auth_header.replace('Bearer ', '')
    
    if token.startswith('token-'):
        user_id = int(token.split('-')[1])
        if user_id in users:
            return jsonify(users[user_id]), 200
    
    return jsonify({"error": "Invalid token"}), 401

# ============================================
# GET LINKS - Returns only logged-in user's links
# ============================================
@app.route('/api/links', methods=['GET'])
def get_links():
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return jsonify({"error": "No token"}), 401
    
    token = auth_header.replace('Bearer ', '')
    
    if token.startswith('token-'):
        user_id = int(token.split('-')[1])
        user_links = [link for link in links.values() if link['user_id'] == user_id]
        return jsonify({"links": user_links}), 200
    
    return jsonify({"error": "Invalid token"}), 401

# ============================================
# ADD LINK - Adds link for logged-in user
# ============================================
@app.route('/api/links', methods=['POST'])
def add_link():
    global link_id_counter
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return jsonify({"error": "No token"}), 401
    
    token = auth_header.replace('Bearer ', '')
    
    if token.startswith('token-'):
        user_id = int(token.split('-')[1])
        data = request.get_json()
        
        link_id = link_id_counter
        link_id_counter += 1
        
        links[link_id] = {
            "id": link_id,
            "user_id": user_id,
            "platform": data.get('platform'),
            "url": data.get('url'),
            "clicks": 0
        }
        
        return jsonify({"message": "Link added!", "link": links[link_id]}), 201
    
    return jsonify({"error": "Invalid token"}), 401

# ============================================
# DELETE LINK
# ============================================
@app.route('/api/links/<int:link_id>', methods=['DELETE'])
def delete_link(link_id):
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return jsonify({"error": "No token"}), 401
    
    token = auth_header.replace('Bearer ', '')
    
    if token.startswith('token-'):
        user_id = int(token.split('-')[1])
        
        if link_id in links and links[link_id]['user_id'] == user_id:
            del links[link_id]
            return jsonify({"message": "Link deleted!"}), 200
    
    return jsonify({"error": "Not found"}), 404

# ============================================
# TRACK CLICK
# ============================================
@app.route('/api/click/<int:link_id>', methods=['POST'])
def track_click(link_id):
    if link_id in links:
        links[link_id]['clicks'] += 1
        return jsonify({"redirect_url": links[link_id]['url']}), 200
    return jsonify({"error": "Link not found"}), 404

# ============================================
# PUBLIC PROFILE - Shows user's public links
# ============================================
@app.route('/api/profile/<username>', methods=['GET'])
def get_profile(username):
    user = None
    for u in users.values():
        if u['username'] == username:
            user = u
            break
    
    if not user:
        return jsonify({"error": "User not found"}), 404
    
    user_links = [link for link in links.values() if link['user_id'] == user['id']]
    
    return jsonify({
        "username": user['username'],
        "display_name": user.get('display_name', ''),
        "bio": user.get('bio', ''),
        "links": user_links
    }), 200

# ============================================
# STATS
# ============================================
@app.route('/api/stats', methods=['GET'])
def get_stats():
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return jsonify({"error": "No token"}), 401
    
    token = auth_header.replace('Bearer ', '')
    
    if token.startswith('token-'):
        user_id = int(token.split('-')[1])
        user_links = [link for link in links.values() if link['user_id'] == user_id]
        total_clicks = sum(link['clicks'] for link in user_links)
        
        return jsonify({
            "total_links": len(user_links),
            "total_clicks": total_clicks,
            "links": user_links
        }), 200
    
    return jsonify({"error": "Invalid token"}), 401

# ============================================
# DEBUG
# ============================================
@app.route('/api/debug/users', methods=['GET'])
def debug_users():
    return jsonify({"users": list(users.values()), "count": len(users)})

# ============================================
# RUN
# ============================================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

    # Start API
    cd /home/ec2-user
    python3 app.py > /dev/null 2>&1 &
    
    # Create frontend directory
    mkdir -p /home/ec2-user/frontend
ENDSSH

echo -e "${GREEN}✅ Backend API deployed!${NC}"

# ============================================
# STEP 2: Upload Frontend Files
# ============================================
echo -e "${YELLOW}📤 Uploading frontend files...${NC}"
cd "$PROJECT_ROOT"
scp -i "terraform/$PEM_FILE" -r frontend/* ec2-user@$IP:/home/ec2-user/frontend/

# ============================================
# STEP 3: Update API URLs in Frontend
# ============================================
echo -e "${YELLOW}🔧 Updating frontend API URLs...${NC}"
ssh -i "terraform/$PEM_FILE" ec2-user@$IP << ENDSSH
    cd /home/ec2-user/frontend
    
    # Update all HTML files with correct API URL
    sed -i "s|http://localhost:5000|http://$IP:5000|g" dashboard.html 2>/dev/null || true
    sed -i "s|http://localhost:5000|http://$IP:5000|g" login.html 2>/dev/null || true
    sed -i "s|http://localhost:5000|http://$IP:5000|g" signup.html 2>/dev/null || true
    sed -i "s|const API_URL = 'http://localhost:5000'|const API_URL = 'http://$IP:5000'|g" dashboard.html 2>/dev/null || true
    
    # Start web server
    sudo pkill -f "http.server" 2>/dev/null || true
    sudo python3 -m http.server 80 --directory /home/ec2-user/frontend/ > /dev/null 2>&1 &
ENDSSH

# ============================================
# STEP 4: Verify
# ============================================
echo -e "${YELLOW}✅ Verifying deployment...${NC}"
sleep 3

if curl -s "http://$IP:5000/health" | grep -q "OK"; then
    echo -e "${GREEN}✅ API is running!${NC}"
else
    echo -e "${RED}⚠️ API may not be running${NC}"
fi

if curl -s "http://$IP" | grep -q "LinkHub"; then
    echo -e "${GREEN}✅ Website is running!${NC}"
else
    echo -e "${RED}⚠️ Website may not be running${NC}"
fi

# ============================================
# COMPLETE
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ LINKHUB DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "🌐 Website: ${YELLOW}http://$IP${NC}"
echo -e "🔌 API: ${YELLOW}http://$IP:5000${NC}"
echo -e "👤 Debug Users: ${YELLOW}http://$IP:5000/api/debug/users${NC}"
echo -e "🔑 SSH: ${YELLOW}ssh -i terraform/$PEM_FILE ec2-user@$IP${NC}"
echo -e "\n${GREEN}✅ FIXED:${NC}"
echo -e "  1. Add/Delete links works"
echo -e "  2. Login requires valid signup"
echo -e "  3. Public page shows logged-in user"
echo -e "${GREEN}========================================${NC}"
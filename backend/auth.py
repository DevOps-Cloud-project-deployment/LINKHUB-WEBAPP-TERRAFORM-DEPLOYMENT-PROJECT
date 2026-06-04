cat > auth.py << 'EOF'
# ============================================
# AUTH.PY - Authentication Logic
# Handles: JWT tokens, password hashing, user validation
# ============================================

import jwt
import bcrypt
import datetime
import os
from functools import wraps
from flask import request, jsonify
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Secret key for JWT (should be in .env file)
SECRET_KEY = os.getenv('SECRET_KEY', 'your-super-secret-key-change-this')

class Auth:
    @staticmethod
    def hash_password(password):
        """Hash a password using bcrypt"""
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
        return hashed.decode('utf-8')
    
    @staticmethod
    def verify_password(password, hashed_password):
        """Verify a password against its hash"""
        return bcrypt.checkpw(password.encode('utf-8'), hashed_password.encode('utf-8'))
    
    @staticmethod
    def generate_token(user_id, username):
        """Generate JWT token for authenticated user"""
        payload = {
            'user_id': user_id,
            'username': username,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(days=7),
            'iat': datetime.datetime.utcnow()
        }
        token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')
        return token
    
    @staticmethod
    def verify_token(token):
        """Verify and decode JWT token"""
        try:
            # Remove 'Bearer ' prefix if present
            if token.startswith('Bearer '):
                token = token[7:]
            
            payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None
    
    @staticmethod
    def get_user_from_request(request, db):
        """Get current user from request token"""
        token = request.headers.get('Authorization')
        
        if not token:
            return None
        
        payload = Auth.verify_token(token)
        
        if not payload:
            return None
        
        user_id = payload.get('user_id')
        
        # Query user from database
        user = db.fetch_one(
            "SELECT id, email, username, display_name, bio, plan FROM users WHERE id = %s",
            (user_id,)
        )
        
        return user

# Decorator for protected routes
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'message': 'Missing authentication token'}), 401
        
        payload = Auth.verify_token(token)
        
        if not payload:
            return jsonify({'message': 'Invalid or expired token'}), 401
        
        # Add user info to request context
        request.user_id = payload.get('user_id')
        request.username = payload.get('username')
        
        return f(*args, **kwargs)
    
    return decorated_function

# Validation functions
def validate_email(email):
    """Validate email format"""
    import re
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

def validate_username(username):
    """Validate username format (alphanumeric, underscore, 3-20 chars)"""
    import re
    pattern = r'^[a-zA-Z0-9_]{3,20}$'
    return re.match(pattern, username) is not None

def validate_url(url):
    """Validate URL format"""
    import re
    pattern = r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$'
    return re.match(pattern, url) is not None
EOF
from flask import Flask, request, jsonify
from flask_cors import CORS
import jwt
import bcrypt
import datetime
from functools import wraps

app = Flask(__name__)
CORS(app)

app.config['SECRET_KEY'] = 'linkhub-secret-key'

# In-memory database (for testing)
users = {}
links = {}
user_counter = 1
link_counter = 1

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'message': 'Token missing'}), 401
        try:
            token = token.split(' ')[1]
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            request.user_id = data['user_id']
        except:
            return jsonify({'message': 'Invalid token'}), 401
        return f(*args, **kwargs)
    return decorated

@app.route('/')
def home():
    return jsonify({'message': 'LinkHub API is running!', 'status': 'healthy'})

@app.route('/health')
def health():
    return jsonify({'status': 'ok'})

@app.route('/api/signup', methods=['POST'])
def signup():
    global user_counter
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    username = data.get('username', email.split('@')[0])
    
    for user in users.values():
        if user['email'] == email:
            return jsonify({'message': 'User exists'}), 400
    
    hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
    user_id = user_counter
    user_counter += 1
    
    users[user_id] = {
        'id': user_id,
        'email': email,
        'password': hashed.decode(),
        'username': username,
        'display_name': data.get('display_name', ''),
        'bio': '',
        'created_at': datetime.datetime.now().isoformat()
    }
    
    token = jwt.encode({'user_id': user_id, 'exp': datetime.datetime.utcnow() + datetime.timedelta(days=7)}, app.config['SECRET_KEY'])
    return jsonify({'token': token, 'user': users[user_id]}), 201

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    
    for user in users.values():
        if user['email'] == email and bcrypt.checkpw(password.encode(), user['password'].encode()):
            token = jwt.encode({'user_id': user['id'], 'exp': datetime.datetime.utcnow() + datetime.timedelta(days=7)}, app.config['SECRET_KEY'])
            return jsonify({'token': token, 'user': user})
    
    return jsonify({'message': 'Invalid credentials'}), 401

@app.route('/api/user', methods=['GET'])
@token_required
def get_user():
    return jsonify(users.get(request.user_id, {}))

@app.route('/api/links', methods=['GET'])
@token_required
def get_links():
    user_links = [l for l in links.values() if l['user_id'] == request.user_id]
    return jsonify({'links': user_links})

@app.route('/api/links', methods=['POST'])
@token_required
def add_link():
    global link_counter
    data = request.get_json()
    link_id = link_counter
    link_counter += 1
    
    links[link_id] = {
        'id': link_id,
        'user_id': request.user_id,
        'platform': data.get('platform'),
        'url': data.get('url'),
        'clicks': 0,
        'created_at': datetime.datetime.now().isoformat()
    }
    return jsonify(links[link_id]), 201

@app.route('/api/links/<int:link_id>', methods=['DELETE'])
@token_required
def delete_link(link_id):
    if link_id in links and links[link_id]['user_id'] == request.user_id:
        del links[link_id]
        return jsonify({'message': 'Deleted'})
    return jsonify({'message': 'Not found'}), 404

@app.route('/api/profile/<username>', methods=['GET'])
def get_profile(username):
    for user in users.values():
        if user['username'] == username:
            user_links = [l for l in links.values() if l['user_id'] == user['id']]
            return jsonify({
                'username': user['username'],
                'display_name': user['display_name'],
                'bio': user['bio'],
                'links': user_links
            })
    return jsonify({'message': 'User not found'}), 404

@app.route('/api/stats', methods=['GET'])
@token_required
def get_stats():
    user_links = [l for l in links.values() if l['user_id'] == request.user_id]
    total_clicks = sum(l['clicks'] for l in user_links)
    return jsonify({
        'total_links': len(user_links),
        'total_clicks': total_clicks,
        'links': user_links
    })

@app.route('/api/click/<int:link_id>', methods=['POST'])
def track_click(link_id):
    if link_id in links:
        links[link_id]['clicks'] += 1
        return jsonify({'redirect_url': links[link_id]['url']})
    return jsonify({'message': 'Not found'}), 404

if __name__ == '__main__':
    print("=" * 50)
    print("🚀 LINKHUB API RUNNING on http://localhost:5000")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=True)
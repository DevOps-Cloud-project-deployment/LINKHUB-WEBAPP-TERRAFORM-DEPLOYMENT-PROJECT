cat > models.py << 'EOF'
# ============================================
# MODELS.PY - Database Schema and Models
# Defines all database tables and operations
# ============================================

from database import db

class User:
    """User model for database operations"""
    
    @staticmethod
    def create_table():
        """Create users table if not exists"""
        query = """
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            username VARCHAR(50) UNIQUE NOT NULL,
            display_name VARCHAR(100),
            bio TEXT,
            avatar_url TEXT,
            theme VARCHAR(20) DEFAULT 'dark',
            button_color VARCHAR(7) DEFAULT '#667eea',
            plan VARCHAR(20) DEFAULT 'free',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
        db.execute_query(query)
        print("✅ Users table ready")
    
    @staticmethod
    def create(email, password_hash, username, display_name=None):
        """Create a new user"""
        query = """
        INSERT INTO users (email, password_hash, username, display_name)
        VALUES (%s, %s, %s, %s)
        RETURNING id, email, username, display_name, plan, created_at
        """
        result = db.fetch_one(query, (email, password_hash, username, display_name))
        return result
    
    @staticmethod
    def find_by_email(email):
        """Find user by email"""
        query = "SELECT * FROM users WHERE email = %s"
        return db.fetch_one(query, (email,))
    
    @staticmethod
    def find_by_username(username):
        """Find user by username"""
        query = "SELECT * FROM users WHERE username = %s"
        return db.fetch_one(query, (username,))
    
    @staticmethod
    def find_by_id(user_id):
        """Find user by ID"""
        query = "SELECT id, email, username, display_name, bio, avatar_url, theme, button_color, plan, created_at FROM users WHERE id = %s"
        return db.fetch_one(query, (user_id,))
    
    @staticmethod
    def update(user_id, data):
        """Update user information"""
        return db.update('users', data, 'id = %s', [user_id])

class Link:
    """Link model for database operations"""
    
    @staticmethod
    def create_table():
        """Create links table if not exists"""
        query = """
        CREATE TABLE IF NOT EXISTS links (
            id SERIAL PRIMARY KEY,
            user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
            platform VARCHAR(50) NOT NULL,
            url TEXT NOT NULL,
            position INTEGER DEFAULT 0,
            is_active BOOLEAN DEFAULT true,
            clicks INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
        db.execute_query(query)
        print("✅ Links table ready")
    
    @staticmethod
    def create(user_id, platform, url, position=None):
        """Create a new link"""
        if position is None:
            # Get next position
            pos_query = "SELECT COALESCE(MAX(position), -1) + 1 as next_pos FROM links WHERE user_id = %s"
            result = db.fetch_one(pos_query, (user_id,))
            position = result['next_pos'] if result else 0
        
        query = """
        INSERT INTO links (user_id, platform, url, position)
        VALUES (%s, %s, %s, %s)
        RETURNING id, user_id, platform, url, position, clicks, created_at
        """
        return db.fetch_one(query, (user_id, platform, url, position))
    
    @staticmethod
    def find_by_user(user_id):
        """Get all links for a user, ordered by position"""
        query = "SELECT * FROM links WHERE user_id = %s ORDER BY position ASC"
        return db.fetch_all(query, (user_id,))
    
    @staticmethod
    def find_by_id(link_id):
        """Find link by ID"""
        query = "SELECT * FROM links WHERE id = %s"
        return db.fetch_one(query, (link_id,))
    
    @staticmethod
    def update(link_id, data):
        """Update link information"""
        return db.update('links', data, 'id = %s', [link_id])
    
    @staticmethod
    def delete(link_id):
        """Delete a link"""
        return db.delete('links', 'id = %s', [link_id])
    
    @staticmethod
    def increment_clicks(link_id):
        """Increment click count for a link"""
        query = "UPDATE links SET clicks = clicks + 1 WHERE id = %s"
        return db.execute_query(query, (link_id,))
    
    @staticmethod
    def reorder(user_id, link_ids):
        """Reorder links based on provided order"""
        for position, link_id in enumerate(link_ids):
            query = "UPDATE links SET position = %s WHERE id = %s AND user_id = %s"
            db.execute_query(query, (position, link_id, user_id))
        return True

class Click:
    """Click model for analytics"""
    
    @staticmethod
    def create_table():
        """Create clicks table if not exists"""
        query = """
        CREATE TABLE IF NOT EXISTS clicks (
            id SERIAL PRIMARY KEY,
            link_id INTEGER REFERENCES links(id) ON DELETE CASCADE,
            user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
            ip_address VARCHAR(45),
            user_agent TEXT,
            referer TEXT,
            country VARCHAR(2),
            device VARCHAR(20),
            browser VARCHAR(50),
            clicked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
        db.execute_query(query)
        print("✅ Clicks table ready")
    
    @staticmethod
    def create(link_id, user_id, ip_address=None, user_agent=None, referer=None):
        """Record a click"""
        query = """
        INSERT INTO clicks (link_id, user_id, ip_address, user_agent, referer)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id
        """
        result = db.fetch_one(query, (link_id, user_id, ip_address, user_agent, referer))
        return result['id'] if result else None
    
    @staticmethod
    def get_stats(user_id):
        """Get click statistics for a user"""
        query = """
        SELECT 
            COUNT(*) as total_clicks,
            COUNT(DISTINCT link_id) as links_clicked,
            COUNT(DISTINCT ip_address) as unique_visitors
        FROM clicks 
        WHERE user_id = %s
        """
        return db.fetch_one(query, (user_id,))
    
    @staticmethod
    def get_clicks_by_link(user_id):
        """Get clicks grouped by link"""
        query = """
        SELECT 
            l.id,
            l.platform,
            COUNT(c.id) as click_count
        FROM links l
        LEFT JOIN clicks c ON l.id = c.link_id
        WHERE l.user_id = %s
        GROUP BY l.id, l.platform
        ORDER BY click_count DESC
        """
        return db.fetch_all(query, (user_id,))

def init_database():
    """Initialize all database tables"""
    print("🔄 Initializing database...")
    User.create_table()
    Link.create_table()
    Click.create_table()
    print("✅ Database initialization complete!")
EOF
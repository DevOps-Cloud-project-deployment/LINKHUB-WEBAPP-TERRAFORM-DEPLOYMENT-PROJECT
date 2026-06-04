cat > database.py << 'EOF'
# ============================================
# DATABASE.PY - PostgreSQL Connection
# Handles all database operations
# ============================================

import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database connection configuration
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'linkhub')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'postgres')

class Database:
    def __init__(self):
        self.connection = None
    
    def connect(self):
        """Create database connection"""
        try:
            self.connection = psycopg2.connect(
                host=DB_HOST,
                port=DB_PORT,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD
            )
            print("✅ Database connected successfully!")
            return self.connection
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return None
    
    def disconnect(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            print("📴 Database disconnected")
    
    def execute_query(self, query, params=None):
        """Execute a query and return results"""
        try:
            cursor = self.connection.cursor(cursor_factory=RealDictCursor)
            cursor.execute(query, params)
            self.connection.commit()
            return cursor
        except Exception as e:
            print(f"❌ Query failed: {e}")
            self.connection.rollback()
            return None
    
    def fetch_all(self, query, params=None):
        """Fetch all results from a query"""
        cursor = self.execute_query(query, params)
        if cursor:
            results = cursor.fetchall()
            cursor.close()
            return results
        return []
    
    def fetch_one(self, query, params=None):
        """Fetch single result from a query"""
        cursor = self.execute_query(query, params)
        if cursor:
            result = cursor.fetchone()
            cursor.close()
            return result
        return None
    
    def insert(self, table, data):
        """Insert data into a table"""
        columns = ', '.join(data.keys())
        placeholders = ', '.join(['%s'] * len(data))
        query = f"INSERT INTO {table} ({columns}) VALUES ({placeholders}) RETURNING id"
        
        cursor = self.execute_query(query, list(data.values()))
        if cursor:
            result = cursor.fetchone()
            cursor.close()
            return result['id'] if result else None
        return None
    
    def update(self, table, data, where_clause, where_params):
        """Update data in a table"""
        set_clause = ', '.join([f"{key} = %s" for key in data.keys()])
        query = f"UPDATE {table} SET {set_clause} WHERE {where_clause}"
        
        params = list(data.values()) + where_params
        cursor = self.execute_query(query, params)
        if cursor:
            cursor.close()
            return True
        return False
    
    def delete(self, table, where_clause, where_params):
        """Delete data from a table"""
        query = f"DELETE FROM {table} WHERE {where_clause}"
        cursor = self.execute_query(query, where_params)
        if cursor:
            cursor.close()
            return True
        return False

# Create global database instance
db = Database()
EOF
cat > seed.py << 'EOF'
#!/usr/bin/env python3

# ============================================
# SEED.PY - Seed Database with Sample Data
# Populates the database with test users and links
# ============================================

import sys
import os
import bcrypt

# Add parent directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))

from database import db
from models import User, Link, Click, init_database
from auth import Auth

def seed_database():
    """Seed the database with sample data"""
    
    print("=" * 50)
    print("🌱 SEEDING DATABASE WITH SAMPLE DATA")
    print("=" * 50)
    
    # Initialize database tables
    init_database()
    
    # Connect to database
    db.connect()
    
    # Sample users data
    sample_users = [
        {
            'email': 'john@example.com',
            'username': 'john_doe',
            'display_name': 'John Doe',
            'bio': 'Software Engineer & Content Creator',
            'password': 'password123'
        },
        {
            'email': 'jane@example.com',
            'username': 'jane_smith',
            'display_name': 'Jane Smith',
            'bio': 'Digital Artist & Illustrator',
            'password': 'password123'
        },
        {
            'email': 'mike@example.com',
            'username': 'mike_wilson',
            'display_name': 'Mike Wilson',
            'bio': 'Tech Blogger & Reviewer',
            'password': 'password123'
        },
        {
            'email': 'sarah@example.com',
            'username': 'sarah_art',
            'display_name': 'Sarah Johnson',
            'bio': 'Visual Storyteller',
            'password': 'password123'
        },
        {
            'email': 'alex@example.com',
            'username': 'alex_codes',
            'display_name': 'Alex Chen',
            'bio': 'Full Stack Developer',
            'password': 'password123'
        }
    ]
    
    # Insert users
    users_created = []
    for user_data in sample_users:
        # Check if user already exists
        existing = User.find_by_email(user_data['email'])
        if existing:
            print(f"⚠️ User {user_data['email']} already exists, skipping...")
            continue
        
        # Hash password
        hashed = Auth.hash_password(user_data['password'])
        
        # Create user
        user = User.create(
            user_data['email'],
            hashed,
            user_data['username'],
            user_data['display_name']
        )
        
        if user:
            users_created.append(user)
            # Update bio separately
            User.update(user['id'], {'bio': user_data['bio']})
            print(f"✅ Created user: {user_data['email']} (ID: {user['id']})")
    
    # Sample links for each user
    sample_links_by_platform = {
        'Instagram': 'https://instagram.com/',
        'YouTube': 'https://youtube.com/@',
        'Twitter': 'https://twitter.com/',
        'GitHub': 'https://github.com/',
        'LinkedIn': 'https://linkedin.com/in/',
        'TikTok': 'https://tiktok.com/@',
        'Website': 'https://',
        'Newsletter': 'https://substack.com/@',
        'Podcast': 'https://podcast.com/@'
    }
    
    # Add links for each user
    for user in users_created:
        print(f"\n📝 Adding links for {user['email']}...")
        username = user['username']
        
        for i, (platform, base_url) in enumerate(sample_links_by_platform.items()):
            if i > 4:  # Limit to 5 links per user
                break
            
            url = f"{base_url}{username}"
            link = Link.create(user['id'], platform, url)
            
            if link:
                # Simulate some random clicks
                import random
                random_clicks = random.randint(5, 100)
                for _ in range(random_clicks):
                    Link.increment_clicks(link['id'])
                
                print(f"  ✅ Added {platform}: {url} ({random_clicks} clicks)")
    
    # Display summary
    print("\n" + "=" * 50)
    print("📊 SEEDING SUMMARY")
    print("=" * 50)
    print(f"✅ Users created: {len(users_created)}")
    
    all_users = db.fetch_all("SELECT * FROM users")
    all_links = db.fetch_all("SELECT * FROM links")
    all_clicks = db.fetch_all("SELECT * FROM clicks")
    
    print(f"📁 Total users in database: {len(all_users)}")
    print(f"🔗 Total links in database: {len(all_links)}")
    print(f"👆 Total clicks tracked: {len(all_clicks)}")
    
    print("\n" + "=" * 50)
    print("📝 TEST ACCOUNTS")
    print("=" * 50)
    for user in all_users[:5]:  # Show first 5 users
        print(f"  Email: {user['email']}")
        print(f"  Password: password123")
        print(f"  Page: /api/profile/{user['username']}")
        print("-" * 30)
    
    # Disconnect
    db.disconnect()
    
    print("\n✅ Database seeding complete!")
    print("=" * 50)

if __name__ == '__main__':
    try:
        seed_database()
    except Exception as e:
        print(f"❌ Error seeding database: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
EOF

chmod +x seed.py
cat > backup.sh << 'EOF'
#!/bin/bash

# ============================================
# BACKUP.SH - Database Backup Script for LinkHub
# Creates automated backups of the database
# ============================================

# Configuration
BACKUP_DIR="/home/ec2-user/backups"
DB_NAME="linkhub"
DB_USER="postgres"
RETENTION_DAYS=30
S3_BUCKET="linkhub-backups"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}💾 LINKHUB DATABASE BACKUP${NC}"
echo -e "${GREEN}========================================${NC}"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Generate backup filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/linkhub_backup_$TIMESTAMP.sql"
COMPRESSED_FILE="$BACKUP_FILE.gz"

echo -e "${YELLOW}📤 Creating backup: $BACKUP_FILE${NC}"

# Create database backup
if pg_dump -U $DB_USER -h localhost $DB_NAME > $BACKUP_FILE 2>/dev/null; then
    echo -e "${GREEN}✅ Database backup created successfully${NC}"
else
    echo -e "${RED}❌ Failed to create database backup${NC}"
    exit 1
fi

# Compress the backup
echo -e "${YELLOW}🗜️ Compressing backup...${NC}"
gzip $BACKUP_FILE

if [ -f "$COMPRESSED_FILE" ]; then
    BACKUP_SIZE=$(du -h $COMPRESSED_FILE | cut -f1)
    echo -e "${GREEN}✅ Backup compressed: $BACKUP_SIZE${NC}"
else
    echo -e "${RED}❌ Failed to compress backup${NC}"
    exit 1
fi

# Upload to S3 (if AWS CLI is configured)
if command -v aws &> /dev/null && aws s3 ls s3://$S3_BUCKET &> /dev/null; then
    echo -e "${YELLOW}☁️ Uploading to S3...${NC}"
    aws s3 cp $COMPRESSED_FILE s3://$S3_BUCKET/backups/
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Backup uploaded to S3${NC}"
    else
        echo -e "${RED}⚠️ Failed to upload to S3${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ AWS CLI not configured or bucket not found. Skipping S3 upload.${NC}"
fi

# Clean up old backups
echo -e "${YELLOW}🧹 Cleaning up backups older than $RETENTION_DAYS days...${NC}"
find $BACKUP_DIR -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Count remaining backups
BACKUP_COUNT=$(ls -1 $BACKUP_DIR/*.sql.gz 2>/dev/null | wc -l)
echo -e "${GREEN}✅ Remaining backups: $BACKUP_COUNT${NC}"

# Send notification (optional)
# echo "LinkHub database backup completed at $TIMESTAMP" | mail -s "LinkHub Backup Complete" admin@linkhub.com

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ BACKUP COMPLETED SUCCESSFULLY${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "📁 Backup Location: $COMPRESSED_FILE"
echo -e "📊 Backup Size: $BACKUP_SIZE"
echo -e "📅 Created: $(date)"
echo -e "${GREEN}========================================${NC}"
EOF

chmod +x backup.sh
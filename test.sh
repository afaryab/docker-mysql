#!/bin/bash
set -euo pipefail

# MySQL Backup Docker Image - Test Script using Docker Compose
# This script tests the MySQL backup functionality using docker-compose

echo "🐳 Testing MySQL Backup Docker Image with Docker Compose"

# Clean up function
cleanup() {
    echo "🧹 Cleaning up..."
    docker-compose -f docker-compose.test.yml down -v 2>/dev/null || true
    sudo rm -rf test-backups 2>/dev/null || true
}

# Set up cleanup trap
trap cleanup EXIT

# Build the image first
echo "📦 Building Docker image..."
docker build -t ahmadfaryabkokab/mysql8:test .

echo "📁 Setting up test environment..."
mkdir -p test-backups

# Start services using docker-compose
echo "🚀 Starting MySQL with Docker Compose..."
docker-compose -f docker-compose.test.yml up -d

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL to start..."
for i in {1..20}; do
    if docker-compose -f docker-compose.test.yml exec -T mysql mysqladmin ping -h localhost -u root -ptestpass123 --silent 2>/dev/null; then
        echo "✅ MySQL is ready!"
        break
    fi
    echo "   Waiting... ($i/20)"
    sleep 2
done

if ! docker-compose -f docker-compose.test.yml exec -T mysql mysqladmin ping -h localhost -u root -ptestpass123 --silent 2>/dev/null; then
    echo "❌ MySQL failed to start properly"
    docker-compose -f docker-compose.test.yml logs mysql
    exit 1
fi

# Test database operations
echo "🧪 Testing database operations..."
docker-compose -f docker-compose.test.yml exec -T mysql mysql -uroot -ptestpass123 -e "
    CREATE DATABASE IF NOT EXISTS testdb;
    USE testdb;
    CREATE TABLE IF NOT EXISTS users (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(100), email VARCHAR(100));
    INSERT INTO users (name, email) VALUES 
        ('John Doe', 'john@example.com'),
        ('Jane Smith', 'jane@example.com'),
        ('Bob Wilson', 'bob@example.com');
    SELECT COUNT(*) as user_count FROM users;
"

# Test manual backup
echo "💾 Testing manual backup..."
docker-compose -f docker-compose.test.yml exec -T mysql /usr/local/bin/backup.sh

# Wait a moment for backup to complete
sleep 3

# Verify backup was created
if ls test-backups/mysql-*.sql.gz 1> /dev/null 2>&1; then
    echo "✅ Backup created successfully"
    BACKUP_FILE=$(ls -t test-backups/mysql-*.sql.gz | head -1)
    echo "   Backup file: $(basename "$BACKUP_FILE")"
    echo "   Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
else
    echo "❌ Backup creation failed"
    ls -la test-backups/ || echo "Backup directory is empty"
    exit 1
fi

# Test usage report
echo "📊 Testing usage report..."
docker-compose -f docker-compose.test.yml exec -T mysql /usr/local/bin/usage_report.sh

# Verify usage report was created
if ls test-backups/usage/*.json 1> /dev/null 2>&1; then
    echo "✅ Usage report created successfully"
    USAGE_FILE=$(ls -t test-backups/usage/*.json | head -1)
    echo "   Usage report: $(basename "$USAGE_FILE")"
    if command -v jq >/dev/null 2>&1; then
        echo "   Content preview:"
        cat "$USAGE_FILE" | jq . | head -10
    fi
else
    echo "❌ Usage report creation failed"
    ls -la test-backups/usage/ 2>/dev/null || echo "Usage directory not found"
    exit 1
fi

# Test backup verification by checking content
echo "🔍 Verifying backup content..."
if gunzip -c "$BACKUP_FILE" | grep -q "users"; then
    echo "✅ Backup contains expected data"
else
    echo "❌ Backup verification failed"
    exit 1
fi

# Test auto-recovery feature
echo "🔄 Testing auto-recovery feature..."

# Stop and remove containers but keep backup volume
docker-compose -f docker-compose.test.yml down

# Start fresh containers (this simulates data volume loss + recovery)
echo "🚀 Starting fresh containers for auto-recovery test..."
docker-compose -f docker-compose.test.yml up -d

# Wait for recovery and MySQL startup
echo "⏳ Waiting for auto-recovery and MySQL restart..."
for i in {1..90}; do
    if docker-compose -f docker-compose.test.yml exec -T mysql mysqladmin ping -h localhost -u root -ptestpass123 --silent 2>/dev/null; then
        echo "✅ Auto-recovery completed and MySQL is ready!"
        break
    fi
    echo "   Waiting for recovery... ($i/90)"
    sleep 3
done

# Verify data was restored
echo "🧪 Verifying restored data..."
sleep 5  # Give MySQL a moment to fully initialize

RESTORED_COUNT=$(docker-compose -f docker-compose.test.yml exec -T mysql mysql -uroot -ptestpass123 -e "USE testdb; SELECT COUNT(*) FROM users;" 2>/dev/null | tail -n1 | tr -d '\r')

if [ "$RESTORED_COUNT" = "3" ]; then
    echo "✅ Auto-recovery successful - all data restored!"
    docker-compose -f docker-compose.test.yml exec -T mysql mysql -uroot -ptestpass123 -e "USE testdb; SELECT * FROM users;"
else
    echo "❌ Auto-recovery failed - data not properly restored"
    echo "Expected 3 users, found: '$RESTORED_COUNT'"
    echo "Checking if databases exist..."
    docker-compose -f docker-compose.test.yml exec -T mysql mysql -uroot -ptestpass123 -e "SHOW DATABASES;"
    exit 1
fi

# Show container logs for debugging
echo "📋 Container logs (last 20 lines):"
docker-compose -f docker-compose.test.yml logs --tail 20 mysql

echo ""
echo "🎉 All tests passed! MySQL backup image is working correctly."
echo ""
echo "📋 Test Results Summary:"
echo "   ✅ Docker image builds successfully"
echo "   ✅ MySQL starts and accepts connections"
echo "   ✅ Manual backup creation works"
echo "   ✅ Usage reporting works"
echo "   ✅ Backup content verification passes"
echo "   ✅ Auto-recovery from backup works"
echo ""
echo "🚀 Image is ready for deployment!"

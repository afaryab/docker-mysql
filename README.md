# MySQL Backup Docker Image

A production-ready MySQL 8.0 Docker image with automated backup functionality, auto-recovery capabilities, and intelligent backup management.

[![Build and Release](https://github.com/afaryab/docker-mysql/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/afaryab/docker-mysql/actions/workflows/build-and-release.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/ahmadfaryabkokab/mysql8)](https://hub.docker.com/r/ahmadfaryabkokab/mysql8)

## Features

✅ **Automated Backups** - Scheduled via cron with customizable intervals  
✅ **Auto-Recovery** - Automatically restores from latest backup on fresh deployments  
✅ **Backup Encryption** - Optional AES encryption for backup files  
✅ **Intelligent Retention** - Clean old backups by age and/or count  
✅ **Usage Reporting** - Detailed database usage statistics  
✅ **Multi-Architecture** - Supports AMD64 and ARM64  
✅ **Production Ready** - Based on official MySQL 8.0 image  

## Quick Start

### Using Docker Compose (Recommended)

1. **Download the compose file:**
```bash
curl -O https://raw.githubusercontent.com/afaryab/docker-mysql/main/docker-compose.yml
```

2. **Set your password:**
```bash
export MYSQL_ROOT_PASSWORD=your-secure-password
```

3. **Start the service:**
```bash
docker-compose up -d
```

### Using Docker CLI

```bash
docker run -d \
  --name mysql-backup \
  -e MYSQL_ROOT_PASSWORD=your-secure-password \
  -e RETAIN_DAYS=7 \
  -e RETAIN_COUNT=10 \
  -v mysql_data:/var/lib/mysql \
  -v ./backups:/backups \
  -p 3306:3306 \
  ahmadfaryabkokab/mysql8:latest
```

## Sample Usage Examples

### 1. Basic Development Setup

Perfect for local development with daily backups:

```bash
# Create directories
mkdir -p ./mysql-data ./mysql-backups

# Run with basic configuration
docker run -d \
  --name mysql-dev \
  -e MYSQL_ROOT_PASSWORD=devpass123 \
  -e MYSQL_DATABASE=myapp \
  -e MYSQL_USER=appuser \
  -e MYSQL_PASSWORD=apppass123 \
  -e RETAIN_COUNT=5 \
  -v ./mysql-data:/var/lib/mysql \
  -v ./mysql-backups:/backups \
  -p 3306:3306 \
  ahmadfaryabkokab/mysql8:latest

# Connect to database
mysql -h localhost -u appuser -papppass123 myapp
```

### 2. Production Deployment with Encryption

Enterprise setup with encrypted backups and comprehensive retention:

```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  mysql:
    image: ahmadfaryabkokab/mysql8:latest
    container_name: mysql-prod
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: production_db
      MYSQL_USER: app_user
      MYSQL_PASSWORD: ${MYSQL_USER_PASSWORD}
      
      # Backup Configuration
      BACKUP_CRON: "0 2 * * *"          # Daily at 2 AM
      USAGE_CRON: "30 2 * * *"          # Daily at 2:30 AM
      PRUNE_CRON: "0 4 * * 0"           # Weekly cleanup on Sunday at 4 AM
      
      # Retention Policy
      RETAIN_DAYS: 30                    # Keep 30 days of backups
      RETAIN_COUNT: 50                   # Keep max 50 backups
      
      # PRODUCTION: Enable backup encryption (REQUIRED for production)
      # Uncomment these lines and set secure values:
      # BACKUP_ENCRYPT: "aes-256-cbc"
      # BACKUP_ENCRYPT_PASSWORD: ${BACKUP_ENCRYPTION_KEY}  # Use strong 32+ char password
      
      # Timezone
      TZ: "America/New_York"
      
    volumes:
      - mysql_prod_data:/var/lib/mysql
      - mysql_prod_backups:/backups
    ports:
      - "3306:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      timeout: 20s
      retries: 10

volumes:
  mysql_prod_data:
    driver: local
  mysql_prod_backups:
    driver: local
```

Deploy with:
```bash
# Set environment variables
export MYSQL_ROOT_PASSWORD="super-secure-root-password"
export MYSQL_USER_PASSWORD="secure-app-password"
# PRODUCTION: Set a strong encryption key (32+ characters)
# export BACKUP_ENCRYPTION_KEY="your-very-strong-32-character-encryption-key-here"

# Deploy
docker-compose -f docker-compose.prod.yml up -d
```

**🔐 Production Security Note:**
- **ALWAYS enable encryption in production** by uncommenting the encryption lines
- Use a strong encryption password (32+ characters)
- Store encryption keys securely (e.g., in a secrets manager)
- Example strong key: `"MyVerySecureBackupEncryptionKey2025!@#$"`

### 3. High-Frequency Backup Setup

For critical applications requiring frequent backups:

```yaml
version: '3.8'
services:
  mysql:
    image: ahmadfaryabkokab/mysql8:latest
    environment:
      MYSQL_ROOT_PASSWORD: criticalapp123
      MYSQL_DATABASE: critical_data
      
      # High-frequency backups
      BACKUP_CRON: "0 */4 * * *"        # Every 4 hours
      USAGE_CRON: "15 0 * * *"          # Daily usage report
      PRUNE_CRON: "30 0 * * *"          # Daily cleanup
      
      # Aggressive retention
      RETAIN_DAYS: 14                    # 2 weeks
      RETAIN_COUNT: 100                  # Up to 100 backups
      
      # PRODUCTION: Enable encryption for critical applications
      # Uncomment and set secure values:
      # BACKUP_ENCRYPT: "aes-256-cbc"
      # BACKUP_ENCRYPT_PASSWORD: "critical-app-encryption-key-2025-very-secure"
      
    volumes:
      - critical_data:/var/lib/mysql
      - critical_backups:/backups
    ports:
      - "3306:3306"

volumes:
  critical_data:
  critical_backups:
```

### 4. Development with Auto-Recovery Testing

Test the auto-recovery feature in development:

```bash
# Step 1: Start MySQL with sample data
docker run -d \
  --name mysql-recovery-test \
  -e MYSQL_ROOT_PASSWORD=testpass123 \
  -e MYSQL_DATABASE=testdb \
  -e RETAIN_COUNT=3 \
  -v recovery_data:/var/lib/mysql \
  -v recovery_backups:/backups \
  -p 3306:3306 \
  ahmadfaryabkokab/mysql8:latest

# Step 2: Add some test data
mysql -h localhost -u root -ptestpass123 -e "
  USE testdb;
  CREATE TABLE users (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(100), email VARCHAR(100));
  INSERT INTO users (name, email) VALUES 
    ('John Doe', 'john@example.com'),
    ('Jane Smith', 'jane@example.com'),
    ('Bob Johnson', 'bob@example.com');
  SELECT * FROM users;
"

# Step 3: Create manual backup
docker exec mysql-recovery-test /usr/local/bin/backup.sh

# Step 4: Simulate data loss
docker stop mysql-recovery-test
docker volume rm recovery_data

# Step 5: Start fresh container (auto-recovery will restore from backup)
docker run -d \
  --name mysql-recovered \
  -e MYSQL_ROOT_PASSWORD=testpass123 \
  -e MYSQL_DATABASE=testdb \
  -v recovery_new_data:/var/lib/mysql \
  -v recovery_backups:/backups \
  -p 3306:3306 \
  ahmadfaryabkokab/mysql8:latest

# Step 6: Verify data recovery (wait 30 seconds for startup)
sleep 30
mysql -h localhost -u root -ptestpass123 -e "USE testdb; SELECT * FROM users;"
```

### 5. Multi-Environment Setup with Shared Backups

Development, staging, and production environments sharing backup storage:

```yaml
# docker-compose.multi-env.yml
version: '3.8'

services:
  # Development Environment
  mysql-dev:
    image: ahmadfaryabkokab/mysql8:latest
    container_name: mysql-dev
    environment:
      MYSQL_ROOT_PASSWORD: dev_password_123
      MYSQL_DATABASE: myapp_dev
      BACKUP_CRON: "0 */6 * * *"        # Every 6 hours
      RETAIN_COUNT: 10
      AUTO_RECOVER: "true"
    volumes:
      - mysql_dev_data:/var/lib/mysql
      - shared_backups:/backups/dev     # Separate backup directory
    ports:
      - "3306:3306"

  # Staging Environment  
  mysql-staging:
    image: ahmadfaryabkokab/mysql8:latest
    container_name: mysql-staging
    environment:
      MYSQL_ROOT_PASSWORD: staging_password_456
      MYSQL_DATABASE: myapp_staging
      BACKUP_CRON: "0 */3 * * *"        # Every 3 hours
      RETAIN_COUNT: 20
      AUTO_RECOVER: "true"
    volumes:
      - mysql_staging_data:/var/lib/mysql
      - shared_backups:/backups/staging
    ports:
      - "3307:3306"

  # Production Environment
  mysql-prod:
    image: ahmadfaryabkokab/mysql8:latest
    container_name: mysql-prod
    environment:
      MYSQL_ROOT_PASSWORD: ${PROD_MYSQL_PASSWORD}
      MYSQL_DATABASE: myapp_production
      BACKUP_CRON: "0 1 * * *"          # Daily at 1 AM
      RETAIN_DAYS: 30
      RETAIN_COUNT: 100
      
      # PRODUCTION: Enable encryption (REQUIRED)
      # Uncomment these lines:
      # BACKUP_ENCRYPT: "aes-256-cbc"
      # BACKUP_ENCRYPT_PASSWORD: ${BACKUP_KEY}  # Use strong encryption key
      
      AUTO_RECOVER: "true"
    volumes:
      - mysql_prod_data:/var/lib/mysql
      - shared_backups:/backups/prod
    ports:
      - "3308:3306"

volumes:
  mysql_dev_data:
  mysql_staging_data:
  mysql_prod_data:
  shared_backups:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/mysql-backups        # Shared backup storage
```

### 6. Kubernetes Deployment Example

Production-ready Kubernetes deployment:

```yaml
# mysql-backup-k8s.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secrets
type: Opaque
stringData:
  root-password: "your-super-secure-password"
  backup-encryption-key: "your-32-character-encryption-key"

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-backups-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-backup
  labels:
    app: mysql-backup
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-backup
  template:
    metadata:
      labels:
        app: mysql-backup
    spec:
      containers:
      - name: mysql
        image: ahmadfaryabkokab/mysql8:latest
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secrets
              key: root-password
        - name: MYSQL_DATABASE
          value: "production_app"
        - name: BACKUP_CRON
          value: "0 2 * * *"
        - name: RETAIN_DAYS
          value: "30"
        - name: RETAIN_COUNT
          value: "100"
        - name: BACKUP_ENCRYPT
          value: "aes-256-cbc"
        - name: BACKUP_ENCRYPT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secrets
              key: backup-encryption-key
        - name: TZ
          value: "UTC"
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        - name: mysql-backups
          mountPath: /backups
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -h
            - localhost
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - mysql
            - -h
            - localhost
            - -u
            - root
            - -p$(MYSQL_ROOT_PASSWORD)
            - -e
            - "SELECT 1"
          initialDelaySeconds: 5
          periodSeconds: 2
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-data-pvc
      - name: mysql-backups
        persistentVolumeClaim:
          claimName: mysql-backups-pvc

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-backup-service
spec:
  selector:
    app: mysql-backup
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP
```

Deploy with:
```bash
kubectl apply -f mysql-backup-k8s.yaml
```

### 7. Monitoring and Maintenance Scripts

Useful scripts for monitoring and maintenance:

```bash
#!/bin/bash
# monitor-mysql-backup.sh

echo "=== MySQL Backup Status Report ==="
echo "Date: $(date)"
echo

# Container status
echo "📊 Container Status:"
docker ps --filter "name=mysql" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo

# Backup directory status
echo "💾 Recent Backups:"
ls -lah ./mysql-backups/*.gz 2>/dev/null | tail -5
echo

# Disk usage
echo "💿 Disk Usage:"
du -sh ./mysql-backups 2>/dev/null || echo "No backup directory found"
echo

# Recent logs
echo "📋 Recent Activity (last 20 lines):"
docker logs mysql-backup 2>/dev/null | tail -20
echo

# Database size
echo "🗄️ Database Sizes:"
docker exec mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "
  SELECT 
    table_schema as 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as 'Size (MB)'
  FROM information_schema.tables 
  WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
  GROUP BY table_schema;
" 2>/dev/null
```

### 8. Backup Restoration Examples

Manual backup restoration scenarios:

```bash
# Restore from specific backup file
BACKUP_FILE="mysql-20250819-030001.sql.gz"

# Method 1: Restore to running container
docker exec -i mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD < \
  <(docker exec mysql-backup zcat /backups/$BACKUP_FILE)

# Method 2: Restore to new container
docker run -d \
  --name mysql-restored \
  -e MYSQL_ROOT_PASSWORD=restored_pass \
  -e AUTO_RECOVER=false \
  -v restored_data:/var/lib/mysql \
  -v ./mysql-backups:/backups \
  ahmadfaryabkokab/mysql8:latest

# Wait for startup
sleep 30

# Restore the backup
docker exec mysql-restored zcat /backups/$BACKUP_FILE | \
  mysql -uroot -prestored_pass

# Method 3: Restore encrypted backup
ENCRYPT_PASSWORD="your-encryption-password"
docker exec mysql-backup openssl enc -aes-256-cbc -d \
  -in /backups/mysql-20250819-030001.sql.gz.enc \
  -pass pass:$ENCRYPT_PASSWORD | \
  zcat | mysql -uroot -p$MYSQL_ROOT_PASSWORD
```

## Auto-Recovery Feature

The **auto-recovery** feature automatically detects when MySQL is starting with an empty data directory and restores from the latest available backup. This is perfect for scenarios where:

- Persistent volumes are accidentally deleted
- Deploying to a new environment
- Disaster recovery situations

### How it works:

1. **Detection**: On startup, checks if MySQL data directory is empty
2. **Search**: Looks for the latest backup in `/backups` directory
3. **Restore**: Automatically restores from the most recent backup
4. **Continue**: Proceeds with normal MySQL startup

To disable auto-recovery, set `AUTO_RECOVER=false`.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MYSQL_ROOT_PASSWORD` | - | **Required** - MySQL root password |
| `MYSQL_DATABASE` | - | Optional database to create |
| `MYSQL_USER` | - | Optional user to create |
| `MYSQL_PASSWORD` | - | Password for optional user |
| `BACKUP_DIR` | `/backups` | Directory to store backups |
| `RETAIN_DAYS` | - | Delete backups older than N days |
| `RETAIN_COUNT` | - | Keep only latest N backups |
| `AUTO_RECOVER` | `true` | Enable auto-recovery from backups |
| `BACKUP_CRON` | `0 3 * * *` | Backup schedule (daily at 3 AM) |
| `USAGE_CRON` | `5 3 * * *` | Usage report schedule |
| `PRUNE_CRON` | `15 3 * * *` | Backup cleanup schedule |
| `BACKUP_ENCRYPT` | - | Encryption cipher (e.g., `aes-256-cbc`) |
| `BACKUP_ENCRYPT_PASSWORD` | - | Encryption password |
| `TZ` | `UTC` | Timezone for schedules |

### Backup Encryption

**Development (Default - No Encryption):**
```yaml
environment:
  # Encryption disabled by default for development
  # BACKUP_ENCRYPT: ""
  # BACKUP_ENCRYPT_PASSWORD: ""
```

**Production (Encryption Required):**
```yaml
environment:
  # REQUIRED for production environments
  BACKUP_ENCRYPT: "aes-256-cbc"
  BACKUP_ENCRYPT_PASSWORD: "YourVerySecure32CharEncryptionKey2025!"
```

**Available encryption ciphers:**
- `aes-256-cbc` (Recommended)
- `aes-192-cbc`
- `aes-128-cbc`
- `des3`

**⚠️ Production Security Requirements:**
- **ALWAYS enable encryption in production environments**
- Use a strong password (minimum 32 characters)
- Include uppercase, lowercase, numbers, and special characters
- Store encryption keys in a secure secrets manager
- **Without the encryption password, encrypted backups cannot be restored**

**Example secure encryption key:**
```bash
# Generate a secure key
openssl rand -base64 32
# Example output: "mK8x9vL3nQ7pR2sT4wU6yE9rA5dF8hJ1"
```

**When to use encryption:**
- ✅ **Production environments** (always required)
- ✅ **Staging environments** with real data
- ✅ **Cloud storage** or shared backup volumes
- ✅ **Compliance requirements** (GDPR, HIPAA, etc.)
- ❌ **Local development** (optional, disabled by default)
- ❌ **Testing environments** with dummy data

### Backup Retention

Control backup retention with two methods:

```yaml
environment:
  RETAIN_DAYS: 30      # Keep backups for 30 days
  RETAIN_COUNT: 50     # Keep latest 50 backups
```

Both can be used together - the most restrictive rule applies.

## Manual Operations

### Create Manual Backup

```bash
# Create backup immediately
docker exec mysql-backup /usr/local/bin/backup.sh

# Create backup with custom name
docker exec mysql-backup bash -c 'BACKUP_PREFIX="manual-backup" /usr/local/bin/backup.sh'

# Check backup was created
docker exec mysql-backup ls -la /backups/
```

### Generate Usage Report

```bash
# Generate current usage report
docker exec mysql-backup /usr/local/bin/usage_report.sh

# View the latest usage report
docker exec mysql-backup cat /backups/usage/usage-$(date +%Y%m%d-*)*.json
```

### Clean Old Backups

```bash
# Clean old backups using configured retention policy
docker exec mysql-backup /usr/local/bin/prune_backups.sh

# Force cleanup with custom retention (keep only 5 latest)
docker exec mysql-backup bash -c 'RETAIN_COUNT=5 /usr/local/bin/prune_backups.sh'

# Force cleanup by days (keep only last 7 days)
docker exec mysql-backup bash -c 'RETAIN_DAYS=7 /usr/local/bin/prune_backups.sh'
```

### Database Management Examples

```bash
# Connect to MySQL as root
docker exec -it mysql-backup mysql -uroot -p

# Execute SQL from file
docker exec -i mysql-backup mysql -uroot -p < my_script.sql

# Dump specific database
docker exec mysql-backup mysqldump -uroot -p my_database > local_backup.sql

# Import SQL file
docker exec -i mysql-backup mysql -uroot -p my_database < local_backup.sql

# Show database sizes
docker exec mysql-backup mysql -uroot -p -e "
  SELECT 
    table_schema as 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as 'Size (MB)'
  FROM information_schema.tables 
  WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
  GROUP BY table_schema;
"
```

### Backup Verification and Testing

```bash
# List all available backups
docker exec mysql-backup ls -lah /backups/*.gz

# Check backup file integrity
docker exec mysql-backup gzip -t /backups/mysql-20250819-030001.sql.gz

# Preview backup contents (first 20 lines)
docker exec mysql-backup zcat /backups/mysql-20250819-030001.sql.gz | head -20

# Verify encrypted backup
docker exec mysql-backup openssl enc -aes-256-cbc -d \
  -in /backups/mysql-20250819-030001.sql.gz.enc \
  -pass pass:your-encryption-password | gzip -t

# Test restore to temporary database
BACKUP_FILE="mysql-20250819-030001.sql.gz"
docker exec mysql-backup mysql -uroot -p -e "CREATE DATABASE test_restore;"
docker exec mysql-backup zcat /backups/$BACKUP_FILE | \
  mysql -uroot -p test_restore
```

### Monitoring and Maintenance

```bash
# Check backup schedule status
docker exec mysql-backup crontab -l

# View recent backup activity
docker exec mysql-backup tail -50 /var/log/cron

# Monitor disk usage
docker exec mysql-backup df -h /backups

# Check MySQL status and performance
docker exec mysql-backup mysql -uroot -p -e "SHOW GLOBAL STATUS LIKE 'Uptime%';"
docker exec mysql-backup mysql -uroot -p -e "SHOW PROCESSLIST;"

# View MySQL error log
docker exec mysql-backup tail -50 /var/log/mysql/error.log

# Check container resource usage
docker stats mysql-backup --no-stream
```

### Emergency Recovery Procedures

```bash
# Full disaster recovery (restore from backup to new environment)
# Step 1: Prepare new environment
docker run -d \
  --name mysql-emergency \
  -e MYSQL_ROOT_PASSWORD=emergency_pass \
  -e AUTO_RECOVER=false \
  -v emergency_data:/var/lib/mysql \
  -v ./existing-backups:/backups \
  -p 3307:3306 \
  ahmadfaryabkokab/mysql8:latest

# Step 2: Wait for startup
sleep 30

# Step 3: Restore from latest backup
LATEST_BACKUP=$(docker exec mysql-emergency ls -t /backups/mysql-*.sql.gz | head -1)
docker exec mysql-emergency zcat /backups/$LATEST_BACKUP | \
  mysql -uroot -pemergency_pass

# Point-in-time recovery (if you have binary logs)
# This requires additional setup with binary logging enabled
docker exec mysql-backup mysql -uroot -p -e "SHOW BINARY LOGS;"
```

### Backup Migration Between Environments

```bash
# Export backup from one environment
docker exec source-mysql /usr/local/bin/backup.sh
docker cp source-mysql:/backups/mysql-latest.sql.gz ./migration-backup.sql.gz

# Import to new environment
docker cp ./migration-backup.sql.gz target-mysql:/tmp/
docker exec target-mysql zcat /tmp/migration-backup.sql.gz | mysql -uroot -p

# Or use direct pipe between containers
docker exec source-mysql /usr/local/bin/backup.sh
docker exec source-mysql cat /backups/mysql-latest.sql.gz | \
  docker exec -i target-mysql zcat | \
  docker exec -i target-mysql mysql -uroot -p
```

### Force Recovery from Backup

```bash
# Method 1: Using docker-compose (recommended)
docker-compose down
docker volume rm $(docker-compose config --volumes)
docker-compose up -d

# Method 2: Manual recovery for standalone container
docker stop mysql-backup
docker rm mysql-backup
docker volume rm mysql_data  # Be careful - this deletes data!

# Start fresh container with same backup volume
docker run -d \
  --name mysql-backup \
  -e MYSQL_ROOT_PASSWORD=your-password \
  -e AUTO_RECOVER=true \
  -v mysql_fresh_data:/var/lib/mysql \
  -v mysql_backups:/backups \
  -p 3306:3306 \
  ahmadfaryabkokab/mysql8:latest

# Method 3: Force recovery on existing container
docker exec mysql-backup rm -rf /var/lib/mysql/*
docker restart mysql-backup
```

## Production Deployment

### Docker Compose Setup

1. **Create environment file:**
```bash
cp docker-compose.example.yml .env
# Edit .env with your settings
```

2. **Deploy:**
```bash
docker-compose up -d
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-backup
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-backup
  template:
    metadata:
      labels:
        app: mysql-backup
    spec:
      containers:
      - name: mysql
        image: ahmadfaryabkokab/mysql8:latest
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        - name: RETAIN_DAYS
          value: "30"
        - name: RETAIN_COUNT
          value: "100"
        # PRODUCTION: Enable backup encryption
        # Uncomment these lines and create appropriate secrets:
        # - name: BACKUP_ENCRYPT
        #   value: "aes-256-cbc"
        # - name: BACKUP_ENCRYPT_PASSWORD
        #   valueFrom:
        #     secretKeyRef:
        #       name: mysql-backup-secret
        #       key: encryption-password
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        - name: mysql-backups
          mountPath: /backups
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-data
      - name: mysql-backups
        persistentVolumeClaim:
          claimName: mysql-backups
```

## Monitoring

### Health Check

The image includes a built-in health check:

```bash
docker inspect --format='{{.State.Health.Status}}' mysql-backup
```

### Logs

Monitor backup operations:

```bash
docker logs -f mysql-backup
```

### Usage Reports

Usage reports are stored in `${BACKUP_DIR}/usage/` as JSON files:

```json
{
  "timestamp": "2025-08-19T03:05:01Z",
  "server_version": "8.0.35",
  "uptime_seconds": 86400,
  "databases": [
    {
      "name": "myapp",
      "size_mb": 1024.5,
      "tables": 15
    }
  ],
  "total_size_mb": 2048.7,
  "backup_size_mb": 512.3
}
```

## Backup File Structure

```
/backups/
├── mysql-20250819-030001.sql.gz          # Compressed backup
├── mysql-20250819-030001.sql.gz.enc      # Encrypted backup (if enabled)
└── usage/
    └── usage-20250819-030501.json        # Usage report
```

## Testing

### Local Testing

```bash
# Run comprehensive tests
./test.sh

# Or test with docker-compose
docker-compose -f docker-compose.test.yml up -d
```

### CI/CD Testing

The project includes GitHub Actions workflow that:
- Builds multi-architecture images
- Runs comprehensive tests
- Publishes to Docker Hub
- Creates GitHub releases

## Troubleshooting

### Common Issues and Solutions

#### 1. Backup Creation Problems

**Backup fails with permission error:**
```bash
# Check backup directory permissions
docker exec mysql-backup ls -la /backups

# Fix permission issues
docker exec mysql-backup chown -R mysql:mysql /backups
docker exec mysql-backup chmod 755 /backups

# Test manual backup
docker exec mysql-backup /usr/local/bin/backup.sh
```

**Backup directory not accessible:**
```bash
# Check if backup directory exists
docker exec mysql-backup ls -la /backups

# Create backup directory if missing
docker exec mysql-backup mkdir -p /backups
docker exec mysql-backup chown mysql:mysql /backups

# Check volume mounts
docker inspect mysql-backup | grep -A 10 "Mounts"
```

**Backup files corrupted or empty:**
```bash
# Check backup file integrity
docker exec mysql-backup ls -lah /backups/
docker exec mysql-backup gzip -t /backups/mysql-*.sql.gz

# Test backup manually with verbose output
docker exec mysql-backup bash -c '
  mysqldump -uroot -p$MYSQL_ROOT_PASSWORD \
    --single-transaction \
    --routines \
    --triggers \
    --all-databases \
    --verbose
'

# Check available disk space
docker exec mysql-backup df -h /backups
```

#### 2. Auto-Recovery Issues

**Auto-recovery not working:**
```bash
# Check if AUTO_RECOVER is enabled
docker exec mysql-backup env | grep AUTO_RECOVER

# Verify backup files exist
docker exec mysql-backup ls -la /backups/mysql-*.sql.gz

# Check auto-recovery logs
docker logs mysql-backup | grep -i "recovery\|restore"

# Manual recovery test
docker exec mysql-backup /usr/local/bin/auto_recover.sh
```

**Recovery restores wrong/old data:**
```bash
# List backups by date
docker exec mysql-backup ls -lt /backups/mysql-*.sql.gz

# Check what backup was used for recovery
docker logs mysql-backup | grep "Restoring from backup"

# Force recovery from specific backup
docker exec mysql-backup bash -c '
  BACKUP_FILE="/backups/mysql-20250819-030001.sql.gz"
  if [ -f "$BACKUP_FILE" ]; then
    echo "Restoring from $BACKUP_FILE"
    zcat "$BACKUP_FILE" | mysql -uroot -p$MYSQL_ROOT_PASSWORD
  fi
'
```

#### 3. Database Connection Problems

**Cannot connect to MySQL:**
```bash
# Check if MySQL is running
docker exec mysql-backup mysqladmin ping -uroot -p$MYSQL_ROOT_PASSWORD

# Check MySQL status
docker exec mysql-backup systemctl status mysql 2>/dev/null || \
  docker exec mysql-backup ps aux | grep mysql

# Test connection with basic client
docker exec mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT 1;"

# Check MySQL error logs
docker exec mysql-backup tail -50 /var/log/mysql/error.log
```

**Connection refused errors:**
```bash
# Check if port is exposed
docker port mysql-backup

# Test network connectivity
docker exec mysql-backup netstat -tlnp | grep 3306

# Verify container is healthy
docker inspect mysql-backup | grep -A 5 '"Health"'

# Check firewall/network issues
telnet localhost 3306
```

#### 4. Encryption and Security Issues

**Encrypted backup restore fails:**
```bash
# Verify encryption password is set
docker exec mysql-backup env | grep BACKUP_ENCRYPT_PASSWORD

# Test encryption/decryption manually
docker exec mysql-backup bash -c '
  echo "test data" | openssl enc -aes-256-cbc -pass pass:$BACKUP_ENCRYPT_PASSWORD | \
  openssl enc -aes-256-cbc -d -pass pass:$BACKUP_ENCRYPT_PASSWORD
'

# Check encrypted backup file
docker exec mysql-backup file /backups/mysql-*.sql.gz.enc

# Manual decrypt and restore
docker exec mysql-backup bash -c '
  openssl enc -aes-256-cbc -d \
    -in /backups/mysql-20250819-030001.sql.gz.enc \
    -pass pass:$BACKUP_ENCRYPT_PASSWORD | \
  zcat | mysql -uroot -p$MYSQL_ROOT_PASSWORD
'
```

#### 5. Cron and Scheduling Problems

**Automated backups not running:**
```bash
# Check cron service status
docker exec mysql-backup ps aux | grep cron

# View current crontab
docker exec mysql-backup crontab -l

# Check cron logs
docker exec mysql-backup tail -f /var/log/cron &
# Wait for next scheduled time or...

# Test cron manually
docker exec mysql-backup run-parts /etc/cron.daily

# Force backup execution
docker exec mysql-backup /usr/local/bin/backup.sh
```

**Wrong timezone affecting schedules:**
```bash
# Check current timezone
docker exec mysql-backup date
docker exec mysql-backup cat /etc/timezone

# Set correct timezone
docker stop mysql-backup
docker run -d \
  --name mysql-backup-new \
  -e TZ="America/New_York" \
  -e MYSQL_ROOT_PASSWORD=your-password \
  ahmadfaryabkokab/mysql8:latest

# Verify timezone change
docker exec mysql-backup-new date
```

#### 6. Storage and Performance Issues

**Out of disk space:**
```bash
# Check available space
docker exec mysql-backup df -h

# Check backup directory size
docker exec mysql-backup du -sh /backups

# Clean old backups manually
docker exec mysql-backup /usr/local/bin/prune_backups.sh

# Find large files
docker exec mysql-backup find /backups -size +100M -ls
```

**Slow backup performance:**
```bash
# Check MySQL processes during backup
docker exec mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SHOW PROCESSLIST;"

# Monitor I/O during backup
docker stats mysql-backup --no-stream

# Use faster compression (if space allows)
docker exec mysql-backup bash -c '
  mysqldump -uroot -p$MYSQL_ROOT_PASSWORD \
    --single-transaction \
    --all-databases | \
  gzip -1 > /backups/mysql-fast-$(date +%Y%m%d-%H%M%S).sql.gz
'
```

### Debug Mode and Verbose Logging

**Enable detailed logging:**
```bash
# View all container logs
docker logs -f mysql-backup

# Filter specific operations
docker logs mysql-backup 2>&1 | grep -i "backup\|error\|cron"

# Enable MySQL general log (temporarily)
docker exec mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "
  SET GLOBAL general_log = 'ON';
  SET GLOBAL general_log_file = '/var/log/mysql/general.log';
"

# View MySQL general log
docker exec mysql-backup tail -f /var/log/mysql/general.log

# Disable general log (when done debugging)
docker exec mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "
  SET GLOBAL general_log = 'OFF';
"
```

**Script debugging:**
```bash
# Run backup script with debug output
docker exec mysql-backup bash -x /usr/local/bin/backup.sh

# Test individual components
docker exec mysql-backup bash -c 'echo $MYSQL_ROOT_PASSWORD'
docker exec mysql-backup which mysqldump
docker exec mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;"
```

### Health Checks and Monitoring

**Container health status:**
```bash
# Check container health
docker inspect mysql-backup | grep -A 10 '"Health"'

# Manual health check
docker exec mysql-backup mysqladmin ping -uroot -p$MYSQL_ROOT_PASSWORD

# Check all services
docker exec mysql-backup ps aux
```

**Performance monitoring:**
```bash
# Resource usage
docker stats mysql-backup --no-stream

# MySQL performance metrics
docker exec mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "
  SHOW GLOBAL STATUS LIKE 'Threads_%';
  SHOW GLOBAL STATUS LIKE 'Questions';
  SHOW GLOBAL STATUS LIKE 'Uptime';
"

# Backup operation monitoring
docker exec mysql-backup bash -c '
  while true; do
    echo "$(date): $(ps aux | grep mysqldump | wc -l) backup processes running"
    sleep 5
  done
'
```

### Recovery and Rollback Procedures

**Emergency rollback:**
```bash
# Stop current container
docker stop mysql-backup

# Start with previous backup
docker run -d \
  --name mysql-rollback \
  -e MYSQL_ROOT_PASSWORD=your-password \
  -e AUTO_RECOVER=false \
  -v mysql_rollback_data:/var/lib/mysql \
  -v mysql_backups:/backups \
  -p 3306:3306 \
  ahmadfaryabkokab/mysql8:latest

# Restore specific backup
ROLLBACK_BACKUP="mysql-20250818-030001.sql.gz"  # Yesterday's backup
docker exec mysql-rollback zcat /backups/$ROLLBACK_BACKUP | \
  mysql -uroot -pyour-password
```

**Data corruption recovery:**
```bash
# Check for corruption
docker exec mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "
  CHECK TABLE information_schema.tables;
"

# Repair tables if possible
docker exec mysql-backup mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "
  REPAIR TABLE your_database.your_table;
"

# If repair fails, restore from backup
docker exec mysql-backup /usr/local/bin/auto_recover.sh
```

### Getting Help

**Collect diagnostic information:**
```bash
#!/bin/bash
# diagnostic-report.sh
echo "=== MySQL Backup Diagnostic Report ===" > diagnostic-report.txt
echo "Date: $(date)" >> diagnostic-report.txt
echo "" >> diagnostic-report.txt

echo "=== Container Status ===" >> diagnostic-report.txt
docker ps --filter "name=mysql" >> diagnostic-report.txt
echo "" >> diagnostic-report.txt

echo "=== Environment Variables ===" >> diagnostic-report.txt
docker exec mysql-backup env | grep -E "MYSQL|BACKUP|RETAIN|AUTO_RECOVER" >> diagnostic-report.txt
echo "" >> diagnostic-report.txt

echo "=== Backup Files ===" >> diagnostic-report.txt
docker exec mysql-backup ls -lah /backups/ >> diagnostic-report.txt
echo "" >> diagnostic-report.txt

echo "=== Recent Logs ===" >> diagnostic-report.txt
docker logs mysql-backup --tail 100 >> diagnostic-report.txt
echo "" >> diagnostic-report.txt

echo "Diagnostic report saved to diagnostic-report.txt"
```

This comprehensive troubleshooting guide should help resolve most common issues with the MySQL backup Docker image.

## Development

### Building Locally

```bash
# Build the image
docker build -t ahmadfaryabkokab/mysql8:local .

# Run tests
docker-compose -f docker-compose.test.yml up --build
```

### Versioning and Releases

This project uses automated semantic versioning with GitHub Actions. There are three ways to create a new release:

#### 1. Automatic Version Detection (Recommended)

Push commits to the `main` branch. The workflow automatically determines the version bump based on commit messages:

- **Major version** (`1.0.0 → 2.0.0`): Commit messages containing `BREAKING CHANGE` or `major:`
- **Minor version** (`1.0.0 → 1.1.0`): Commit messages containing `feat`, `feature`, or `minor:`
- **Patch version** (`1.0.0 → 1.0.1`): All other commits

```bash
git commit -m "feat: add new backup encryption feature"  # → Minor version bump
git commit -m "fix: resolve backup cleanup issue"        # → Patch version bump
git commit -m "BREAKING CHANGE: update API interface"    # → Major version bump
```

#### 2. Manual Version Control Script

Use the included version management script:

```bash
# Patch version (1.0.0 → 1.0.1)
./version.sh patch

# Minor version (1.0.0 → 1.1.0)  
./version.sh minor

# Major version (1.0.0 → 2.0.0)
./version.sh major
```

The script will:
- Show current version and upcoming changes
- Create and push a version tag
- Trigger the automated release workflow

#### 3. Manual Workflow Dispatch

Trigger releases manually from GitHub Actions:

1. Go to **Actions** → **Build and Release Docker Image**
2. Click **Run workflow**
3. Select version bump type (patch/minor/major)
4. Click **Run workflow**

#### Release Process

When a new version is created, the automated workflow:

1. **Calculates** the next semantic version
2. **Creates** a Git tag (e.g., `v1.2.3`)
3. **Builds** multi-architecture Docker images
4. **Tests** the images with comprehensive test suite
5. **Releases** to GitHub with auto-generated release notes
6. **Pushes** versioned images to Docker Hub:
   - `ahmadfaryabkokab/mysql8:1.2.3` (version-specific)
   - `ahmadfaryabkokab/mysql8:latest` (latest stable)

#### Development Builds

Non-main branches automatically build development images tagged with the branch name:
- `ahmadfaryabkokab/mysql8:develop`
- `ahmadfaryabkokab/mysql8:feature-xyz`

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Run tests: `./test.sh`
5. Commit with descriptive messages
6. Push to your fork
7. Submit a pull request

The CI/CD pipeline will automatically test your changes and build preview images.

## Quick Reference

### Security Checklist for Production

| Component | Development | Production |
|-----------|-------------|------------|
| **Backup Encryption** | ❌ Disabled (default) | ✅ **Required** |
| **Encryption Cipher** | - | `aes-256-cbc` |
| **Encryption Key** | - | 32+ chars, generated securely |
| **Key Storage** | - | Secrets manager/vault |
| **Backup Retention** | 3-7 days | 30+ days |
| **Access Control** | Local only | Restricted network/VPN |

### Environment Variables Quick Reference

```bash
# Development
MYSQL_ROOT_PASSWORD=devpass123
RETAIN_COUNT=5
# BACKUP_ENCRYPT=""                    # Disabled

# Production
MYSQL_ROOT_PASSWORD=super-secure-password
RETAIN_DAYS=30
RETAIN_COUNT=100
BACKUP_ENCRYPT=aes-256-cbc            # Required
BACKUP_ENCRYPT_PASSWORD=YourSecureKey32Characters2025!
```

### Command Cheatsheet

```bash
# Start with encryption disabled (development)
docker run -d --name mysql-dev \
  -e MYSQL_ROOT_PASSWORD=devpass123 \
  -v ./backups:/backups \
  ahmadfaryabkokab/mysql8:latest

# Start with encryption enabled (production)
docker run -d --name mysql-prod \
  -e MYSQL_ROOT_PASSWORD=secure-password \
  -e BACKUP_ENCRYPT=aes-256-cbc \
  -e BACKUP_ENCRYPT_PASSWORD=YourSecureKey32Chars! \
  -v ./backups:/backups \
  ahmadfaryabkokab/mysql8:latest

# Generate secure encryption key
openssl rand -base64 32
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/afaryab/docker-mysql/issues)
- **Docker Hub**: [ahmadfaryabkokab/mysql8](https://hub.docker.com/r/ahmadfaryabkokab/mysql8)
- **Documentation**: This README and inline code comments
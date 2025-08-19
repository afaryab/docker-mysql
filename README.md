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

Enable encryption for backup files:

```yaml
environment:
  BACKUP_ENCRYPT: "aes-256-cbc"
  BACKUP_ENCRYPT_PASSWORD: "your-encryption-key"
```

**⚠️ Important**: Store the encryption password securely. Without it, encrypted backups cannot be restored.

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
docker exec mysql-backup /usr/local/bin/backup.sh
```

### Generate Usage Report

```bash
docker exec mysql-backup /usr/local/bin/usage_report.sh
```

### Clean Old Backups

```bash
docker exec mysql-backup /usr/local/bin/prune_backups.sh
```

### Force Recovery from Backup

```bash
# Stop MySQL, clear data, restart to trigger recovery
docker-compose down
docker volume rm $(docker-compose config --volumes)
docker-compose up -d
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

### Common Issues

**Backup fails with permission error:**
```bash
# Check backup directory permissions
docker exec mysql-backup ls -la /backups
```

**Auto-recovery not working:**
```bash
# Check if AUTO_RECOVER is enabled
docker exec mysql-backup env | grep AUTO_RECOVER

# Check backup directory
docker exec mysql-backup ls -la /backups
```

**Encrypted backup restore fails:**
```bash
# Verify encryption password is set
docker exec mysql-backup env | grep BACKUP_ENCRYPT_PASSWORD
```

### Debug Mode

Enable verbose logging:

```bash
docker logs mysql-backup
```

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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/afaryab/docker-mysql/issues)
- **Docker Hub**: [ahmadfaryabkokab/mysql8](https://hub.docker.com/r/ahmadfaryabkokab/mysql8)
- **Documentation**: This README and inline code comments
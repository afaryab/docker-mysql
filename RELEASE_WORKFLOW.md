# Release Workflow Guide

This document explains the automated versioning and release workflow for the MySQL Backup Docker image.

## Overview

The project now includes a fully automated CI/CD pipeline that:

1. **Automatically calculates** semantic versions based on commit messages
2. **Creates GitHub releases** with auto-generated release notes  
3. **Builds and pushes** versioned Docker images to Docker Hub
4. **Runs comprehensive tests** before each release
5. **Supports manual version control** for precise control

## Workflow Triggers

### 1. Automatic Versioning (Main Branch)

When you push to the `main` branch, the workflow analyzes commit messages to determine the version bump:

- **Major version bump** (`1.0.0 → 2.0.0`): 
  - Commit messages containing `BREAKING CHANGE` or `major:`
  - Example: `git commit -m "BREAKING CHANGE: update backup format"`

- **Minor version bump** (`1.0.0 → 1.1.0`):
  - Commit messages containing `feat`, `feature`, or `minor:`
  - Example: `git commit -m "feat: add backup encryption support"`

- **Patch version bump** (`1.0.0 → 1.0.1`):
  - All other commits (fixes, docs, etc.)
  - Example: `git commit -m "fix: resolve backup cleanup issue"`

### 2. Manual Version Control

Use the version management script for precise control:

```bash
# Create a patch release (1.0.0 → 1.0.1)
./version.sh patch
make version-patch

# Create a minor release (1.0.0 → 1.1.0)
./version.sh minor
make version-minor

# Create a major release (1.0.0 → 2.0.0)
./version.sh major
make version-major
```

### 3. Manual Workflow Dispatch

Trigger releases from GitHub Actions web interface:

1. Go to **Actions** → **Build and Release Docker Image**
2. Click **Run workflow**
3. Select version type (patch/minor/major)
4. Click **Run workflow**

## Release Process

When a new version is triggered, the automated workflow performs:

### Step 1: Version Calculation
- Analyzes commit history since last tag
- Determines appropriate semantic version bump
- Creates and pushes new Git tag (e.g., `v1.2.3`)

### Step 2: Build Docker Images
- Builds multi-architecture images (linux/amd64, linux/arm64)
- Tags images with:
  - Version-specific tag: `ahmadfaryabkokab/mysql8:1.2.3`
  - Latest stable tag: `ahmadfaryabkokab/mysql8:latest`

### Step 3: Comprehensive Testing
- Starts MySQL container with test configuration
- Tests basic MySQL functionality
- Verifies backup creation and compression
- Tests usage reporting functionality
- Validates auto-recovery mechanism
- Ensures data persistence after recovery

### Step 4: GitHub Release
- Creates GitHub release with version tag
- Generates release notes from commit history
- Attaches relevant files (README, docker-compose files)
- Includes Docker image references and feature list

### Step 5: Docker Hub Deployment
- Pushes versioned images to Docker Hub
- Updates `latest` tag to point to new version
- Provides multi-architecture support

## Development Workflow

### Feature Development

1. **Create feature branch:**
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **Make changes and commit with descriptive messages:**
   ```bash
   git commit -m "feat: add backup retention policies"
   git commit -m "fix: resolve cron scheduling issue"
   ```

3. **Push branch and create PR:**
   ```bash
   git push origin feature/amazing-feature
   ```

4. **Development builds:** Non-main branches automatically build preview images:
   - `ahmadfaryabkokab/mysql8:feature-amazing-feature`

### Release Process

1. **Merge to main:**
   ```bash
   git checkout main
   git merge feature/amazing-feature
   git push origin main
   ```

2. **Automatic release:** The workflow detects the merge and:
   - Analyzes commit messages for version bump type
   - Creates appropriate version tag
   - Builds, tests, and releases automatically

### Manual Release Control

For precise version control, use the manual methods:

```bash
# Option 1: Use version script
./version.sh minor  # Will show preview and ask for confirmation

# Option 2: Use Makefile
make version-minor  # Convenience wrapper

# Option 3: Traditional git tagging
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

## Image Tagging Strategy

| Tag Pattern | Description | Example |
|-------------|-------------|---------|
| `latest` | Latest stable release | `ahmadfaryabkokab/mysql8:latest` |
| `x.y.z` | Specific version | `ahmadfaryabkokab/mysql8:1.2.3` |
| `branch-name` | Development builds | `ahmadfaryabkokab/mysql8:develop` |
| `test` | Test builds | `ahmadfaryabkokab/mysql8:test` |

## Monitoring Releases

### GitHub Actions
Monitor workflow progress at:
```
https://github.com/afaryab/docker-mysql/actions
```

### Docker Hub
View published images at:
```
https://hub.docker.com/r/ahmadfaryabkokab/mysql8
```

### Release Notes
Check GitHub releases for detailed changelogs:
```
https://github.com/afaryab/docker-mysql/releases
```

## Rollback Process

If a release has issues, you can:

1. **Revert to previous version:**
   ```bash
   docker pull ahmadfaryabkokab/mysql8:1.2.2  # Previous version
   ```

2. **Create hotfix release:**
   ```bash
   git checkout -b hotfix/critical-fix
   # Make minimal fix
   git commit -m "fix: critical issue with backup recovery"
   # Merge to main for automatic patch release
   ```

3. **Manual rollback tag:**
   ```bash
   git tag -a v1.2.4 -m "Rollback to stable version"
   git push origin v1.2.4
   ```

## Best Practices

### Commit Messages
- Use conventional commit format for automatic version detection
- Be descriptive about the changes made
- Include breaking change information when applicable

### Testing
- Always run `make test` before pushing to main
- Use `make deploy-test` to test locally before releases
- Monitor GitHub Actions for test results

### Version Planning
- Use semantic versioning principles
- Plan breaking changes for major versions
- Group related features for minor versions
- Use patch versions for bug fixes only

## Troubleshooting

### Workflow Fails
- Check GitHub Actions logs for detailed error messages
- Ensure Docker Hub credentials are properly configured
- Verify all required secrets are set in repository

### Version Conflicts
- If tags conflict, delete and recreate: `git tag -d v1.2.3 && git push --delete origin v1.2.3`
- Use `git fetch --tags` to sync local tags with remote

### Docker Hub Issues
- Verify repository exists and has proper permissions
- Check Docker Hub status page for service issues
- Ensure image names match exactly in all configurations

This automated workflow ensures consistent, reliable releases while providing flexibility for different development needs.

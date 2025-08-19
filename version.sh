#!/bin/bash

# Version management script for docker-mysql project
# Usage: ./version.sh [patch|minor|major]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default version type
VERSION_TYPE=${1:-patch}

# Validate version type
if [[ ! "$VERSION_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo -e "${RED}Error: Invalid version type. Use 'patch', 'minor', or 'major'${NC}"
    exit 1
fi

echo -e "${BLUE}🏷️  Version Management Tool${NC}"
echo -e "${BLUE}=========================${NC}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Check if we're on main branch
current_branch=$(git branch --show-current)
if [ "$current_branch" != "main" ]; then
    echo -e "${YELLOW}Warning: You're on branch '$current_branch', not 'main'${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get the latest tag
latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo -e "${BLUE}Current version: ${NC}$latest_tag"

# Remove 'v' prefix if present
current_version=${latest_tag#v}

# Split version into components
IFS='.' read -ra VERSION_PARTS <<< "$current_version"
major=${VERSION_PARTS[0]:-0}
minor=${VERSION_PARTS[1]:-0}
patch=${VERSION_PARTS[2]:-0}

echo -e "${BLUE}Parsed version: ${NC}$major.$minor.$patch"

# Calculate new version based on type
case $VERSION_TYPE in
    major)
        major=$((major + 1))
        minor=0
        patch=0
        ;;
    minor)
        minor=$((minor + 1))
        patch=0
        ;;
    patch)
        patch=$((patch + 1))
        ;;
esac

new_version="$major.$minor.$patch"
new_tag="v$new_version"

echo -e "${GREEN}New version: ${NC}$new_version"
echo -e "${GREEN}New tag: ${NC}$new_tag"

# Show what will be included in this release
if [ "$latest_tag" != "v0.0.0" ]; then
    echo -e "\n${BLUE}Changes since $latest_tag:${NC}"
    git log ${latest_tag}..HEAD --oneline --no-merges || echo "No changes found"
else
    echo -e "\n${BLUE}This will be the first release${NC}"
fi

echo
read -p "Create and push tag $new_tag? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Create and push the tag
    echo -e "${BLUE}Creating tag...${NC}"
    git tag -a "$new_tag" -m "Release $new_tag"
    
    echo -e "${BLUE}Pushing tag...${NC}"
    git push origin "$new_tag"
    
    echo -e "${GREEN}✅ Tag $new_tag created and pushed successfully!${NC}"
    echo -e "${BLUE}The GitHub Actions workflow will now:${NC}"
    echo -e "  1. Build Docker images with version $new_version"
    echo -e "  2. Run tests"
    echo -e "  3. Create a GitHub release"
    echo -e "  4. Push images to Docker Hub"
    echo
    echo -e "${BLUE}Monitor the progress at:${NC}"
    echo -e "  https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\/[^/.]*\).*/\1/')/actions"
else
    echo -e "${YELLOW}Cancelled.${NC}"
fi

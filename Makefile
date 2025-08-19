# Makefile for MySQL Backup Docker Image

.PHONY: help build test clean deploy-local deploy-test

# Variables
IMAGE_NAME = ahmadfaryabkokab/mysql8
TAG ?= latest
TEST_TAG = test

help: ## Show this help message
	@echo "MySQL Backup Docker Image - Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	@echo "🐳 Building $(IMAGE_NAME):$(TAG)..."
	docker build -t $(IMAGE_NAME):$(TAG) .
	@echo "✅ Build complete!"

build-test: ## Build the test image
	@echo "🐳 Building test image..."
	docker build -t $(IMAGE_NAME):$(TEST_TAG) .
	@echo "✅ Test image built!"

test: build-test ## Run comprehensive tests using docker-compose
	@echo "🧪 Running tests..."
	./test.sh
	@echo "✅ All tests passed!"

test-compose: build-test ## Run tests using docker-compose only
	@echo "🧪 Running docker-compose tests..."
	mkdir -p test-backups
	docker-compose -f docker-compose.test.yml up --build -d
	@echo "⏳ Waiting for MySQL to be ready..."
	@for i in $$(seq 1 20); do \
		if docker-compose -f docker-compose.test.yml exec -T mysql mysqladmin ping -h localhost -u root -ptestpass123 --silent 2>/dev/null; then \
			echo "✅ MySQL is ready!"; \
			break; \
		fi; \
		echo "   Waiting... ($$i/20)"; \
		sleep 2; \
	done
	@echo "🧪 Running basic tests..."
	docker-compose -f docker-compose.test.yml exec -T mysql mysql -uroot -ptestpass123 -e "CREATE DATABASE testdb; USE testdb; CREATE TABLE test (id INT PRIMARY KEY, name VARCHAR(50)); INSERT INTO test VALUES (1, 'test');"
	docker-compose -f docker-compose.test.yml exec -T mysql /usr/local/bin/backup.sh
	@echo "✅ Tests completed!"
	docker-compose -f docker-compose.test.yml down -v

clean: ## Clean up test containers and images
	@echo "🧹 Cleaning up..."
	-docker-compose -f docker-compose.test.yml down -v 2>/dev/null
	-docker-compose down -v 2>/dev/null
	-docker rmi $(IMAGE_NAME):$(TEST_TAG) 2>/dev/null
	-sudo rm -rf test-backups test-data 2>/dev/null
	@echo "✅ Cleanup complete!"

deploy-local: build ## Deploy locally using docker-compose
	@echo "🚀 Deploying locally..."
	@if [ ! -f .env ]; then \
		echo "📝 Creating .env file from example..."; \
		cp docker-compose.example.yml .env; \
		echo "⚠️  Please edit .env file with your settings"; \
	fi
	docker-compose up -d
	@echo "✅ Local deployment started!"
	@echo "📊 Monitor with: docker-compose logs -f"

deploy-test: ## Deploy test environment
	@echo "🚀 Deploying test environment..."
	mkdir -p test-backups
	docker-compose -f docker-compose.test.yml up -d
	@echo "✅ Test environment started!"
	@echo "📊 Monitor with: docker-compose -f docker-compose.test.yml logs -f"

logs: ## Show logs from running containers
	docker-compose logs -f

logs-test: ## Show logs from test containers
	docker-compose -f docker-compose.test.yml logs -f

backup: ## Create manual backup (requires running container)
	@echo "💾 Creating manual backup..."
	docker-compose exec mysql /usr/local/bin/backup.sh
	@echo "✅ Backup created!"

usage-report: ## Generate usage report (requires running container)
	@echo "📊 Generating usage report..."
	docker-compose exec mysql /usr/local/bin/usage_report.sh
	@echo "✅ Usage report generated!"

shell: ## Open shell in running container
	docker-compose exec mysql bash

shell-test: ## Open shell in test container
	docker-compose -f docker-compose.test.yml exec mysql bash

push: build ## Push image to Docker Hub
	@echo "📤 Pushing $(IMAGE_NAME):$(TAG) to Docker Hub..."
	docker push $(IMAGE_NAME):$(TAG)
	@echo "✅ Push complete!"

version-patch: ## Create a patch version release (1.0.0 → 1.0.1)
	@echo "🏷️  Creating patch version release..."
	./version.sh patch

version-minor: ## Create a minor version release (1.0.0 → 1.1.0)
	@echo "🏷️  Creating minor version release..."
	./version.sh minor

version-major: ## Create a major version release (1.0.0 → 2.0.0)
	@echo "🏷️  Creating major version release..."
	./version.sh major

release: ## Create a new release (requires version tag)
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ VERSION is required. Usage: make release VERSION=v1.0.0"; \
		echo "💡 Or use: make version-patch, make version-minor, make version-major"; \
		exit 1; \
	fi
	@echo "🏷️  Creating release $(VERSION)..."
	git tag -a $(VERSION) -m "Release $(VERSION)"
	git push origin $(VERSION)
	@echo "✅ Release $(VERSION) created! GitHub Actions will build and publish."

status: ## Show status of running containers
	@echo "📊 Container Status:"
	docker-compose ps
	@echo ""
	@echo "📊 Test Container Status:"
	docker-compose -f docker-compose.test.yml ps

# Default target
all: build test

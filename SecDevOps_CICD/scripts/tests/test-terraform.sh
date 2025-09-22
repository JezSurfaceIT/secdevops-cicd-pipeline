#!/bin/bash
set -e

echo "Running Terraform Tests for Story 001-01..."

echo "→ Running Python unit tests..."
cd ../..
source venv/bin/activate
pytest tests/unit/test_networking.py -v --tb=short

echo "→ Running Terraform validation..."
cd terraform
terraform init -backend=false
terraform validate

echo "→ Checking Terraform formatting..."
terraform fmt -check -recursive

echo "All tests passed for Story 001-01"
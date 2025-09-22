.PHONY: test test-unit test-integration deploy validate clean

test: test-unit test-integration

test-unit:
	@echo "Running unit tests..."
	@. venv/bin/activate && pytest tests/unit -v --cov=terraform --cov-report=html

test-integration:
	@echo "Running integration tests..."
	@. venv/bin/activate && pytest tests/integration -v

init:
	@echo "Initializing Terraform..."
	@cd terraform && terraform init

plan:
	@echo "Planning Terraform deployment..."
	@cd terraform && terraform plan -var-file=environments/dev.tfvars -out=plan.tfplan

apply:
	@echo "Applying Terraform configuration..."
	@cd terraform && terraform apply plan.tfplan

deploy: init plan apply
	@echo "Deployment complete. Running validation..."
	@./scripts/setup/validate-infrastructure.sh

validate:
	@echo "Validating infrastructure..."
	@./scripts/tests/test-connectivity.sh
	@./scripts/tests/test-acr-access.sh

clean:
	@echo "Cleaning up infrastructure..."
	@cd terraform && terraform destroy -var-file=environments/dev.tfvars -auto-approve
	@rm -rf terraform/.terraform
	@rm -f terraform/plan.tfplan

docs-serve:
	@echo "Serving documentation..."
	@cd docs && python -m http.server 8000

pre-commit:
	@echo "Running pre-commit hooks..."
	@pre-commit run --all-files
ENV ?= dev
TF  := terraform -chdir=terraform/stack
VARS := -var-file=../environments/$(ENV)/terraform.tfvars

.PHONY: bootstrap init plan apply destroy outputs summary test

bootstrap:            ## one-time: create the S3 state bucket (BUCKET=name)
	terraform -chdir=terraform/bootstrap init
	terraform -chdir=terraform/bootstrap apply -var bucket_name=$(BUCKET)

init:                 ## ENV=dev|staging|prod
	$(TF) init -reconfigure -backend-config=../environments/$(ENV)/backend.hcl

plan: init
	$(TF) plan $(VARS)

apply: init           ## creates EKS + Jenkins/JFrog/Xray/Trivy and writes the env summary
	$(TF) apply $(VARS)
	@echo "\nSummary written to terraform/environments/$(ENV)/outputs/summary.md"

destroy: init
	$(TF) destroy $(VARS)

outputs: init         ## print this environment's outputs
	$(TF) output

summary:              ## merge every environment's summary into one file
	@cat terraform/environments/*/outputs/summary.md > terraform/environments/ALL-ENVIRONMENTS.md
	@echo "Wrote terraform/environments/ALL-ENVIRONMENTS.md"

test:                 ## run app unit tests
	cd app && pip install -q -r requirements.txt pytest && python -m pytest -q

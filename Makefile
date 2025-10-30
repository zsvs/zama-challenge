SHELL := /bin/bash

REGION ?= eu-west-1
TAG ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo local)
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 000000000000)

.PHONY: docker-login docker-build docker-push tf-init tf-validate tf-plan tf-apply tf-destroy tf-graph

docker-login:
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com

docker-build:
	docker build -t $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/zama-api:$(TAG) -f services/api/Dockerfile services/api
	docker build -t $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/zama-nginx:$(TAG) -f services/nginx/Dockerfile services/nginx

docker-push: docker-login docker-build
	docker push $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/zama-api:$(TAG)
	docker push $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/zama-nginx:$(TAG)

tf-init:
	cd terraform && terraform init

tf-validate:
	cd terraform && terraform validate

tf-plan:
	cd terraform && terraform plan -out plan.bin && terraform show -no-color plan.bin > ../plan.txt

tf-apply:
	cd terraform && terraform apply -auto-approve plan.bin

tf-destroy:
	cd terraform && terraform destroy -auto-approve

tf-graph:
	cd terraform && terraform graph | dot -Tpng > ../terraform-graph.png

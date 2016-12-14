PROJECT_NAME ?= bedrock
REPO_NAME ?= bedrock-docker

TEMPLATES ?= git@github.com:wilddogdesign/puppy.git

SERVER_NAME ?= docker.local.dev

BEDROCK_PATH := bedrock
BEDROCK_REPO := roots/bedrock

COMPOSE_FILE := docker-compose.yml
DEV_COMPOSE_FILE := docker-compose.development.yml

CERTIFICATE_KEY_FILE := .certs/bedrock.key
CERTIFICATE_CRT_FILE := .certs/bedrock.pem
CERTIFICATE_DHPARAM_FILE := .certs/dhparam.pem

# Default deployment target
TO := staging

# Default deployment method ("flightplan" is the only other possible option)
DEPLOY_WITH := capistrano

# Cosmetics
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Shell functions
INFO := @bash -c '\
	printf $(YELLOW); \
	echo "=> $$1"; \
	printf $(NC)' VALUE

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: build deploy dev launch setup update-templates

setup:
ifeq ($(wildcard $(ROOT_DIR)/$(COMPOSE_FILE)),)
	${INFO} "Creating $(COMPOSE_FILE) ..."
	@ sed "s|PROJECT_NAME|$(PROJECT_NAME)|g" < .docker/$(COMPOSE_FILE) > $(COMPOSE_FILE)
else
	${INFO} "$(COMPOSE_FILE) exists"
endif

ifeq ($(wildcard $(ROOT_DIR)/$(DEV_COMPOSE_FILE)),)
	${INFO} "Creating $(DEV_COMPOSE_FILE) ..."
	@ sed "s|PROJECT_NAME|$(PROJECT_NAME)|g" < .docker/stages/dev/docker-compose/$(DEV_COMPOSE_FILE) > $(DEV_COMPOSE_FILE)
else
	${INFO} "$(DEV_COMPOSE_FILE) exists"
endif

ifeq ($(wildcard $(ROOT_DIR)/docker-sync.yml),)
	${INFO} "Creating docker-sync.yml ..."
	@ sed "s|PROJECT_NAME|$(PROJECT_NAME)|g" < .docker/stages/dev/docker-compose/docker-sync.yml > docker-sync.yml
else
	${INFO} "docker-sync.yml exists"
endif

	${INFO} "Creating development database volume..."
	@ docker volume create --name $(PROJECT_NAME)-db

	${INFO} "Creating development cache volume..."
	@ docker volume create --name $(PROJECT_NAME)-cache

	${INFO} "Resolving certificates..."
ifeq ($(wildcard $(ROOT_DIR)/$(CERTIFICATE_KEY_FILE)),)
	@ openssl req -x509 -newkey rsa:2048 -keyout $(CERTIFICATE_KEY_FILE) -out $(CERTIFICATE_CRT_FILE) -days 30 -nodes -subj '/CN=$(SERVER_NAME)'
else
	${INFO} "Certificates exist"
endif

	${INFO} "Sorting out forward secrecy..."
ifeq ($(wildcard $(ROOT_DIR)/$(CERTIFICATE_DHPARAM_FILE)),)
	@ openssl dhparam -dsaparam -out $(CERTIFICATE_DHPARAM_FILE) 4096
else
	${INFO} "All safe"
endif

ifeq ($(shell git submodule | grep templates),)
	${INFO} "Hooking templates in..."
	@ git submodule add $(TEMPLATES) templates
	@ git submodule update --init --recursive
else
	${INFO} "Templates are already there"
endif

	${INFO} "Creating images..."
	@ docker-compose -f $(COMPOSE_FILE) -f $(DEV_COMPOSE_FILE) build

update-templates:
	${INFO} "Updating templates..."
	@ git submodule update --init --remote --merge

	${INFO} "Getting templates dependencies..."
	@ cd $(ROOT_DIR)/templates && npm run setup

	${INFO} "Building project"
	@ cd $(ROOT_DIR)/templates && npm run build

# build:
# 	${INFO} "Creating images..."
# 	@ docker-compose -f $(COMPOSE_FILE) -f $(DEV_COMPOSE_FILE) build

launch:
	${INFO} "Launching..."
	@ docker-sync-stack start
	# @ docker-compose -f $(COMPOSE_FILE) -f $(DEV_COMPOSE_FILE) up

dev: | update-templates launch

deploy:
	${INFO} "Deploying to: $(TO) using $(DEPLOY_WITH)"
ifeq ($(DEPLOY_WITH),flightplan)
	@ cd $(ROOT_DIR)/deploy && npm install && fly deploy:$(TO)
else
	@ cd $(ROOT_DIR)/deploy && bundle && cap $(TO) deploy
endif

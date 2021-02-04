PROJECT_NAME ?= bedrock
REPO_NAME ?= bedrock-docker

TEMPLATES ?= git@github.com:wilddogdesign/puppy.git

SERVER_NAME ?= docker.test

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
DEPLOY_WITH := flightplan

# Cosmetics
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Shell functions
INFO := @bash -c '\
	printf $(YELLOW); \
	echo "=> $$1"; \
	printf $(NC)' VALUE

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: deploy dev launch setup update-templates link-assets setup-env update-plugins valet-link work

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

	${INFO} "Creating development database volume..."
	@ docker volume create --name $(PROJECT_NAME)-db

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
else
	${INFO} "Templates are already there"
endif
	@ git submodule update --init --recursive

	${INFO} "Creating images..."
	@ docker-compose -f $(COMPOSE_FILE) -f $(DEV_COMPOSE_FILE) build

	${INFO} "Updating git-hooks..."
	@ chmod u+x .hooks/pre-commit.sh
	@ if ! [ -L .git/hooks/pre-commit ]; then ln -s ../../.hooks/pre-commit.sh .git/hooks/pre-commit; fi

update-templates:
	${INFO} "Updating templates..."
	@ git submodule update --init --remote --merge

	${INFO} "Getting templates dependencies..."
	@ cd $(ROOT_DIR)/templates && npm run setup && git checkout package-lock.json

	${INFO} "Building project"
	@ cd $(ROOT_DIR)/templates && npm run build:bedrock

ut: | update-templates

launch:
	${INFO} "Launching..."
	@ docker-compose -f $(COMPOSE_FILE) -f $(DEV_COMPOSE_FILE) up

dev: | update-templates launch

deploy:
	${INFO} "Deploying to: $(TO) using $(DEPLOY_WITH)"
	@ cd $(ROOT_DIR)/deploy && npm install && fly deploy:$(TO)

link-assets:
	${INFO} "Linking assets..."
	@ cd $(ROOT_DIR)/bedrock/web/app/themes/bedrock-theme/static
	@ ln -snf $(ROOT_DIR)/templates/dist/assets/css $(ROOT_DIR)/bedrock/web/app/themes/bedrock-theme/static/css
	@ ln -snf $(ROOT_DIR)/templates/dist/assets/favicons $(ROOT_DIR)/bedrock/web/app/themes/bedrock-theme/static/favicons
	@ ln -snf $(ROOT_DIR)/templates/dist/assets/fonts $(ROOT_DIR)/bedrock/web/app/themes/bedrock-theme/static/fonts
	@ ln -snf $(ROOT_DIR)/templates/dist/assets/icons $(ROOT_DIR)/bedrock/web/app/themes/bedrock-theme/static/icons
	@ ln -snf $(ROOT_DIR)/templates/dist/assets/images $(ROOT_DIR)/bedrock/web/app/themes/bedrock-theme/static/images
	@ ln -snf $(ROOT_DIR)/templates/dist/assets/js $(ROOT_DIR)/bedrock/web/app/themes/bedrock-theme/static/js
	@ ln -snf $(ROOT_DIR)/templates/dist/assets/js $(ROOT_DIR)/bedrock/web/app/themes/bedrock-theme/static/json

la: | link-assets

link-sw:
	@ ln -snf $(ROOT_DIR)/templates/dist/service-worker.js $(ROOT_DIR)/bedrock/web/service-worker.js

update-plugins:
	${INFO} "Updating composer packages and plugins"
	@ cd $(ROOT_DIR)/bedrock && composer up --no-dev --prefer-dist --no-interaction --optimize-autoloader

up: | update-plugins

setup-env:
ifeq ($(wildcard $(ROOT_DIR)/bedrock/.env),)
	${INFO} "Creating ENV file..."
	@ cd $(ROOT_DIR)/bedrock && cp .env.example .env
else
	${INFO} ".env exists"
endif

valet-link:
	${INFO} "Setup Valet link..."
	@ cd $(ROOT_DIR)/bedrock/web && valet link $(REPO_NAME)

work:
	$(MAKE) update-templates
	$(MAKE) link-assets
	$(MAKE) update-plugins
	$(MAKE) setup-env
	$(MAKE) valet-link
	${INFO} "Ready to rock and roll..."
	@ open http://$(REPO_NAME).test

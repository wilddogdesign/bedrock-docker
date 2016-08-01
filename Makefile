PROJECT_NAME ?= bedrock
REPO_NAME ?= bedrock-docker

SERVER_NAME ?= docker.local.dev

BEDROCK_PATH := bedrock
BEDROCK_REPO := roots/bedrock

DEV_COMPOSE_FILE := docker-compose.development.yml

CERTIFICATE_KEY_FILE := .certs/bedrock.key
CERTIFICATE_CRT_FILE := .certs/bedrock.pem
CERTIFICATE_DHPARAM_FILE := .certs/dhparam.pem

# Cosmetics
YELLOW := "\e[1;33m"
NC := "\e[0m"

# Shell functions
INFO := @bash -c '\
	printf $(YELLOW); \
	echo "=> $$1"; \
	printf $(NC)' VALUE

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: setup dev

setup:
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

	${INFO} "Creating images..."
	@ docker-compose -f $(DEV_COMPOSE_FILE) build

dev:
	${INFO} "Launching..."
	@ docker-compose -f $(DEV_COMPOSE_FILE) up

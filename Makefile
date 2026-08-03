SHELL := /usr/bin/env bash

COMPOSE ?= docker compose
COMPOSE_GPU ?= $(COMPOSE) -f docker-compose.yml -f docker-compose.gpu.yml
ENV_FILE ?= .env
MODEL ?=

.PHONY: up up-gpu up-web-search up-gpu-web-search down restart restart-gpu logs logs-web-search ps pull-model run-model models test-ollama test-open-webui test-searxng shell-ollama update-images

up:
	$(COMPOSE) up -d

up-gpu:
	$(COMPOSE_GPU) up -d

up-web-search:
	COMPOSE_PROFILES=web-search ENABLE_WEB_SEARCH=true ENABLE_SEARCH_QUERY_GENERATION=false ENABLE_PERSISTENT_CONFIG=false DEFAULT_MODEL_METADATA='{"capabilities":{"web_search":true},"defaultFeatureIds":["web_search"]}' $(COMPOSE) up -d

up-gpu-web-search:
	COMPOSE_PROFILES=web-search ENABLE_WEB_SEARCH=true ENABLE_SEARCH_QUERY_GENERATION=false ENABLE_PERSISTENT_CONFIG=false DEFAULT_MODEL_METADATA='{"capabilities":{"web_search":true},"defaultFeatureIds":["web_search"]}' $(COMPOSE_GPU) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

restart-gpu:
	$(COMPOSE_GPU) restart

logs:
	$(COMPOSE) logs -f

logs-web-search:
	COMPOSE_PROFILES=web-search $(COMPOSE) logs -f searxng open-webui

ps:
	$(COMPOSE) ps

pull-model:
	MODEL="$(MODEL)" ENV_FILE="$(ENV_FILE)" scripts/pull-model.sh

run-model:
	MODEL="$(MODEL)" ENV_FILE="$(ENV_FILE)" scripts/run-model.sh

models:
	$(COMPOSE) exec ollama ollama list

test-ollama:
	ENV_FILE="$(ENV_FILE)" scripts/test-ollama.sh

test-open-webui:
	ENV_FILE="$(ENV_FILE)" scripts/test-open-webui.sh

test-searxng:
	ENV_FILE="$(ENV_FILE)" scripts/test-searxng.sh

shell-ollama:
	$(COMPOSE) exec ollama sh

update-images:
	$(COMPOSE) pull

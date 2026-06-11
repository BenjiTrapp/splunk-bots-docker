.DEFAULT_GOAL := help

COMPOSE      := docker compose
SERVICES     := bots1 bots2 bots3
BOTS1_PORT   := $(shell grep BOTS1_PORT .env 2>/dev/null | cut -d= -f2)
BOTS2_PORT   := $(shell grep BOTS2_PORT .env 2>/dev/null | cut -d= -f2)
BOTS3_PORT   := $(shell grep BOTS3_PORT .env 2>/dev/null | cut -d= -f2)

.PHONY: help install up down start stop restart reset logs ps pull clean

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Setup"
	@echo "  install      Run the full installer (downloads apps, prompts for password, starts containers)"
	@echo "  install-all  Alias for install"
	@echo "  install-1    Install and start only bots1"
	@echo "  install-2    Install and start only bots2"
	@echo "  install-3    Install and start only bots3"
	@echo ""
	@echo "Lifecycle"
	@echo "  up           Start all containers (background)"
	@echo "  down         Stop and remove all containers"
	@echo "  start        Alias for up"
	@echo "  stop         Alias for down"
	@echo "  restart      Down then up (renews 30-day trial license)"
	@echo "  reset        Alias for restart"
	@echo ""
	@echo "Services (start a single version)"
	@echo "  bots1        Start bots1 only"
	@echo "  bots2        Start bots2 only"
	@echo "  bots3        Start bots3 only"
	@echo ""
	@echo "Monitoring"
	@echo "  ps           Show container status"
	@echo "  logs         Follow logs from all containers"
	@echo "  logs-1       Follow logs from bots1"
	@echo "  logs-2       Follow logs from bots2"
	@echo "  logs-3       Follow logs from bots3"
	@echo ""
	@echo "Maintenance"
	@echo "  pull         Pull the Splunk image"
	@echo "  clean        Down and remove named volumes (full data wipe)"
	@echo "  shell-1      Open a shell in bots1"
	@echo "  shell-2      Open a shell in bots2"
	@echo "  shell-3      Open a shell in bots3"
	@echo "  url          Print access URLs"

# ── Setup ──────────────────────────────────────────────────

install:
	./install.sh

install-all: install

install-1:
	./install.sh bots1

install-2:
	./install.sh bots2

install-3:
	./install.sh bots3

# ── Lifecycle ──────────────────────────────────────────────

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

start: up

stop: down

restart: down up

reset: restart

# ── Services ───────────────────────────────────────────────

bots1:
	$(COMPOSE) up -d bots1

bots2:
	$(COMPOSE) up -d bots2

bots3:
	$(COMPOSE) up -d bots3

# ── Monitoring ─────────────────────────────────────────────

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

logs-1:
	$(COMPOSE) logs -f bots1

logs-2:
	$(COMPOSE) logs -f bots2

logs-3:
	$(COMPOSE) logs -f bots3

# ── Maintenance ────────────────────────────────────────────

pull:
	docker pull splunk/splunk:8.2.3 --platform linux/amd64

clean: down
	$(COMPOSE) down -v

shell-1:
	$(COMPOSE) exec bots1 /bin/bash

shell-2:
	$(COMPOSE) exec bots2 /bin/bash

shell-3:
	$(COMPOSE) exec bots3 /bin/bash

url:
	@echo "BOTSv1: http://localhost:$(BOTS1_PORT)"
	@echo "BOTSv2: http://localhost:$(BOTS2_PORT)"
	@echo "BOTSv3: http://localhost:$(BOTS3_PORT)"
	@echo "Login: admin / password from .env"

---
id: infra_mvp_docker
human_name: MVP Docker Infrastructure
type: BUILD
version: 1.0
status: DRAFT
priority: CORE
tags: [docker, infrastructure, mvp]
parents:
  - [[module_backend]]
dependents: []
---

# MVP Docker Infrastructure

## INTENT
Provide a lightweight, development-friendly Docker orchestration for the Upsilon system MVP.

## THE RULE / LOGIC
- **Base Images**:
  - BattleUI: `php:8.4-apache`
  - WebSocket: `php:8.4-apache` (Twin of BattleUI)
  - Go Engine: `golang:1.25-alpine`
  - Database: `postgres:18-alpine`
- **Service Orchestration**:
  - `app`: Laravel/Vue via Apache. Port `8000:80`.
  - `ws`: Reverb WebSocket server. Port `8080:8080`.
  - `engine`: Go battle engine. Internal communication.
  - `db`: PostgreSQL. Port `5432:5432`.
- **Data Persistence**:
  - Named volume `db_data` for PostgreSQL `/var/lib/postgresql/data`.
  - Dev volume binds for `battleui` and `upsilonbattle` to allow live-reload (if needed in prod-like dev).
- **Environment**:
  - `DB_CONNECTION=pgsql`
  - `SESSION_DRIVER=database`
  - `QUEUE_CONNECTION=database`
  - `CACHE_STORE=database`
  - Hardcoded `DATABASE_URL` in `docker-compose.prod.yaml`.
- **Simplifications**:
  - No Nginx/PHP-FPM split.
  - No Redis.
  - No Opcache or complex multi-stage builds.

## BUILD AND EXECUTION PROCEDURE
- **Build strategy**:
  - **Context**: Must be executed from the **workspace root** to allow `upsilon*` cross-module resolution.
  - **Command**: `docker compose -f docker-compose.prod.yaml build`
- **Execution strategy**:
  - **Lifecycle**: Services must be started via `docker compose -f docker-compose.prod.yaml up -d`.
  - **Order**: `db` must be healthy before `app`, `ws`, and `engine` can function (handled via `depends_on`).
  - **Initialization**: Database migrations must be run manually after the initial startup: `docker compose -f docker-compose.prod.yaml exec app php artisan migrate`.

## TECHNICAL INTERFACE
- **Files**:
  - `battleui/Dockerfile`
  - `upsilonapi/Dockerfile`
  - `docker-compose.prod.yaml` (root)
- **Code Tag**: `@spec-link [[infra_mvp_docker]]`

## EXPECTATION
- `docker compose up` starts all 4 services.
- `app` is reachable at `http://localhost:8000`.
- `ws` is reachable at `http://localhost:8080`.
- Laravel can connect to `db` using the provided environment variables.

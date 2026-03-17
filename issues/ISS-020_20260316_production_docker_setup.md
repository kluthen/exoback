# Issue: Simplified MVP Docker Infrastructure

**ID:** `20260316_mvp_docker_setup`
**Ref:** `ISS-020`
**Date:** 2026-03-16
**Severity:** Medium
**Status:** Resolved
**Component:** `infrastructure`
**Affects:** Development and MVP orchestration

---

## Summary

The goal is to provide a lightweight, development-friendly Docker orchestration for the Upsilon system, tailored for a school MVP. This setup avoids production complexities like Nginx/PHP-FPM splits or Redis, focusing instead on simplicity and live code reloading via volume binds.

---

## Technical Description

### Integrated Architecture
1. **BattleUI (Apache + PHP 8.2)**: A single container using `php:8.2-apache`. This hosts the Laravel/Vue application without a separate Nginx service.
2. **WebSocket Server**: A twin of the BattleUI container, but executing `php artisan reverb:start`. This ensures consistent environments for the app and its real-time layer.
3. **Go Engine (Alpine Build)**: A simple `golang:alpine` container for `upsilonbattle`. No complex multi-stage builds are required for this phase.
4. **Database (PostgreSQL)**: Standard Postgres image with persistent volume data.

### MVP Constraints & Simplifications
- **No Redis**: All caching, sessions, and queues will use the `database` driver.
- **No Reverse Proxy**: Direct port mapping will be used.
    - **App**: `8000:80`
    - **WebSocket**: `8080:8080` (or as configured for Reverb)
    - **Go Engine**: Not called on by the front. 
- **Volume Binds**: Only the database volume is bind mounted.
- **Environment Management**: Hardcoded `DATABASE_URL` in `docker-compose.yaml`.
- **Omitted Production Ops**: No Opcache, no health checks, and no optimized multi-stage build scripts.

---

## Recommended Fix

**Short term:** Prepare a single `Dockerfile` for BattleUI (Apache-based) and a `Dockerfile` for the Go Engine (Alpine-based).
**Medium term:** Create a root `docker-compose.yaml` that orchestrates these 4 services (App, WS, Go, DB) with bind mounts.
**Long term:** Document the MVP deployment flow using these simplified images.

---

## References

- [docker-compose.yaml](file:///home/bastien/work/upsilon/projbackend/docker-compose.yaml)
- [battleui](file:///home/bastien/work/upsilon/projbackend/battleui)
- [upsilonbattle](file:///home/bastien/work/upsilon/projbackend/upsilonbattle)

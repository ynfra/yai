#!/usr/bin/env bash
# yai — manage the AI stack (per-service docker-compose projects).
#
# Usage:
#   yai stack <cmd>              operate on every service
#   yai service <name> <cmd>     operate on one service
#   yai <cmd> [service|all]      short form (same semantics as ydocker/server.sh)
#
# Commands: init | start | stop | restart | logs | ps | status | doctor | orbstack install

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Order matters: shared infrastructure first, then services that consume it.
# vmetrics must start before grafana (datasource); vlogs/vtraces can be parallel.
SERVICES=(postgres minio qdrant browserless firecrawl n8n litellm langfuse vmetrics vlogs vtraces vector node-exporter grafana traefik)

usage() {
    cat <<EOF
Usage:
  $(basename "$0") stack <cmd>              operate on every service
  $(basename "$0") service <name> <cmd>     operate on one service
  $(basename "$0") <cmd> [service|all]      short form

Commands:
  init [service|all]      Create data directories; warn on placeholder secrets
  start [service|all]     docker compose up -d
  stop [service|all]      docker compose down (reverse order for 'all')
  restart [service|all]   docker compose restart
  logs <service>          docker compose logs -f
  ps [service|all]        docker compose ps
  status [service|all]    alias for ps
  doctor                  Validate toolchain, repo layout, and compose files
  orbstack install        Install Claude Code, Docker; add user to docker group (Linux)

Services: ${SERVICES[*]}

Examples:
  $(basename "$0") stack start
  $(basename "$0") service n8n logs
  $(basename "$0") start qdrant
  $(basename "$0") stop all
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

valid_service() {
    local svc="$1"
    for s in "${SERVICES[@]}"; do
        [[ "$s" == "$svc" ]] && return 0
    done
    return 1
}

resolve_services() {
    local target="${1:-all}"
    if [[ "$target" == "all" ]]; then
        echo "${SERVICES[@]}"
    elif valid_service "$target"; then
        echo "$target"
    else
        die "Unknown service: '$target'. Valid: ${SERVICES[*]}, all"
    fi
}

compose() {
    local svc="$1"; shift
    local dir="$SCRIPT_DIR/$svc"
    [[ -d "$dir" ]] || die "Service directory missing: $dir"
    [[ -f "$dir/docker-compose.yml" ]] || die "Compose file missing: $dir/docker-compose.yml"

    local env_args=()
    [[ -f "$dir/.env" ]]       && env_args+=(--env-file "$dir/.env")
    [[ -f "$dir/.env.local" ]] && env_args+=(--env-file "$dir/.env.local")
    ( cd "$dir" && docker compose -f docker-compose.yml "${env_args[@]}" "$@" )
}

ensure_data_dirs() {
    local svc="$1"
    local dir="$SCRIPT_DIR/$svc"
    case "$svc" in
        postgres)    mkdir -p "$dir/data" ;;
        minio)       mkdir -p "$dir/data" ;;
        qdrant)      mkdir -p "$dir/data" ;;
        browserless) ;;  # stateless
        traefik)     ;;  # stateless; config files are tracked in git
        firecrawl)   mkdir -p "$dir/data/redis" "$dir/data/rabbitmq" "$dir/data/postgres" ;;
        n8n)         mkdir -p "$dir/data/postgres" "$dir/data/n8n" "$dir/data/redis" ;;
        litellm)     ;;  # uses shared postgres
        langfuse)    mkdir -p "$dir/data/postgres" "$dir/data/clickhouse/data" \
                              "$dir/data/clickhouse/logs" "$dir/data/minio" "$dir/data/redis" ;;
        windmill)    ;; # disabled
        vmetrics) mkdir -p "$dir/data" ;;
        vlogs)    mkdir -p "$dir/data" ;;
        vtraces)  mkdir -p "$dir/data" ;;
        grafana)  mkdir -p "$dir/data/grafana" ;;
    esac
}

ensure_infra_network() {
    if ! docker network inspect yai-infra >/dev/null 2>&1; then
        docker network create yai-infra >/dev/null
        echo "  [ok] created Docker network yai-infra"
    fi
}

cmd_init() {
    ensure_infra_network
    local services
    read -ra services <<< "$(resolve_services "${1:-all}")"
    for svc in "${services[@]}"; do
        local dir="$SCRIPT_DIR/$svc"
        echo "--- Initializing $svc ---"
        ensure_data_dirs "$svc"
        echo "  [ok] data directories"
        env_status=$(doctor_secrets_status "$svc")
        [[ "$env_status" == none ]] && echo "  [!]  $svc/.env not found — copy from template and configure" || true
    done
}

cmd_start() {
    ensure_infra_network
    local services
    read -ra services <<< "$(resolve_services "${1:-all}")"
    for svc in "${services[@]}"; do
        echo "--- Starting $svc ---"
        ensure_data_dirs "$svc"
        compose "$svc" up -d
    done
}

cmd_stop() {
    local target="${1:-all}"
    local services
    read -ra services <<< "$(resolve_services "$target")"
    # Reverse for clean shutdown when stopping everything
    if [[ "$target" == "all" ]]; then
        local reversed=()
        for (( i=${#services[@]}-1; i>=0; i-- )); do reversed+=("${services[$i]}"); done
        services=("${reversed[@]}")
    fi
    for svc in "${services[@]}"; do
        echo "--- Stopping $svc ---"
        compose "$svc" down
    done
}

cmd_restart() {
    local services
    read -ra services <<< "$(resolve_services "${1:-all}")"
    for svc in "${services[@]}"; do
        echo "--- Restarting $svc ---"
        compose "$svc" restart
    done
}

cmd_logs() {
    local svc="${1:-}"
    [[ -z "$svc" ]] && die "logs requires a service name: ${SERVICES[*]}"
    valid_service "$svc" || die "Unknown service: '$svc'"
    compose "$svc" logs -f
}

cmd_ps() {
    local services
    read -ra services <<< "$(resolve_services "${1:-all}")"
    for svc in "${services[@]}"; do
        echo "--- $svc ---"
        compose "$svc" ps
    done
}

cmd_orbstack_install() {
    local os
    os="$(uname -s)"

    case "$os" in
        Darwin)
            command -v brew >/dev/null 2>&1 || die "Homebrew required — https://brew.sh"

            if [[ ! -d /Applications/OrbStack.app ]]; then
                echo "--- Installing OrbStack (Docker Engine + Compose) ---"
                brew install --cask orbstack
            else
                echo "[ok] OrbStack already installed"
            fi

            open -a OrbStack 2>/dev/null || true

            if ! command -v docker >/dev/null 2>&1; then
                echo "Waiting for OrbStack to link docker CLI..."
                for _ in $(seq 1 30); do
                    command -v docker >/dev/null 2>&1 && break
                    sleep 2
                done
            fi
            command -v docker >/dev/null 2>&1 || die "docker CLI not found — open OrbStack and retry"

            if docker context ls 2>/dev/null | grep -q orbstack; then
                docker context use orbstack >/dev/null 2>&1 || true
            fi

            if ! command -v claude >/dev/null 2>&1; then
                echo "--- Installing Claude Code ---"
                brew install --cask claude-code
            else
                echo "[ok] claude already installed"
            fi

            echo "[ok] macOS + OrbStack: docker group membership is not required"
            ;;
        Linux)
            command -v docker >/dev/null 2>&1 || {
                echo "--- Installing Docker Engine (https://get.docker.com/) ---"
                command -v curl >/dev/null 2>&1 || die "curl required — install curl, then re-run"
                curl -fsSL https://get.docker.com | sudo sh
            }

            if getent group docker >/dev/null 2>&1; then
                if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
                    echo "[ok] $USER is already in the docker group"
                else
                    echo "--- Adding $USER to the docker group ---"
                    sudo usermod -aG docker "$USER"
                    echo "[!]  Log out and back in (or run: newgrp docker) for group membership to apply"
                fi
            else
                die "docker group not found after install"
            fi

            if ! command -v claude >/dev/null 2>&1; then
                echo "--- Installing Claude Code ---"
                curl -fsSL https://claude.ai/install.sh | bash
            else
                echo "[ok] claude already installed"
            fi
            ;;
        *)
            die "orbstack install supports macOS (OrbStack) and Linux only"
            ;;
    esac

    echo "--- Done ---"
    command -v docker >/dev/null 2>&1 && docker --version
    command -v claude >/dev/null 2>&1 && claude --version 2>/dev/null || true
}

doctor_data_dirs() {
    local svc="$1"
    local dir="$SCRIPT_DIR/$svc"
    case "$svc" in
        postgres|minio|qdrant) echo "$dir/data" ;;
        firecrawl)   echo "$dir/data/redis" "$dir/data/rabbitmq" "$dir/data/postgres" ;;
        n8n)         echo "$dir/data/postgres" "$dir/data/n8n" "$dir/data/redis" ;;
        langfuse)    echo "$dir/data/postgres" "$dir/data/clickhouse/data" \
                              "$dir/data/clickhouse/logs" "$dir/data/minio" "$dir/data/redis" ;;
        windmill)    ;; # disabled
        vmetrics) echo "$dir/data" ;;
        vlogs)    echo "$dir/data" ;;
        vtraces)  echo "$dir/data" ;;
        grafana)  echo "$dir/data/grafana" ;;
        browserless|litellm|traefik) ;;
    esac
}

doctor_count() {
    case "$1" in
        warn) warnings=$((warnings + 1)) ;;
        fail) failures=$((failures + 1)) ;;
    esac
}

doctor_label() {
    case "$1" in
        ok)       echo OK ;;
        warn)     echo WARN ;;
        fail)     echo FAIL ;;
        running)  echo UP ;;
        partial)  echo PARTIAL ;;
        stopped)  echo down ;;
        —|skip)   echo n/a ;;
        *)        echo "$1" ;;
    esac
}

doctor_print() {
    local status="$1"
    local label
    label=$(doctor_label "$status")
    if [[ -t 1 ]]; then
        case "$status" in
            ok|running|env|env+loc) printf '\033[32m%-8s\033[0m' "$label" ;;
            warn|partial|local)     printf '\033[33m%-8s\033[0m' "$label" ;;
            fail)                   printf '\033[31m%-8s\033[0m' "$label" ;;
            stopped|none)           printf '\033[90m%-8s\033[0m' "$label" ;;
            *)           printf '%-8s' "$label" ;;
        esac
    else
        printf '%-8s' "$label"
    fi
}

doctor_toolchain() {
    local status="$1" check="$2" detail="$3"
    doctor_count "$status"
    printf "  %-16s " "$check"
    doctor_print "$status"
    echo "$detail"
}

doctor_secrets_status() {
    local svc="$1"
    local has_env=false has_local=false
    [[ -f "$SCRIPT_DIR/$svc/.env" ]]       && has_env=true
    [[ -f "$SCRIPT_DIR/$svc/.env.local" ]] && has_local=true
    if $has_env && $has_local; then echo "env+loc"
    elif $has_env;             then echo "env"
    elif $has_local;           then echo "local"
    else                            echo "none"
    fi
}

doctor_data_status() {
    local svc="$1" path
    local paths
    read -ra paths <<< "$(doctor_data_dirs "$svc")"
    [[ ${#paths[@]} -eq 0 ]] && { echo "—"; return; }
    for path in "${paths[@]}"; do
        [[ ! -d "$path" ]] && { echo warn; return; }
    done
    echo ok
}

doctor_compose_status() {
    local svc="$1" docker_ok="$2"
    local dir="$SCRIPT_DIR/$svc"
    [[ ! -d "$dir" || ! -f "$dir/docker-compose.yml" ]] && { echo fail; return; }
    [[ "$docker_ok" != true ]] && { echo "—"; return; }
    if compose "$svc" config -q >/dev/null 2>&1; then
        echo ok
    else
        echo fail
    fi
}

doctor_running_status() {
    local svc="$1" docker_ok="$2"
    local total running exited_ok
    [[ "$docker_ok" != true ]] && { echo "—"; return; }
    total=$(compose "$svc" ps -a -q 2>/dev/null | wc -l | tr -d ' ')
    running=$(compose "$svc" ps --status running -q 2>/dev/null | wc -l | tr -d ' ')
    # One-shot init containers exit with 0 and should not count as failures
    exited_ok=$(compose "$svc" ps -a 2>/dev/null | awk 'NR>1 && /Exited \(0\)/' | wc -l | tr -d ' ')
    local effective=$(( total - exited_ok ))
    if [[ "$total" -eq 0 ]]; then
        echo stopped
    elif [[ "$running" -eq "$effective" ]]; then
        echo running
    elif [[ "$running" -gt 0 ]]; then
        echo partial
    else
        echo stopped
    fi
}

cmd_doctor() {
    failures=0
    warnings=0
    local docker_ok=false
    local svc running secrets data compose_status

    if [[ -t 1 ]]; then
        printf '\033[1m%s\033[0m\n\n' "yai doctor"
    else
        echo "yai doctor"
        echo ""
    fi

    if [[ -t 1 ]]; then printf '\033[1m%s\033[0m\n' "Toolchain"; else echo "Toolchain"; fi
    if command -v docker >/dev/null 2>&1; then
        doctor_toolchain ok "docker CLI" "$(docker --version 2>/dev/null | head -1)"
    else
        doctor_toolchain fail "docker CLI" "run: $(basename "$0") orbstack install"
    fi

    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        docker_ok=true
        doctor_toolchain ok "docker daemon" "reachable"
    elif command -v docker >/dev/null 2>&1; then
        doctor_toolchain fail "docker daemon" "start Docker/OrbStack or: newgrp docker"
    fi

    if docker compose version >/dev/null 2>&1; then
        doctor_toolchain ok "docker compose" "$(docker compose version 2>/dev/null | head -1)"
    else
        doctor_toolchain fail "docker compose" "Compose v2 required"
    fi

    if [[ "$(uname -s)" == "Linux" ]]; then
        if getent group docker >/dev/null 2>&1 && id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
            doctor_toolchain ok "docker group" "$USER is a member"
        elif [[ "$docker_ok" == true ]]; then
            doctor_toolchain warn "docker group" "$USER not in group (daemon reachable)"
        else
            doctor_toolchain fail "docker group" "run: newgrp docker or log out/in"
        fi
    fi

    if command -v curl >/dev/null 2>&1; then
        doctor_toolchain ok "curl" "$(curl --version 2>/dev/null | head -1 | awk '{print $2}')"
    else
        doctor_toolchain fail "curl" "run: sudo apt-get install -y curl"
    fi

    if command -v jq >/dev/null 2>&1; then
        doctor_toolchain ok "jq" "$(jq --version 2>/dev/null)"
    else
        doctor_toolchain fail "jq" "run: sudo apt-get install -y jq"
    fi

    if command -v claude >/dev/null 2>&1; then
        doctor_toolchain ok "claude CLI" "installed"
    else
        doctor_toolchain warn "claude CLI" "run: $(basename "$0") orbstack install"
    fi

    echo ""
    if [[ -t 1 ]]; then printf '\033[1m%s\033[0m\n' "Services"; else echo "Services"; fi
    printf "  %-16s %-8s %-8s %-8s %s\n" "SERVICE" "STATE" ".ENV" "DATA" "COMPOSE"
    if [[ -t 1 ]]; then printf '\033[90m'; fi
    printf "  %s\n" "────────────────────────────────────────────────────"
    if [[ -t 1 ]]; then printf '\033[0m'; fi

    for svc in "${SERVICES[@]}"; do
        running=$(doctor_running_status "$svc" "$docker_ok")
        secrets=$(doctor_secrets_status "$svc")
        data=$(doctor_data_status "$svc")
        compose_status=$(doctor_compose_status "$svc" "$docker_ok")

        [[ "$secrets" == none ]] && doctor_count warn
        [[ "$data" == warn ]] && doctor_count warn
        [[ "$compose_status" == fail ]] && doctor_count fail

        printf "  %-16s " "$svc"
        doctor_print "$running"
        doctor_print "$secrets"
        doctor_print "$data"
        doctor_print "$compose_status"
        echo
    done

    echo ""
    if [[ $failures -eq 0 && $warnings -eq 0 ]]; then
        if [[ -t 1 ]]; then printf '\033[32m%s\033[0m\n' "All checks passed."; else echo "All checks passed."; fi
    else
        [[ $failures -gt 0 ]] && echo "✗ $failures failure(s)"
        [[ $warnings -gt 0 ]]  && echo "⚠ $warnings warning(s)"
        if [[ $warnings -gt 0 ]]; then
            echo "  → create missing .env files, then: $(basename "$0") init all"
        fi
        if [[ $failures -gt 0 ]]; then
            echo "  → fix toolchain/compose errors above"
        fi
    fi
    [[ $failures -eq 0 ]]
}

dispatch() {
    local cmd="${1:-}"; shift || true
    case "$cmd" in
        init)            cmd_init    "${1:-all}" ;;
        start|up)        cmd_start   "${1:-all}" ;;
        stop|down)       cmd_stop    "${1:-all}" ;;
        restart)         cmd_restart "${1:-all}" ;;
        logs)            cmd_logs    "${1:-}" ;;
        ps|status)       cmd_ps      "${1:-all}" ;;
        help|-h|--help)  usage ;;
        '')              usage ;;
        *)               die "Unknown command: '$cmd'. Run '$(basename "$0") help'." ;;
    esac
}

# --- Top-level parsing -----------------------------------------------------
TOP="${1:-}"

case "$TOP" in
    stack)
        shift
        cmd="${1:-}"
        [[ -z "$cmd" ]] && { usage; exit 1; }
        shift
        # 'stack' implies target=all; reject explicit service arg
        if [[ "$cmd" == "logs" ]]; then
            die "'stack logs' is not supported — use 'service <name> logs' or '$(basename "$0") logs <name>'"
        fi
        dispatch "$cmd" "all"
        ;;
    service)
        shift
        svc="${1:-}"
        cmd="${2:-}"
        [[ -z "$svc" || -z "$cmd" ]] && { echo "Usage: $(basename "$0") service <name> <cmd>" >&2; exit 1; }
        valid_service "$svc" || die "Unknown service: '$svc'. Valid: ${SERVICES[*]}"
        # logs takes the service as its sole arg; others take service-as-target
        if [[ "$cmd" == "logs" ]]; then
            dispatch "$cmd" "$svc"
        else
            dispatch "$cmd" "$svc"
        fi
        ;;
    orbstack)
        shift
        sub="${1:-}"
        case "$sub" in
            install) cmd_orbstack_install ;;
            '')      die "Usage: $(basename "$0") orbstack install" ;;
            *)       die "Unknown orbstack subcommand: '$sub'. Use: orbstack install" ;;
        esac
        ;;
    orbstack:install)
        cmd_orbstack_install
        ;;
    doctor)
        cmd_doctor
        ;;
    help|-h|--help|'')
        usage
        ;;
    *)
        # Short form: yai <cmd> [service|all]
        dispatch "$@"
        ;;
esac

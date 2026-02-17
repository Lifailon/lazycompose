#!/bin/bash

function compose-ls() {
    stacks=$(docker-compose ls --all)
    echo "$stacks" | sed "1d" | fzf \
        --no-sort \
        --ansi \
        --wrap \
        --reverse \
        --exact \
        --border \
        --list-border \
        --height 100% \
        --prompt "🔎 " \
        --pointer "▶ " \
        --color="header:blue:bold,pointer:bright-blue:bold" \
        --header "$(echo "$stacks" | head -n 1)" \
        --preview-window down:70%:wrap:follow \
        --preview "compose-stats {1}" \
        --bind "enter:execute(compose-ps-bind {1} {3})"
}

function compose-stats() {
    export COMPOSE_PROJECT_NAME="$1"
    while true; do
        stats=$(docker-compose stats --all --no-stream)
        header=$(echo "$stats" | head -n 1)
        echo -e "\x1b[34;1m$header\x1b[0m"
        echo "$stats" | sed "1d"
        sleep $TIMEOUT
        clear
    done
}

function compose-ps-bind() {
    export COMPOSE_PROJECT_NAME="$1"
    export COMPOSE_FILE=$(docker-compose ls --all --filter "name=$COMPOSE_PROJECT_NAME" --format json | jq -r ".[].ConfigFiles")
    ps=$(docker-compose ps --all --format "$FORMAT")
    echo "$ps" | sed "1d" | fzf \
        --no-sort \
        --ansi \
        --wrap \
        --reverse \
        --exact \
        --border \
        --list-border \
        --height 100% \
        --prompt "🔎 " \
        --pointer "▶ " \
        --color="header:blue:bold,pointer:bright-blue:bold" \
        --header "$(echo "$ps" | head -n 1)" \
        --preview-window down:70%:wrap:follow \
        --preview "compose-logs {1}" \
        --bind "enter:execute(compose-custom-commands {1})"
}

function compose-logs() {
    export COMPOSE_SERVICE_NAME="$1"
    while true; do
        docker logs "$COMPOSE_SERVICE_NAME" --timestamps --tail 100 2>&1 | tspin
        sleep $TIMEOUT
        clear
    done
}

function compose-custom-commands() {
    export COMPOSE_SERVICE_NAME="$1"
    mapfile -t commands < <(yq e '.customCommands[].name' config.yml)
    commandsName=$(printf "%s\n" "${commands[@]}")
    echo "$commandsName" | fzf \
        --no-sort \
        --ansi \
        --wrap \
        --reverse \
        --exact \
        --border \
        --list-border \
        --height 100% \
        --prompt "🔎 " \
        --pointer "▶ " \
        --preview-window up:30%:wrap:follow \
        --preview "compose-ps-preview" \
        --bind "enter:execute(custom-command-run '{}')"
}

function compose-ps-preview() {
    while true; do
        ps=$(docker-compose ps --all --format "$FORMAT")
        serviceCount=$(($(echo "$ps" | wc -l) - 1))
        upCount=0
        exitCount=0
        lines=()
        while read -r line; do
            sn=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | awk '{print $2}')
            if [[ "$sn" == "$COMPOSE_SERVICE_NAME" ]]; then
                line="\x1b[34;1m▶\x1b[0m  $line"
            else
                line="   $line"
            fi
            case "$status" in
                Up*) ((upCount++)) ;;
                *)   ((exitCount++)) ;;
            esac
            lines+=("$line")
        done < <(echo "$ps" | sed "1d")
        header=$(echo "$ps" | head -n 1)
        if [ "$upCount" -eq "$serviceCount" ]; then
            icon="🟢"
        elif [ "$upCount" -ge 1 ]; then
            icon="🟡"
        else
            icon="🔴"
        fi
        header="$icon Live status\n\n   \x1b[34;1m$header\x1b[0m"
        clear
        echo -e "$header"
        IFS=$'\n'
        echo -e "${lines[*]}"
        sleep $TIMEOUT
    done
}

function custom-command-run() {
    COMMAND_NAME="$*"
    command=$(yq e ".customCommands[] | select(.name == \"$COMMAND_NAME\") | .command" config.yml)
    attach=$(yq e ".customCommands[] | select(.name == \"$COMMAND_NAME\") | .attach" config.yml)
    eval "$command"
    if [ "$attach" == "true" ]; then
        read -r
    fi
}

export COMPOSE_PATH=${COMPOSE_PATH:-/docker}
export TIMEOUT=${TIMEOUT:-2}
export FORMAT="table {{.Service}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}\t{{.Command}}\t{{.Ports}}"
export -f compose-ls
export -f compose-stats
export -f compose-ps-bind
export -f compose-logs
export -f compose-custom-commands
export -f compose-ps-preview
export -f custom-command-run

clear
if [ "$TTYD_MODE" == "true" ]; then
    TTYD_OPTIONS="-W -p ${TTYD_PORT:-3333}"
    if [ -n "${TTYD_USER}" ] && [ -n "${TTYD_PASS}" ]; then
        TTYD_OPTIONS+=" -c ${TTYD_USER}:${TTYD_PASS}"
    fi
    # exec ttyd $TTYD_OPTIONS bash -c compose-ls
    ttyd $TTYD_OPTIONS bash -c compose-ls
else
    # exec bash -c compose-ls
    bash -c compose-ls
fi

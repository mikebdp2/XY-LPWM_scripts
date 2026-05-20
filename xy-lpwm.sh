#!/bin/bash

# --- Configuration ---
BAUD=9600

# --- Line terminator for commands ---
# Set to $'\r\n' for boards that need CR+LF
# Set to $'\r'   for boards that need only CR
# Set to $'\n'   for boards that need only LF
# Set to ''      for boards that need no terminator at all
CRLF=''

# --- Help (handle before anything else) ---
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [SERIAL_PORT] [COMMAND...]"
    echo "  SERIAL_PORT   Path to USB-TTL device (default: /dev/ttyUSB0)"
    echo "                If the first argument does NOT start with /dev/, it is treated as a command."
    echo "  COMMAND       Commands to send. Special commands (case-insensitive):"
    echo "                  terminate    – exit the script immediately"
    echo "                  interactive  – stop processing and enter interactive mode"
    exit 0
fi

# --- Port assignment ---
if [[ -n "$1" && "$1" == /dev/* ]]; then
    PORT="$1"
    shift
else
    PORT="/dev/ttyUSB0"
fi

# Now $@ holds only the optional commands (if any)

echo ">> Checking serial port: $PORT"

# 1. Existence & device type
if [[ ! -e "$PORT" ]]; then
    echo "Error: Device '$PORT' does not exist." >&2
    exit 1
fi
if [[ ! -c "$PORT" ]]; then
    echo "Error: '$PORT' is not a character device." >&2
    exit 1
fi

# 2. Permission check
if [[ ! -r "$PORT" || ! -w "$PORT" ]]; then
    echo "Error: Permission denied for '$PORT'." >&2
    echo "Fix: sudo usermod -aG uucp \$USER && newgrp uucp" >&2
    exit 1
fi

# 3. Configure port (8N1, raw, no echo, 1s inter-byte timeout)
echo ">> Configuring $PORT @ $BAUD baud (8N1)..."
if ! stty -F "$PORT" "$BAUD" cs8 -parenb -cstopb raw -echo min 0 time 10 2>/dev/null; then
    echo "Error: Failed to configure '$PORT'. Is it locked or in use?" >&2
    exit 1
fi

# 4. Open read/write file descriptor
if ! exec 3<>"$PORT"; then
    echo "Error: Failed to open '$PORT' for read/write." >&2
    exit 1
fi

# --- Cleanup ---
cleanup() {
    exec 3>&- 2>/dev/null
    printf '\n>> Port closed.\n'
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- Helper: send a command and print the response ---
send_cmd() {
    local cmd="$1"
    local lower_cmd="${cmd,,}"

    if [[ "$lower_cmd" == "terminate" ]]; then
        echo "Terminating script..."
        exit 0
    fi

    # Send command with the configured line terminator
    printf "%s%s" "$cmd" "$CRLF" >&3
    sleep 0.05

    local resp=""
    while IFS= read -r -t 1 -u 3 line; do
        line="${line%$'\r'}"
        resp+="$line"$'\n'
    done
    resp="${resp%$'\n'}"

    if [[ -n "$resp" ]]; then
        echo "<< $resp"
    else
        echo "<< (timeout / no response)"
    fi
}

echo ">> Successfully connected to $PORT @ $BAUD."

# --- Decide execution mode ---
if [[ $# -eq 0 ]]; then
    # No extra arguments: go straight to interactive mode
    echo ">> Type commands, press Enter. Ctrl+C to exit."
    while IFS= read -r -p "> " cmd; do
        [[ -z "$cmd" ]] && continue
        send_cmd "$cmd"
    done
else
    # Process command-line commands
    interactive=false
    for cmd in "$@"; do
        lower_cmd="${cmd,,}"
        if [[ "$lower_cmd" == "interactive" ]]; then
            echo "Switching to the interactive mode..."
            interactive=true
            break
        fi
        echo "> $cmd"
        send_cmd "$cmd"
    done

    if $interactive; then
        echo ">> Type commands, press Enter. Ctrl+C to exit."
        while IFS= read -r -p "> " cmd; do
            [[ -z "$cmd" ]] && continue
            send_cmd "$cmd"
        done
    fi
fi

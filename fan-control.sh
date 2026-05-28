#!/bin/bash

# --- Default port ---
DEFAULT_PORT="/dev/ttyUSB0"

# --- Usage function ---
usage() {
    echo "Usage: $0 [PORT] VALUE"
    echo "  PORT   Serial device (must start with /dev/). Optional, default: $DEFAULT_PORT"
    echo "  VALUE  Fan speed 0–100 (will be sent as Dxxx with 3-digit padding)"
    exit 1
}

# --- Parse arguments ---
if [[ $# -eq 0 ]]; then
    usage
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Determine if first argument is a port or the value
if [[ "$1" == /dev/* ]]; then
    PORT="$1"
    shift
    if [[ $# -eq 0 ]]; then
        echo "Error: Missing duty cycle value after port." >&2
        usage
    fi
    VALUE="$1"
else
    PORT="$DEFAULT_PORT"
    VALUE="$1"
fi

# --- Pre-flight port checks (identical to xy-lpwm.sh) ---
if [[ ! -e "$PORT" ]]; then
    echo "Error: Device '$PORT' does not exist." >&2
    exit 1
fi
if [[ ! -c "$PORT" ]]; then
    echo "Error: '$PORT' is not a character device." >&2
    exit 1
fi
if [[ ! -r "$PORT" || ! -w "$PORT" ]]; then
    echo "Error: Permission denied for '$PORT'." >&2
    echo "Fix: sudo usermod -aG uucp \$USER && newgrp uucp" >&2
    echo "Or - simply run this script with sudo rights." >&2
    exit 1
fi

# --- Check that the main script exists and is executable ---
MAIN_SCRIPT="./xy-lpwm.sh"
if [[ ! -x "$MAIN_SCRIPT" ]]; then
    echo "Error: '$MAIN_SCRIPT' not found or not executable." >&2
    echo "Make sure xy-lpwm.sh is in the same directory and has execute permissions." >&2
    exit 1
fi

# --- Validate the value ---
if ! [[ "$VALUE" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid value '$VALUE' – must be an integer." >&2
    exit 1
fi
if (( VALUE < 0 || VALUE > 100 )); then
    echo "Error: Invalid value '$VALUE' – must be between 0 and 100." >&2
    exit 1
fi

# --- Build the duty cycle string with 3-digit zero padding ---
DUTY=$(printf "D%03d" "$VALUE")

# --- Call the main serial script ---
"$MAIN_SCRIPT" "$PORT" "F25.0" "$DUTY"

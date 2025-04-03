#!/bin/bash

INTERVAL=10
STAT_FILE="/proc/net/netstat"
PREV_FILE="/tmp/netstat_prev"
MAX_UINT32=4294967295

safe_calculation() {
    local prev=$1
    local curr=$2
    local diff=$((curr - prev))

    if [[ $diff -lt 0 ]]; then
        diff=$(( (MAX_UINT32 - prev) + curr ))
    fi
    echo $diff
}

parse_netstat() {
    awk 'BEGIN { section = "" }
    /^IpExt:/ {
        section = substr($1, 1, length($1)-1)
        split($0, headers)
        getline
        for (i=2; i<=NF; i++) {
            value = $i ~ /^[0-9]+$/ ? $i : 0
            printf "%s:%s %s\n", section, headers[i], value
        }
    }' "$STAT_FILE"
}

# Инициализация
if [ ! -f "$PREV_FILE" ]; then
    parse_netstat > "$PREV_FILE"
    echo "Initializing first run. Next updates will show changes."
    exit 0
fi

while true; do
    declare -A CURRENT
    while IFS=":" read -r ne key value; do
        value=$(echo $key|awk '{print $2}')
        key=$(echo $key|awk '{print $1}')
        CURRENT["$key"]=${value}
        #echo "NEW: "$key" " $value " "$CURRENT["$key"] " key:" $key " value="$value
    done < <(parse_netstat)

    declare -A PREV
    while IFS=":" read -r ne key value; do
        value=$(echo $key|awk '{print $2}')
        key=$(echo $key|awk '{print $1}')
        PREV["$key"]=$value
        #echo "OLD: " $key" " $value" " $PREV["$key"] " key:" $key" value="$value
    done < "$PREV_FILE"

    echo -e "\n===== $(date '+%Y-%m-%d %H:%M:%S') ====="
    for key in "${!CURRENT[@]}"; do
        curr=${CURRENT[$key]-1}
        prev=${PREV[$key]:-1}
        #echo $curr " " $prev "        "$CURRENT[$key] " "$PREV[$key]       
        # Явное преобразование в числа
        curr=$((curr + 0))
        prev=$((prev + 0))
        
        diff=$(safe_calculation $prev $curr)
        
        if [ $diff -gt 0 ]; then
            printf "%-35s %+12d\n" "${key}:" "$diff"
        fi
    done 

    parse_netstat > "$PREV_FILE"
    sleep "$INTERVAL"
done

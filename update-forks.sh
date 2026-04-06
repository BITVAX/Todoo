#!/bin/bash
#
# update-forks.sh — Check and update all BITVAX fork submodules
#
# Usage:
#   ./update-forks.sh          # check + pull --rebase
#   ./update-forks.sh --check  # only check, no pull
#

set -euo pipefail

ODOO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ODOO_DIR"

FORKS=$(awk '/^\[submodule/{gsub(/[\[\]"]/, "", $2); name=$2} /url.*BITVAX/{print name}' .gitmodules)

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

ok=0
warn=0
fail=0

printf "%-25s %-12s %-8s %-10s %s\n" "SUBMODULE" "BRANCH" "DIRTY" "vs REMOTE" "STATUS"
printf "%-25s %-12s %-8s %-10s %s\n" "-------------------------" "------------" "--------" "----------" "----------"

for sub in $FORKS; do
    if [ ! -d "$sub/.git" ] && [ ! -f "$sub/.git" ]; then
        printf "%-25s %-12s %-8s %-10s %s\n" "$sub" "-" "-" "-" "NOT CLONED"
        fail=$((fail + 1))
        continue
    fi

    branch=$(git -C "$sub" symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")
    dirty=$(git -C "$sub" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    git -C "$sub" fetch --quiet 2>/dev/null || true

    if [ "$branch" != "DETACHED" ]; then
        behind=$(git -C "$sub" rev-list --count HEAD..origin/"$branch" 2>/dev/null || echo "?")
        ahead=$(git -C "$sub" rev-list --count origin/"$branch"..HEAD 2>/dev/null || echo "?")
    else
        behind="?"
        ahead="?"
    fi

    if [ "$branch" == "DETACHED" ]; then
        status="DETACHED"
        fail=$((fail + 1))
    elif [ "$behind" -gt 0 ] 2>/dev/null; then
        status="${behind} BEHIND"
        warn=$((warn + 1))
    elif [ "$dirty" -gt 0 ]; then
        status="DIRTY"
        warn=$((warn + 1))
    else
        status="OK"
        ok=$((ok + 1))
    fi

    remote_info=""
    [ "$behind" != "0" ] && [ "$behind" != "?" ] && remote_info+="d${behind}"
    [ "$ahead" != "0" ] && [ "$ahead" != "?" ] && remote_info+=" u${ahead}"
    [ -z "$remote_info" ] && remote_info="="

    printf "%-25s %-12s %-8s %-10s %s\n" "$sub" "$branch" "$dirty" "$remote_info" "$status"

    if ! $CHECK_ONLY && [ "$branch" != "DETACHED" ] && [ "$behind" -gt 0 ] 2>/dev/null; then
        if git -C "$sub" pull --ff-only --quiet 2>/dev/null; then
            echo "  -> Updated"
        else
            echo "  -> Pull failed! Resolve manually"
        fi
    fi
done

echo ""
echo "Total: ${ok} ok, ${warn} warnings, ${fail} errors"
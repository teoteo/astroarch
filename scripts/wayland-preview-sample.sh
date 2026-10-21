#!/bin/bash
# Wayland preview: measure CPU per process group, RAM and network traffic over a time window
# Usage: bash scripts/wayland-preview-sample.sh "<label>" [seconds]
# CPU is % of one core (a Pi 5 has four, so the whole machine is 400%)

LABEL=${1:-sample}
DURATION=${2:-60}
IFACE=$(ip route show default | awk '{print $5; exit}')
PROCESS_GROUPS='compositor:^(Xorg|kwin_x11|kwin_wayland|Xwayland)$ remote:^(x0vncserver|xrdp|xrdp-sesman|krdpserver|w0vncserver|krfb|websockify|novnc)$ media:^(pipewire|wireplumber|pipewire-pulse|xdg-desktop-por)$ shell:^(plasmashell|kded6|ksmserver)$ astro:^(kstars|phd2|phd2.bin|indiserver|indi_.*)$'

_snap() {
    for p in /proc/[0-9]*; do
        read -r line < "$p/stat" 2>/dev/null || continue
        comm=${line#*(}; comm=${comm%%)*}; rest=${line##*) }
        set -- $rest
        echo "${p#/proc/} $comm $(( ${12} + ${13} ))"
    done
}
_total() { awk '/^cpu /{s=0; for(i=2;i<=NF;i++) s+=$i; print s, $5+$6}' /proc/stat; }
_net() { awk -v i="$IFACE:" '$1==i{print $2+$10}' /proc/net/dev; }

A=$(_snap); TA=$(_total); NA=$(_net)
sleep "$DURATION"
B=$(_snap); TB=$(_total); NB=$(_net)

{ echo "$A" | sed 's/^/A /'; echo "$B" | sed 's/^/B /'; } | awk -v hz="$(getconf CLK_TCK)" -v dur="$DURATION" \
    -v groups="$PROCESS_GROUPS" -v label="$LABEL" -v ta="$TA" -v tb="$TB" -v na="$NA" -v nb="$NB" \
    -v cores="$(nproc)" -v mem="$(free -m | awk '/Mem:/{print $3}')" '
    $1=="A" { a[$2]=$4; next }
    { comm[$2]=$3; d[$2]=$4-($2 in a ? a[$2] : $4) }
    END {
        ng=split(groups, G, " ")
        for (pid in d) for (k=1; k<=ng; k++) { split(G[k], kv, ":"); if (comm[pid] ~ kv[2]) { g[kv[1]]+=d[pid]; break } }
        split(ta, x, " "); split(tb, y, " ")
        printf "%-28s total=%5.1f%%", label, ((y[1]-x[1])-(y[2]-x[2]))/(y[1]-x[1])*cores*100
        for (k=1; k<=ng; k++) { split(G[k], kv, ":"); printf "  %s=%5.1f%%", kv[1], g[kv[1]]/hz/dur*100 }
        printf "  ram=%dMB  net=%.0fKB/s\n", mem, (nb-na)/1024/dur
    }'

#!/bin/bash
# Nightly housekeeping so heavy development never leaves the Pi bloated.
# Installed as /usr/local/sbin/mainframe-maintenance (run by mainframe-maintenance.timer).
# Only touches things that are safe to lose: unused images, build caches, orphaned dev
# processes; dockerd is restarted only with live-restore on (containers keep running).
set -uo pipefail
log() { echo "maintenance: $*"; }
mib() { ps -o rss= -C "$1" 2>/dev/null | awk '{s+=$1} END {print int(s/1024)}'; }

KEEP_PER_REPO=3        # newest unused images kept per repository (rollback targets)
MIN_AGE_DAYS=7         # unused images younger than this are never removed
DOCKERD_MAX_MIB=900    # restart dockerd above this RSS (live-restore keeps containers up)
ORPHAN_MAX_HOURS=6     # dev processes older than this are orphans from finished sessions
USER_NAME=christopherklint

# 1. Docker images: dangling layers, then per repository keep the newest KEEP_PER_REPO
#    images no container uses; delete older unused ones past MIN_AGE_DAYS.
docker image prune -f >/dev/null
used=$(docker ps -a --format '{{.Image}}' | xargs -r docker image inspect --format '{{.Id}}' 2>/dev/null | sort -u)
cutoff=$(date -d "-${MIN_AGE_DAYS} days" +%s)
removed=0
while read -r repo; do
	docker images "$repo" --format '{{.ID}} {{.Repository}}:{{.Tag}} {{.CreatedAt}}' |
		sort -k3,4r | while read -r id ref created_date created_time _; do
			full=$(docker image inspect --format '{{.Id}}' "$ref" 2>/dev/null) || continue
			grep -qx "$full" <<<"$used" && continue
			n=$((${n:-0} + 1))
			[ "$n" -le "$KEEP_PER_REPO" ] && continue
			[ "$(date -d "$created_date $created_time" +%s)" -lt "$cutoff" ] || continue
			docker rmi "$ref" >/dev/null 2>&1 && echo x
		done
done < <(docker images --format '{{.Repository}}' | grep -v '^<none>$' | sort -u) | wc -l | { read -r removed; log "removed $removed old images"; }
docker image prune -f >/dev/null

# 2. Build caches older than 3 days on every builder; stop idle buildkit containers.
docker builder prune -af --filter until=72h >/dev/null 2>&1
for b in $(docker buildx ls --format '{{.Name}}' 2>/dev/null | grep -v '^default$'); do
	docker buildx prune -af --filter until=72h --builder "$b" >/dev/null 2>&1
	docker buildx stop "$b" >/dev/null 2>&1
done
log "build caches pruned, builders stopped"

# 3. Orphaned dev processes (type checkers, test runners, headless browsers, dev servers)
#    left behind by finished agent sessions. Never services: those run in containers.
max=$((ORPHAN_MAX_HOURS * 3600))
ps -u "$USER_NAME" -o pid=,etimes=,args= | while read -r pid age args; do
	[ "$age" -gt "$max" ] || continue
	case "$args" in
	*/tsc\ * | *tsserver* | *vitest* | *playwright* | *chrome-headless* | *headless_shell* | *"vite dev"* | *"bun test"* | *"bun run dev"*)
		kill "$pid" 2>/dev/null && log "killed orphan $pid (${args:0:60})" ;;
	esac
done

# 4. dockerd only returns memory on restart. With live-restore the containers keep running.
rss=$(mib dockerd)
if [ "${rss:-0}" -gt "$DOCKERD_MAX_MIB" ]; then
	if [ "$(docker info --format '{{.LiveRestoreEnabled}}')" = "true" ]; then
		log "dockerd at ${rss} MiB, restarting (live-restore on)"
		systemctl restart docker
		sleep 10
		log "dockerd now $(mib dockerd) MiB, $(docker ps -q | wc -l) containers running"
	else
		log "dockerd at ${rss} MiB but live-restore is off; not restarting"
	fi
fi

# 5. Journal capped at 500 MB.
journalctl --vacuum-size=500M -q

log "done: $(free -m | awk '/Mem:/ {print $7}') MiB available, swap used $(free -m | awk '/Swap:/ {print $3}') MiB, hapi $(mib hapi) MiB"

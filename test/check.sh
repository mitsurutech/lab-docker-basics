#!/usr/bin/env bash
# Starts the lab the way the platform runs it and checks it does what the README says: the
# worker stops with the sentence a student reads, a line written from a shell in web fixes it,
# docker restart brings it up healthy, and only the named volume survives the lab stopping.
#   test/check.sh
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
project="lab-docker-basics-check"
override="$root/test/hardened.generated.yaml"

# Every service gets the hardening, and memory-swap equal to its memory limit; root ones also
# get the capabilities the runner gives root back.
json=$(docker compose -f "$root/compose.yaml" config --format json)
{
  cat "$root/test/hardened.yaml"
  echo "services:"
  for s in $(docker compose -f "$root/compose.yaml" config --services); do
    read -r mem user < <(echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin)['services']['$s']; print(((d.get('deploy') or {}).get('resources') or {}).get('limits',{}).get('memory') or 536870912, d.get('user') or 'root')")
    merge='*hardened'; if [ "$user" = root ]; then merge='[*hardened, *root-caps]'; fi
    printf '  %s:\n    <<: %s\n    hostname: %s\n    memswap_limit: %s\n' "$s" "$merge" "$s" "$mem"
  done
} > "$override"

compose() { docker compose -p "$project" -f "$root/compose.yaml" -f "$override" "$@"; }
cleanup() { docker compose -p "$project" down -v --remove-orphans >/dev/null 2>&1 || true; rm -f "$override"; }
trap cleanup EXIT
docker compose -p "$project" down -v --remove-orphans >/dev/null 2>&1 || true

# local.yaml, the file the README tells you to run on your own machine, is valid beside it.
docker compose -f "$root/compose.yaml" -f "$root/local.yaml" config --quiet

docker build -q -t lab-docker-basics-probe -f "$root/test/Dockerfile.probe" "$root/test" >/dev/null

# The worker is broken on purpose and stops, so there is nothing to wait for with --wait: web
# and cache are waited for by name, and worker is expected to be the one that has exited.
compose up -d || true
cid() { compose ps -a -q "$1"; }
state() { docker inspect -f "$2" "$(cid "$1")"; }
waitfor() {  # waitfor <service> <go template> <wanted> <what>
  for _ in $(seq 1 90); do
    [ "$(state "$1" "$2" 2>/dev/null)" = "$3" ] && return 0
    sleep 2
  done
  echo "$1 never reached $4" >&2; compose logs "$1" >&2 || true; exit 1
}
healthy='{{.State.Health.Status}}'
waitfor web "$healthy" healthy "healthy"
waitfor cache "$healthy" healthy "healthy"

# The hardening really took: a check that ran without it proves nothing.
for c in $(compose ps -a -q); do
  docker inspect "$c" --format '{{.Name}} {{.HostConfig.CapDrop}} {{.HostConfig.SecurityOpt}} {{.HostConfig.PidsLimit}} {{.HostConfig.Memory}}={{.HostConfig.MemorySwap}}' \
    | tee /dev/stderr | grep -q '\[ALL\] \[no-new-privileges\] 256 \([0-9]*\)=\1$' || { echo "not hardened" >&2; exit 1; }
done

# The runner gives a service with a named user no capabilities and root only its own few.
[ "$(state cache '{{.HostConfig.CapAdd}}')" = "[]" ] || { echo "cache has capabilities" >&2; exit 1; }
[ "$(state worker '{{.HostConfig.CapAdd}}')" = "[]" ] || { echo "worker has capabilities" >&2; exit 1; }

NET="${project}_lab" PROJECT="$project" ROOT="$root" OVERRIDE="$override" bash "$root/test/lab.sh"
echo "ok"

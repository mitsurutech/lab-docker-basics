#!/usr/bin/env bash
# What the README promises, checked the way a student does it: run by check.sh. Each docker
# command here is one a lab's terminal allows (ps, logs, exec, restart) and nothing else.
set -euo pipefail
: "${NET:?run through test/check.sh}"
compose() { docker compose -p "$PROJECT" -f "$ROOT/compose.yaml" -f "$OVERRIDE" "$@"; }
cid() { compose ps -a -q "$1"; }
state() { docker inspect -f "$2" "$(cid "$1")"; }
d() { docker "$1" "$(cid "$2")" "${@:3}"; }
probe() { docker run --rm --network "$NET" lab-docker-basics-probe bash -c "$1"; }
waitfor() {
  for _ in $(seq 1 60); do
    [ "$(state "$1" "$2" 2>/dev/null)" = "$3" ] && return 0
    sleep 2
  done
  echo "$1 never reached $3" >&2; docker logs "$(cid "$1")" >&2 || true; exit 1
}

echo "- docker ps -a: the worker has stopped, and web and cache are up and healthy"
[ "$(state worker '{{.State.Status}} {{.State.ExitCode}}')" = "exited 1" ] \
  || { echo "the worker should have exited with 1" >&2; exit 1; }
[ "$(state web '{{.State.Status}}')" = running ]
[ "$(state cache '{{.State.Status}}')" = running ]

echo "- docker logs worker says exactly what is wrong"
d logs worker 2>&1 | grep -q "has no QUEUE_HOST line" || { echo "the log does not say why" >&2; exit 1; }

echo "- the page is served by web, and the settings are listed beside it"
probe 'set -eu; curl -fs http://web/ | grep -q "Docker basics"; curl -fs http://web/settings/ | grep -q worker.conf; curl -fs http://web/settings/worker.conf | grep -q "^POLL_SECONDS=5"'

echo "- docker exec into cache reaches the queue the worker will use"
[ "$(d exec cache valkey-cli ping)" = PONG ]

echo "- a wrong name stops the worker again, with a different sentence"
d exec web sh -c "echo QUEUE_HOST=nosuch >> /settings/worker.conf"
d restart worker -t 1 >/dev/null
waitfor worker '{{.State.Status}}' exited exited
d logs worker 2>&1 | tail -n 1 | grep -q "cannot reach a queue called nosuch" \
  || { echo "the wrong name was not reported" >&2; d logs worker >&2; exit 1; }

echo "- the right line, then docker restart, and the worker is healthy"
d exec web sh -c "sed -i 's/^QUEUE_HOST=.*/QUEUE_HOST=cache/' /settings/worker.conf"
d restart worker -t 1 >/dev/null
waitfor worker '{{.State.Health.Status}}' healthy healthy
d logs worker 2>&1 | grep -q "taking jobs from the queue on cache"
sleep 6
d logs worker 2>&1 | grep -qE "finished job [0-9]+"
done_count=$(d exec cache valkey-cli get jobs_done)
[ "$done_count" -ge 2 ] || { echo "the queue counted $done_count jobs" >&2; exit 1; }

echo "- docker restart of a running worker does not wait out docker's ten seconds"
start=$(date +%s)
d restart worker >/dev/null
[ $(( $(date +%s) - start )) -le 6 ] || { echo "restarting the worker took too long" >&2; exit 1; }
waitfor worker '{{.State.Health.Status}}' healthy healthy

echo "- the worker cannot change the settings it reads (they are mounted read-only)"
if d exec worker sh -c "echo x >> /settings/worker.conf" 2>/dev/null; then
  echo "the worker could write to the settings" >&2; exit 1
fi

echo "- docker restart keeps a container's own files, and the volume"
d exec web sh -c "echo from-the-container > /usr/share/nginx/html/mine.txt; echo from-the-volume > /settings/mine.txt"
d restart web -t 1 >/dev/null
waitfor web '{{.State.Health.Status}}' healthy healthy
probe 'set -eu; curl -fs http://web/mine.txt | grep -q from-the-container; curl -fs http://web/settings/mine.txt | grep -q from-the-volume'

echo "- stopping the lab (containers removed, volumes kept) keeps only the volume"
compose down >/dev/null
compose up -d >/dev/null
waitfor web '{{.State.Health.Status}}' healthy healthy
waitfor worker '{{.State.Health.Status}}' healthy healthy
probe 'set -u; curl -fs http://web/settings/mine.txt | grep -q from-the-volume || exit 1; [ "$(curl -s -o /dev/null -w "%{http_code}" http://web/mine.txt)" = 404 ] || exit 1; curl -fs http://web/settings/worker.conf | grep -q "^QUEUE_HOST=cache"'

echo "- nothing here reaches the internet"
probe 'if curl -s -m 4 -o /dev/null https://example.com; then exit 1; fi'
echo "  ok"

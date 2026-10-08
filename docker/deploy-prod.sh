#!/bin/sh
# Baut die fertige Website aus dem aktuellen Stand des Projektordners neu
# und startet den prod-Container neu (Port PROD_PORT aus docker/.env).
#
#   docker/deploy-prod.sh          aktuellen Stand im Ordner bauen
#   docker/deploy-prod.sh --pull   vorher git pull ausführen
set -e
cd "$(dirname "$0")"

PROD_PORT=$(grep "^PROD_PORT=" .env 2>/dev/null | cut -d= -f2- | tr -d "'\"")
PROD_PORT=${PROD_PORT:-8080}

if [ "$1" = "--pull" ]; then
    git -C .. pull --ff-only
fi

echo "Baue Stand: $(git -C .. log -1 --format='%h %s')"
if [ -n "$(git -C .. status --porcelain)" ]; then
    echo "Hinweis: Es gibt nicht committete Änderungen, sie werden mitgebaut."
fi

docker compose build --pull prod
docker compose up -d --no-deps prod
docker image prune -f >/dev/null

echo "Warte auf /api/health ..."
for _ in $(seq 1 30); do
    if curl -fsS http://localhost:$PROD_PORT/api/health >/dev/null 2>&1; then
        curl -sS http://localhost:$PROD_PORT/api/health; echo
        echo "Fertig: http://localhost:$PROD_PORT"
        exit 0
    fi
    sleep 2
done

echo "prod antwortet nicht. Logs: docker compose logs prod" >&2
exit 1

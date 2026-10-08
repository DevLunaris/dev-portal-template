# Docker-Umgebung

Compose-Projekt in diesem Ordner. Der Projektordner ist per Bind-Mount
eingebunden, Änderungen sind sofort live. Alle Einstellungen und Passwörter
stehen in `docker/.env` (Vorlage `.env.example`, angelegt von `../bootstrap.sh`).

| Dienst        | Aufgabe                                          | Erreichbar über             |
|---------------|--------------------------------------------------|-----------------------------|
| `portal`      | nginx, Dev-Portal mit allen Werkzeugen           | `PORTAL_PORT` (Standard 8000) |
| `app`         | PHP 8.3 + Apache, CodeIgniter (development)      | Portal `/api/`              |
| `vite`        | Node 22, Vite-Dev-Server mit Hot Reload          | Portal `/preview/`          |
| `code-server` | VS Code im Browser                               | Portal `/code/`             |
| `phpmyadmin`  | phpMyAdmin                                       | Portal `/pma/`              |
| `mailpit`     | fängt alle Mails ab (SMTP `mailpit:1025`)        | Portal `/mail/`             |
| `db`          | MySQL 8.4                                        | nur intern                  |
| `prod`        | fertige Website (Image aus `../Dockerfile`)      | `PROD_PORT` (Standard 8080) |

## Starten und Stoppen

```
cd docker
docker compose up -d --build     # alles starten (auch nach Änderungen an Images)
docker compose ps                # Status
docker compose logs -f vite      # Logs eines Dienstes
docker compose restart app       # einen Dienst neu starten
docker compose stop              # alles anhalten
docker compose down              # Container entfernen (Daten bleiben in den Volumes)
```

Alle Container haben `restart: unless-stopped` und starten mit der VM.

Befehle im app-Container (läuft mit der UID des VM-Benutzers):

```
docker compose exec app php spark migrate
docker compose exec app composer require irgendein/paket
```

Einfacher ist das Terminal in VS Code (`/code/`). Dort sind git, PHP,
Composer, Node und npm installiert.

## Dev-Portal

Leiste oben: Tabs, Routen-Auswahl bzw. Freitext für die Vorschau, Breite
(Handy 375 px, Tablet 768 px, Desktop), Neu laden, In neuem Tab öffnen und
Link zur fertigen Website. Mit ▲ rechts lässt sich die Leiste einklappen,
mit ▼ wieder ausklappen. Im Tab „Code + Vorschau“ lässt sich die Trennlinie
ziehen (Doppelklick: Mitte). Tab, Route, Breite, Trennlinie und Leiste merkt
sich der Browser.

code-server startet ohne Willkommensseite, mit geschlossener
Chat-Seitenleiste und ohne Restricted Mode. Die Standardeinstellungen stehen
in `code-server/settings.json` und werden beim Start nur ergänzt, wenn sie in
den eigenen Einstellungen fehlen.

## Fertige Website deployen

```
docker/deploy-prod.sh          # aktuellen Stand bauen und starten
docker/deploy-prod.sh --pull   # vorher git pull
```

Baut das Produktiv-Image neu (Vue-Build + CodeIgniter mit
`CI_ENVIRONMENT=production`), startet den Container neu und prüft
`/api/health`. Prod nutzt dieselbe Datenbank und dasselbe Mailpit wie die
Entwicklung.

## Passwörter und Einstellungen (`docker/.env`)

| Variable               | Wofür                                              |
|------------------------|----------------------------------------------------|
| `CODE_SERVER_PASSWORD` | Login bei VS Code (`/code/`)                       |
| `DB_USERNAME`, `DB_PASSWORD` | Datenbankbenutzer der App, auch für phpMyAdmin |
| `DB_ROOT_PASSWORD`     | MySQL-root, z. B. für phpMyAdmin                   |
| `PMA_CONTROL_PASSWORD` | interner Benutzer `pma` für den phpMyAdmin-Konfigurationsspeicher |
| `DEV_DOMAIN`, `PROD_DOMAIN` | Adressen hinter dem Reverse Proxy             |
| `PORTAL_PORT`, `PROD_PORT` | Ports in der VM                                |
| `HMR_CLIENT_PORT`      | optional, Port für den HMR-Websocket               |
| `DEV_UID`, `DEV_GID`, `GIT_CONFIG_DIR` | Benutzer in der VM und seine git-Daten |
| `COMPOSE_PROJECT_NAME` | Präfix für Container, Images und Volumes           |
| `TZ`                   | Zeitzone                                           |

Die Datenbank-Passwörter gelten nur beim ersten Start von MySQL (leeres
Volume). Später ändern: zuerst in MySQL (`ALTER USER ...`), dann in `.env`
nachziehen und `docker compose up -d` ausführen.

phpMyAdmin-Konfigurationsspeicher (Datenbank `phpmyadmin`, Benutzer `pma`):
`./setup-pma.sh` richtet ihn ein. `bootstrap.sh` erledigt das automatisch;
nach einem neuen, leeren DB-Volume einfach erneut ausführen.

## Daten

| Volume                  | Inhalt                                       |
|-------------------------|----------------------------------------------|
| `<projekt>_db-data`     | MySQL-Daten                                  |
| `<projekt>_mailpit-data`| abgefangene Mails                            |
| `<projekt>_code-server-home` | Einstellungen und Erweiterungen von VS Code |

Datenbank sichern:

```
docker compose exec db sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' > ~/db-backup.sql
```

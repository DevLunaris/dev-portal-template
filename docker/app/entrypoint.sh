#!/bin/sh
set -e

# Abhängigkeiten installieren bzw. auf den Stand von composer.lock bringen
composer install --no-interaction --no-progress

exec docker-php-entrypoint "$@"

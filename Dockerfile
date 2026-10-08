# Produktiv-Image: ein Container liefert die gebaute Vue-App und die
# CodeIgniter-API (/api) unter einer Domain aus.
#
# Bauen und starten: docker/deploy-prod.sh

# --- Stufe 1: Frontend mit Vite bauen ---------------------------------------
FROM node:22-slim AS frontend
WORKDIR /build
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

# --- Basis: PHP 8.3 + Apache ------------------------------------------------
FROM php:8.3-apache AS base
RUN apt-get update \
    && apt-get install -y --no-install-recommends libicu-dev \
    && docker-php-ext-install intl mysqli \
    && rm -rf /var/lib/apt/lists/* \
    && a2enmod rewrite headers expires \
    && cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# --- Composer-Abhängigkeiten ohne Dev-Pakete --------------------------------
FROM base AS vendor
RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --no-progress --no-scripts --no-autoloader --prefer-dist
COPY app/ app/
RUN composer dump-autoload --no-dev --optimize

# --- Stufe 2: fertiges Image --------------------------------------------------
FROM base
COPY docker/prod/apache.conf /etc/apache2/sites-available/000-default.conf
COPY docker/prod/php.ini "$PHP_INI_DIR/conf.d/zz-app.ini"

WORKDIR /var/www/html
COPY --from=vendor /var/www/html/vendor/ vendor/
COPY composer.json spark ./
COPY app/ app/
COPY public/ public/
COPY writable/ writable/
# Gebaute Vue-App neben index.php in den Webroot legen
COPY --from=frontend /build/dist/ public/

RUN chown -R www-data:www-data writable

ENV CI_ENVIRONMENT=production
EXPOSE 80

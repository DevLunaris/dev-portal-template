# Entwicklungs-Image für CodeIgniter: PHP 8.3 + Apache
# Der Projektordner wird per Bind-Mount nach /var/www/html eingebunden.
FROM php:8.3-apache

# UID/GID des Benutzers in der VM, dem die Projektdateien gehören
ARG UID=1000
ARG GID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends libicu-dev git unzip \
    && docker-php-ext-install intl mysqli \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Apache läuft mit derselben UID/GID wie der Benutzer in der VM und
# code-server, damit writable/, vendor/ und Logdateien niemandem im Weg stehen.
# Ohne root-Rechte darf Apache nicht auf Port 80 lauschen, daher Port 8080.
RUN groupmod -o -g "$GID" www-data \
    && usermod -o -u "$UID" -g "$GID" www-data \
    && sed -i 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && a2enmod rewrite \
    && cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

COPY apache.conf /etc/apache2/sites-available/000-default.conf
COPY php.ini "$PHP_INI_DIR/conf.d/zz-app.ini"
COPY entrypoint.sh /usr/local/bin/app-entrypoint

ENV COMPOSER_HOME=/tmp/composer
USER www-data
WORKDIR /var/www/html
EXPOSE 8080

ENTRYPOINT ["app-entrypoint"]
CMD ["apache2-foreground"]

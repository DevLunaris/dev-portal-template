# VS Code im Browser mit den Werkzeugen des Projekts im Terminal:
# git, PHP 8.3 (CLI, gleiche Version wie der app-Container), Composer, Node 22
FROM php:8.3-cli

# UID/GID des Benutzers in der VM, dem die Projektdateien gehören
ARG UID=1000
ARG GID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git curl ca-certificates unzip less nano procps openssh-client \
        mariadb-client libicu-dev \
    && docker-php-ext-install intl mysqli \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Node 22 aus dem offiziellen Image übernehmen
COPY --from=node:22-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=node:22-slim /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

RUN curl -fsSL https://code-server.dev/install.sh | sh \
    && rm -rf /root/.cache

# Benutzer "dev" mit der UID/GID aus der VM. Die Ordner unter /home/dev werden
# vorab angelegt, damit das Home-Volume sie mit den richtigen Rechten übernimmt.
RUN groupadd -o -g "$GID" dev \
    && useradd -o -m -u "$UID" -g "$GID" -s /bin/bash dev \
    && mkdir -p /home/dev/.config/git /home/dev/.local/share /home/dev/project \
    && chown -R dev:dev /home/dev

COPY settings.json merge-settings.js /usr/local/share/code-server-defaults/
COPY entrypoint.sh /usr/local/bin/code-server-entrypoint

USER dev
WORKDIR /home/dev/project
ENV SHELL=/bin/bash
EXPOSE 8080

ENTRYPOINT ["code-server-entrypoint"]

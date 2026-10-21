FROM php:7.4-fpm-bullseye
LABEL authors="Sylvain Marty <sylvain@guidap.co>"

# PHP2Shell (CVE-2026-109618, CVE-2026-109619): PHP 7.4 is EOL and gets no release.
# Rebuild the image's own 7.4.33 sources with the PHP security team's backport
# (php-src branch PHP-7.4-CVE-2026-109618-109619, commit 712e60f9ed), same configure options.
# bullseye-security is gone from the mirrors since the LTS ended: drop it before any apt-get.
COPY php2shell-7.4.patch /usr/src/
RUN sed -i '/bullseye-security/d' /etc/apt/sources.list \
    && savedAptMark="$(apt-mark showmanual)" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        $PHPIZE_DEPS \
        libargon2-dev \
        libcurl4-openssl-dev \
        libonig-dev \
        libreadline-dev \
        libsodium-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        zlib1g-dev \
    && docker-php-source extract \
    && cd /usr/src/php \
    && patch -p1 < /usr/src/php2shell-7.4.patch \
    && CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS" \
        ./configure $(php-config --configure-options) \
    && make -j "$(nproc)" \
    && find -type f -name '*.a' -delete \
    && make install \
    && find /usr/local -type f -perm '/0111' -exec sh -euc 'strip --strip-all "$@" || :' -- '{}' + \
    && cd / \
    && docker-php-source delete \
    && rm /usr/src/php2shell-7.4.patch \
    && apt-mark auto '.*' > /dev/null \
    && apt-mark manual $savedAptMark > /dev/null \
    && find /usr/local -type f -executable -exec ldd '{}' ';' \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
        | sort -u | xargs -r dpkg-query --search | cut -d: -f1 | sort -u | xargs -r apt-mark manual \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/* \
    && php -v

ARG ENV_LOG_STREAM=/var/
ENV TERM=xterm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libmagickwand-dev \
        libmagickcore-dev \
        libcurl4-gnutls-dev \
        zlib1g-dev \
        libicu-dev \
        supervisor \
        git \
        curl \
        ssh \
        rsync \
        make \
        awscli \
        libzip-dev \
        libonig-dev \
        pngquant \
        jpegoptim \
        gnupg \
        dirmngr \
        wget \
        && pecl install imagick \
        && docker-php-ext-enable imagick

## Nginx (mainline pinned, from nginx.org — fixes CVE-2026-42945)
ARG NGINX_VERSION=1.31.0-1~bullseye
RUN install -d /usr/share/keyrings \
    && curl -fsSL https://nginx.org/keys/nginx_signing.key \
        | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/mainline/debian bullseye nginx" \
        > /etc/apt/sources.list.d/nginx.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y nginx=${NGINX_VERSION}

RUN pecl install \
        imagick \
        xdebug-3.1.5 \
        unzip \
    && docker-php-ext-install \
        pdo_mysql \
        intl \
        bcmath \
        mbstring \
        zip \
        sockets \
        gd \
    && docker-php-ext-enable \
        opcache \
        imagick \
        xdebug \
        gd

COPY docker/php.ini /usr/local/etc/php/

# Node 14 (installed from official binary; NodeSource Node 14 is EOL)
RUN ARCH=$(uname -m | grep -q 'aarch64' && echo 'arm64' || echo 'x64') \
    && NODE_VERSION=v14.21.3 \
    && curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${ARCH}.tar.xz" -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner \
    && rm /tmp/node.tar.xz

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn \
    && npm install -g gulp \
    && npm rebuild node-sass

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=1.10.16 \
    && rm -rf /tmp/* /var/tmp/*

# Installing wkhtmltopdf
RUN apt-get install -y --no-install-recommends libfontenc1 xfonts-75dpi xfonts-base xfonts-encodings xfonts-utils \
    && curl -sL "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bullseye_$(uname -m | grep -q 'aarch64' && echo 'arm64' || echo 'amd64').deb" --output /tmp/wkhtmltox.deb --silent \
    && dpkg -i /tmp/wkhtmltox.deb \
    && rm /tmp/wkhtmltox.deb

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

# Changing local time and fixing permissions
RUN unlink /etc/localtime \
    && ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && chmod -R g+rwx /var/www/html \
    && umask 0007

EXPOSE 80 443

ADD docker/start.sh /start.sh
RUN chmod +x /start.sh

CMD /start.sh

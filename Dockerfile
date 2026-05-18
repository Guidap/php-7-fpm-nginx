FROM php:7.4-fpm
LABEL authors="Sylvain Marty <sylvain@guidap.co>"

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

## Nginx
RUN echo "deb http://nginx.org/packages/mainline/debian/ bullseye nginx" >> /etc/apt/sources.list \
    && wget -qO - http://nginx.org/keys/nginx_signing.key | apt-key add - \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
        nginx

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

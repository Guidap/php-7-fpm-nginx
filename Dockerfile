FROM php:7.2-fpm
LABEL authors="Sylvain Marty <sylvain@guidap.co>"

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
        libzip4 \
        pngquant \
        jpegoptim \
        gnupg \
        dirmngr \
        wget \
        && pecl install imagick \
        && docker-php-ext-enable imagick

## Nginx
RUN echo "deb http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list \
    && wget -qO - http://nginx.org/keys/nginx_signing.key | apt-key add - \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
        nginx

RUN pecl install \
        imagick \
        xdebug \
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
COPY docker/00-supervisor.conf /etc/supervisor/conf.d/

# Node
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash \
    && apt-get install -y nodejs

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
    && curl -sL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.stretch_amd64.deb --output /tmp/wkhtmltox.deb --silent \
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
    && umask 0007 \
    && mkfifo /var/stdout \
    && chmod 777 /var/stdout

RUN composer global require hirak/prestissimo

RUN composer global require hirak/prestissimo

EXPOSE 80 443

ADD docker/start.sh /start.sh
RUN chmod +x /start.sh

CMD /start.sh

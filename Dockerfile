FROM php:7.0-fpm
LABEL authors="Kevin Monmousseau <kevin@guidap.co>,Sylvain Marty <sylvain@guidap.co>"

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
        libzip2 \
        && pecl install imagick \
        && docker-php-ext-enable imagick

## Nginx
RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
	&& echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" >> /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
        ca-certificates \
        nginx \
        nginx-module-xslt \
        nginx-module-geoip \
        nginx-module-image-filter \
        nginx-module-perl \
        nginx-module-njs \
        gettext-base

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
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash \
    && apt-get install -y nodejs

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn \
    && npm install -g gulp \
    && npm rebuild node-sass

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && rm -rf /tmp/* /var/tmp/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	&& echo Europe/Paris > /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && chmod -R g+rwx /var/www/html \
    && umask 0007

RUN composer global require hirak/prestissimo

EXPOSE 80 443

ADD docker/start.sh /start.sh
RUN chmod +x /start.sh

CMD /start.sh

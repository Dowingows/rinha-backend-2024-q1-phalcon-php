# ARG PHP_VERSION

FROM php:8.3-fpm

ENV PHP_VERSION=8.3

# desabilita os logs de acesso do PHP-FPM
# RUN echo "access.log = /dev/null" >> /usr/local/etc/php-fpm.d/www.conf

RUN apt-get update
RUN apt-get install -y libzip-dev

# Install Postgre PDO
RUN apt-get install -y libpq-dev \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install pdo pdo_pgsql pgsql

RUN apt install -y zip unzip
# Easy installation of PHP extensions in official PHP Docker images
# @see https://github.com/mlocati/docker-php-extension-installer
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions

# Install PHP extensions
#RUN install-php-extensions xdebug pdo_mysql zip

# Add logs error for php-fpm
RUN echo "error_log = /var/log/php/error.log" >> /usr/local/etc/php/php.ini \
  && echo "log_errors = On" >> /usr/local/etc/php/php.ini

RUN mkdir -p /var/log/php \
  && touch /var/log/php/error.log \
  && chown www-data:www-data /var/log/php


# Install psr
# RUN cd /tmp \
#     && curl -LO https://github.com/jbboehr/php-psr/archive/v${PSR_VERSION}.tar.gz \
#     && tar xzf /tmp/v${PSR_VERSION}.tar.gz \
#     && docker-php-ext-install -j $(getconf _NPROCESSORS_ONLN) /tmp/php-psr-${PSR_VERSION} \
#     && rm -r /tmp/v${PSR_VERSION}.tar.gz /tmp/php-psr-${PSR_VERSION}

# Install phalcon
ENV PHALCON_VERSION=5.6.0

RUN cd /tmp \
    && curl -LO https://github.com/phalcon/cphalcon/archive/refs/tags/v${PHALCON_VERSION}.tar.gz \
    && tar xzf /tmp/v${PHALCON_VERSION}.tar.gz \
    && cd /tmp/cphalcon-${PHALCON_VERSION}/build \
    && ./install \
    && docker-php-ext-enable phalcon \
    && rm -r /tmp/v${PHALCON_VERSION}.tar.gz /tmp/cphalcon-${PHALCON_VERSION}

# Import fpm config file
COPY docker/php/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf

# Import composer and run dump
COPY --from=composer:2.5 /usr/bin/composer /usr/local/bin/composer
# COPY composer.lock composer.json /var/www/html/

# Import setup script
COPY docker/php/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY . /var/www/html

WORKDIR /var/www/html

# Start services
# ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# CMD ["php-fpm","-F"]

EXPOSE 9000
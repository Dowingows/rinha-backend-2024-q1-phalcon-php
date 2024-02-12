# ARG PHP_VERSION

FROM php:8.3-fpm

ENV PHP_VERSION=8.3

# Import fpm config file
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

# desabilita os logs de acesso do PHP-FPM
RUN echo "access.log = /dev/null" >> /usr/local/etc/php-fpm.d/www.conf

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


# Install phalcon
ENV PHALCON_VERSION=5.6.0

RUN cd /tmp \
    && curl -LO https://github.com/phalcon/cphalcon/archive/refs/tags/v${PHALCON_VERSION}.tar.gz \
    && tar xzf /tmp/v${PHALCON_VERSION}.tar.gz \
    && cd /tmp/cphalcon-${PHALCON_VERSION}/build \
    && ./install \
    && docker-php-ext-enable phalcon \
    && rm -r /tmp/v${PHALCON_VERSION}.tar.gz /tmp/cphalcon-${PHALCON_VERSION}



COPY . /var/www/html

WORKDIR /var/www/html

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN sed -i '/^\[opcache\]/a opcache.enable=1\nopcache.revalidate_freq=0\nopcache.validate_timestamps=1\nopcache.max_accelerated_files=20000\nopcache.memory_consumption=384\nopcache.max_wasted_percentage=10\nopcache.interned_strings_buffer=16\nopcache.fast_shutdown=1\nopcache.jit_buffer_size=200M\nopcache.jit=1235\nopcache.jit_debug=0' "$PHP_INI_DIR/php.ini"

# Start services
# ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# CMD ["php-fpm","-F"]

EXPOSE 9000
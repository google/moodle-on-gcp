## suggested image version from Bitnami. Use the one that better fits to your needs
FROM bitnami/moodle:4.0.1-debian-11-r11

## change user to perform privileged actions
USER 0

## install 'pt-br locale' or any other you may want to
RUN echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen 

## install 'vim'
RUN install_packages vim

## install 'phpredis'
RUN set -ex \
  && mkdir /tmp/localcachedir \
  && apt update && apt -y install autoconf build-essential \
  && rm -rvf /var/lib/apt/lists*... \
  && pecl channel-update pecl.php.net \
  && pecl install -o igbinary \
  && pecl install -o -D 'enable-redis-igbinary="yes" enable-redis-lzf="no" enable-redis-zstd="no"' redis \
  && echo "extension=redis.so" >> /opt/bitnami/php/lib/php.ini \
  && echo "extension=igbinary.so" >> /opt/bitnami/php/lib/php.ini \
  && rm -rvf /tmp/pear

## Revert to the original non-root user
USER 1001
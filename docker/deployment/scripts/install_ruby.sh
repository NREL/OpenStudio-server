#!/usr/bin/env bash

# This script assumes you are running as a superuser.

RUBY_VERSION=$1
RUBY_DOWNLOAD_SHA256=$2

# Predefined versions
RUBYGEMS_VERSION=2.6.6
BUNDLER_VERSION=1.16.1

if [ ! -z ${RUBY_VERSION} ] && [ ! -z ${RUBY_DOWNLOAD_SHA256} ]; then
    RUBY_MAJOR=${RUBY_VERSION%.*} # strips the last dot.value off the version
    echo "Installing Ruby ${RUBY_MAJOR}, ${RUBY_VERSION}, ${RUBY_DOWNLOAD_SHA256}"

    # Build and Install Ruby
    #   -- skip installing gem documentation
    mkdir -p /usr/local/etc \
        && echo 'install: --no-document' | tee --append /usr/local/etc/gemrc > /dev/null \
        && echo 'update: --no-document' | tee --append /usr/local/etc/gemrc > /dev/null

    # install the dependencies for ruby
    apt-get update && apt-get install -y --no-install-recommends \
        autoconf \
        build-essential \
        ca-certificates \
        curl \
        libcurl4-openssl-dev \
        libreadline-dev \
        libxml2-dev \
        libyaml-dev \
        zlib1g-dev \
        && rm -rf /var/lib/apt/lists/*

    curl -fSL --retry 3 -o ruby.tar.gz "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
        && echo "${RUBY_DOWNLOAD_SHA256} *ruby.tar.gz" | sha256sum -c - \
        && mkdir -p /tmp/ruby_src/ruby \
        && tar -xzf ruby.tar.gz -C /tmp/ruby_src/ruby --strip-components=1 \
        && rm ruby.tar.gz \
        && cd /tmp/ruby_src/ruby \
        && { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c \
        && autoconf \
        && ./configure --disable-install-doc --enable-shared \
        && make -j"$(nproc)" \
        && make install \
        && apt-get purge -y --auto-remove \
        && gem update --system $RUBYGEMS_VERSION \
        && rm -rf /tmp/ruby_src \
        && cd $HOME \
        && gem install bundler --version "${BUNDLER_VERSION}" \
        && export BUNDLE_SILENCE_ROOT_WARNING=1
else
    echo "Must pass in the Ruby version to be installed and the SHA (e.g. install_ruby.sh 2.2.4 <SHA>)"
    exit 9
fi
# AUTHOR:           Nicholas Long
# DESCRIPTION:      OpenStudio Server Docker Container
# TO_BUILD_AND_RUN: docker-compose up
# NOTES:            Currently this is one big dockerfile and non-optimal.

#may include suffix
ARG OPENSTUDIO_VERSION=3.7.0
FROM nrel/openstudio:3.7.0 as base
MAINTAINER Nicholas Long nicholas.long@nrel.gov

ENV DEBIAN_FRONTEND=noninteractive
# Install required libaries.
#   realpath - needed for wait-for-it
RUN apt-get update && apt-get install -y wget gnupg \
    && wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add - \
    && echo "deb http://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-6.0.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        autoconf \
        bison \
        shared-mime-info \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        default-jdk \
        dos2unix \
        imagemagick \
        gdebi-core \
        git \
        libbz2-dev \
        libcurl4-openssl-dev \
        libdbus-glib-1-2 \
        libgdbm-dev \
        libglib2.0-dev \
        libglu1 \
        libgsl0-dev \
        libncurses-dev \
        libreadline-dev \
        libxml2-dev \
        libxslt-dev \
        libffi-dev \
        libssl-dev \
        libyaml-dev \
        libice-dev \
        libsm-dev \
        mongodb-database-tools \
        nodejs \
        procps \
        python-numpy \
        python3-numpy \
        tar \
        unzip \
        wget \
        zip \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install passenger (this also installs nginx)
ENV PASSENGER_VERSION 6.0.18

RUN gem install passenger -v $PASSENGER_VERSION
RUN passenger-install-nginx-module

# Configure the nginx server
RUN mkdir /var/log/nginx
ADD /docker/server/nginx.conf /opt/nginx/conf/nginx.conf

# Radiance env vars. RUBYLIB is set in the base openstudio container
ENV OPENSTUDIO_SERVER 'true'
ENV OS_RAYPATH /usr/local/openstudio-$OPENSTUDIO_VERSION/Radiance
ENV PERL_EXE_PATH /usr/bin

# Specify a couple arguments here, after running the majority of the installation above
ARG rails_env=docker
ARG bundle_args="--without development test"
ENV OS_BUNDLER_VERSION=2.1.4

# Set the rails env var
ENV RAILS_ENV $rails_env

# extension gem testing
#ENV FAVOR_LOCAL_GEMS 1

#### OpenStudio Server Code
# First upload the Gemfile* so that it can cache the Gems -- do this first because it is slow
ADD /bin /opt/openstudio/bin
ADD /server/Gemfile /opt/openstudio/server/Gemfile
WORKDIR /opt/openstudio/server
RUN bundle _${OS_BUNDLER_VERSION}_ install --jobs=3 --retry=3 $bundle_args

# Add the app assets and precompile assets. Do it this way so that when the app changes the assets don't
# have to be recompiled everytime
ADD /server/Rakefile /opt/openstudio/server/Rakefile
ADD /server/config/ /opt/openstudio/server/config/
ADD /server/app/assets/ /opt/openstudio/server/app/assets/

# Now call precompile
RUN mkdir /opt/openstudio/server/log
RUN bundle exec rake assets:precompile

# Bundle app source
ADD /server /opt/openstudio/server
# Add in /spec for testing 
#ADD /server/spec /opt/openstudio/server/spec
ADD .rubocop.yml /opt/openstudio/.rubocop.yml
# Run bundle again, because if the user has a local Gemfile.lock it will have been overriden
RUN rm Gemfile.lock
RUN bundle install --jobs=3 --retry=3

# Add in scripts for running server. This includes the wait-for-it scripts to ensure other processes (mongo, redis) have
# started before starting the main process.
COPY /docker/server/wait-for-it.sh /usr/local/bin/wait-for-it
COPY /docker/server/start-server.sh /usr/local/bin/start-server

COPY /docker/server/rails-entrypoint.sh /usr/local/bin/rails-entrypoint
COPY /docker/server/start-web-background.sh /usr/local/bin/start-web-background
COPY /docker/server/start-workers.sh /usr/local/bin/start-workers
RUN chmod 755 /usr/local/bin/wait-for-it
RUN chmod +x /usr/local/bin/start-server
RUN chmod 755 /usr/local/bin/rails-entrypoint
RUN chmod 755 /usr/local/bin/start-web-background
RUN chmod 755 /usr/local/bin/start-workers

# set the permissions for windows users
RUN chmod +x /opt/openstudio/server/bin/*
ENV OPENSTUDIO_EXE_PATH /usr/local/bin/openstudio

ENTRYPOINT ["rails-entrypoint"]

CMD ["/usr/local/bin/start-server"]

# Expose ports.
EXPOSE 8080 9090

# Multistage build includes test library. To build without testing run
# docker build --target base -t some-tag .
FROM base
ENV GECKODRIVER_VERSION v0.21.0
# Install vfb and firefox requirement if docker-test env
RUN echo "Running in testing environment - Installing Firefox and Gecko Driver" && \
    apt-get update && \
    apt-get install -y xvfb \
        x11-xkb-utils \
        xfonts-100dpi \
        xfonts-75dpi \
        xfonts-scalable \
        xfonts-cyrillic \
        firefox && \
    rm -rf /var/lib/apt/lists/* && \
    cd /usr/local/bin && \
    wget http://github.com/mozilla/geckodriver/releases/download/$GECKODRIVER_VERSION/geckodriver-$GECKODRIVER_VERSION-linux64.tar.gz && \
    tar -xvzf geckodriver-$GECKODRIVER_VERSION-linux64.tar.gz && \
    rm geckodriver-$GECKODRIVER_VERSION-linux64.tar.gz && \
    chmod +x geckodriver;

COPY /docker/server/run-server-tests.sh /usr/local/bin/run-server-tests
RUN chmod +x /usr/local/bin/run-server-tests
# Test adding the git repo to the container for coveralls
# The #TEST# will be removed in the test script to be run in the test container
#TEST#COPY .git /opt/openstudio/.git

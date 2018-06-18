# AUTHOR:           Nicholas Long
# DESCRIPTION:      OpenStudio Server Docker Container
# TO_BUILD_AND_RUN: docker-compose up
# NOTES:            Currently this is one big dockerfile and non-optimal.

FROM nrel/openstudio:2.5.2
MAINTAINER Nicholas Long nicholas.long@nrel.gov
ARG rails_env=docker-dev

# Install required libaries
RUN sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
    echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.0 multiverse" | \
    sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list && \
    apt-get update \
	&& apt-get install -y --no-install-recommends \
        apt-transport-https \
        autoconf \
        bison \
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
        libgdbm3 \
        libgdbm-dev \
        libglib2.0-dev \
        libglu1 \
        libgsl0ldbl \
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
        mongodb-org-tools \
        procps \
        tar \
        unzip \
        wget \
        zip \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install passenger (this also installs nginx)
ENV PASSENGER_VERSION 5.0.25
# Install Rack. Silly workaround for not having ruby 2.2.2. Rack 1.6.4 is the
# latest for Ruby <= 2.0
RUN gem install rack -v=1.6.4
RUN gem install passenger -v $PASSENGER_VERSION
RUN passenger-install-nginx-module

# Configure the nginx server
RUN mkdir /var/log/nginx
ADD /docker/server/nginx.conf /opt/nginx/conf/nginx.conf

# Radiance env vars. RUBYLIB is set in the base openstudio container
ENV OPENSTUDIO_SERVER 'true'
ENV OS_RAYPATH /usr/Radiance
ENV PERL_EXE_PATH /usr/bin

# Set the rails env var
ENV RAILS_ENV $rails_env
ENV GECKODRIVER_VERSION v0.15.0

# Configure IPVS keepalive
ADD /docker/server/ipvs-keepalive.conf /etc/sysctl.d/ipvs-keepalive.conf
RUN sudo sysctl --system

### ADD Gemfile to cache the installation of Gems. If you change the Gemfile, then you will need to rebuild
### your docker containers
ADD /bin /opt/openstudio/bin
ADD /server/Gemfile /opt/openstudio/server/Gemfile
WORKDIR /opt/openstudio/server
RUN bundle install --jobs=3 --retry=3

#### OpenStudio Server Code
VOLUME ["/opt/openstudio"]

# Define working directory
WORKDIR /opt/openstudio/server

COPY /docker/server/start-server-dev.sh /usr/local/bin/start-server-dev
COPY /docker/server/run-server-tests.sh /usr/local/bin/run-server-tests
RUN chmod +x /usr/local/bin/start-server-dev
RUN chmod +x /usr/local/bin/run-server-tests

COPY /docker/server/rails-entrypoint.sh /usr/local/bin/rails-entrypoint
RUN chmod 755 /usr/local/bin/rails-entrypoint
ENTRYPOINT ["rails-entrypoint"]

CMD ["/usr/local/bin/start-server-dev"]

# Expose ports.
EXPOSE 8080 9090

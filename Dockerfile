# AUTHOR:           Nicholas Long
# DESCRIPTION:      OpenStudio Server Docker Container
# TO_BUILD_AND_RUN: docker-compose up
# NOTES:            Currently this is one big dockerfile and non-optimal.

FROM ubuntu:14.04
MAINTAINER Nicholas Long nicholas.long@nrel.gov
ARG rails_env=docker
ARG bundle_args="--without development test"

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

# Install Ruby
ADD /docker/deployment/scripts/install_ruby.sh /usr/local/bin/install_ruby.sh
RUN /usr/local/bin/install_ruby.sh 2.2.4 b6eff568b48e0fda76e5a36333175df049b204e91217aa32a65153cc0cdcb761

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

# Install OpenStudio
ADD /docker/deployment/scripts/install_openstudio.sh /usr/local/bin/install_openstudio.sh
ENV OPENSTUDIO_VERSION 2.4.3
ENV OPENSTUDIO_SHA 29a61f6637
RUN /usr/local/bin/install_openstudio.sh $OPENSTUDIO_VERSION $OPENSTUDIO_SHA

# Add RUBYLIB link for openstudio.rb and Radiance env vars
ENV RUBYLIB /usr/Ruby
ENV OPENSTUDIO_SERVER 'true'
ENV OS_RAYPATH /usr/Radiance
ENV PERL_EXE_PATH /usr/bin

# Set the rails env var
ENV RAILS_ENV $rails_env
ENV GECKODRIVER_VERSION v0.15.0

# Install vfb and firefox requirement if docker-test env
RUN if [ "$RAILS_ENV" = "docker-test" ]; then \
        echo "Running in testing environment - Installing Firefox and Gecko Driver" && \
        echo "deb http://downloads.sourceforge.net/project/ubuntuzilla/mozilla/apt all main" | tee -a /etc/apt/sources.list > /dev/null && \
        apt-key adv --recv-keys --keyserver keyserver.ubuntu.com C1289A29 && \
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
        chmod +x geckodriver; \
    else \
        echo "Not Running in testing environment"; \
    fi

#### OpenStudio Server Code
# First upload the Gemfile* so that it can cache the Gems -- do this first because it is slow
ADD /bin /opt/openstudio/bin
ADD /server/Gemfile /opt/openstudio/server/Gemfile
WORKDIR /opt/openstudio/server
RUN bundle install --jobs=3 --retry=3 $bundle_args

# Add the app assets and precompile assets. Do it this way so that when the app changes the assets don't
# have to be recompiled everytime
ADD /server/Rakefile /opt/openstudio/server/Rakefile
ADD /server/config/ /opt/openstudio/server/config/
ADD /server/app/assets/ /opt/openstudio/server/app/assets/
ADD /server/lib /opt/openstudio/server/lib

# Now call precompile
RUN mkdir /opt/openstudio/server/log
RUN bundle exec rake assets:precompile

# Bundle app source
ADD /server /opt/openstudio/server
ADD .rubocop.yml /opt/openstudio/.rubocop.yml
# Run bundle again, because if the user has a local Gemfile.lock it will have been overriden
RUN rm Gemfile.lock
RUN bundle install --jobs=3 --retry=3

# Configure IPVS keepalive
ADD /docker/server/ipvs-keepalive.conf /etc/sysctl.d/ipvs-keepalive.conf
RUN sudo sysctl --system

# forward request and error logs to docker log collector
# TODO: How to get logs out of this, mount shared volume?
#RUN ln -sf /dev/stdout /var/log/nginx/access.log
#RUN ln -sf /dev/stderr /var/log/nginx/error.log
RUN chmod 775 /opt/openstudio/server/log
RUN chmod 666 /opt/openstudio/server/log/*.log

ADD /docker/server/start-server.sh /usr/local/bin/start-server
ADD /docker/server/run-server-tests.sh /usr/local/bin/run-server-tests
ADD /docker/server/memfix-controller.rb /usr/local/lib/memfix-controller.rb
ADD /docker/server/memfix.rb /usr/local/lib/memfix.rb
RUN chmod +x /usr/local/bin/start-server
RUN chmod +x /usr/local/bin/run-server-tests
RUN chmod +x /usr/local/lib/memfix-controller.rb
RUN chmod +x /usr/local/lib/memfix.rb

# set the permissions for windows users
RUN chmod +x /opt/openstudio/server/bin/*

# permissions on where server assets (e.g. paperclip, data points, R images, etc) are stored
RUN mkdir -p /mnt/openstudio/server/R && chmod 777 /mnt/openstudio/server/R
RUN mkdir -p /mnt/openstudio/server/assets && chmod 777 /mnt/openstudio/server/assets
#RUN mkdir -p /mnt/openstudio/server/assets/data_points && chmod 777 /mnt/openstudio/server/assets/data_points
RUN mkdir -p /mnt/openstudio/server/assets/variables && chmod 777 /mnt/openstudio/server/assets/variables
RUN mkdir -p /opt/openstudio/server/tmp && chmod 777 /opt/openstudio/server/tmp

# Test adding the git repo to the container for coveralls
# The #TEST# will be removed in the circleci test script to be run in the test container
#TEST#ADD .git /opt/openstudio/.git

ADD /docker/server/rails-entrypoint.sh /usr/local/bin/rails-entrypoint
RUN chmod 755 /usr/local/bin/rails-entrypoint
ENTRYPOINT ["rails-entrypoint"]

CMD ["/usr/local/bin/start-server"]

# Expose ports.
EXPOSE 8080 9090

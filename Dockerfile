# AUTHOR:           Nicholas Long
# DESCRIPTION:      OpenStudio Server Docker Container
# TO_BUILD_AND_RUN: docker-compose up
# NOTES:            Currently this is one big dockerfile and non-optimal.

FROM ubuntu:14.04
MAINTAINER Nicholas Long nicholas.long@nrel.gov
ARG rails_env=docker
ARG bundle_args="--without development test"

# Install required libaries
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		apt-transport-https \
		bison \
	    build-essential \
		bzip2 \
		ca-certificates \
		curl \
		default-jdk \
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
		libncurses-dev \
		libreadline-dev \
		libxml2-dev \
		libxslt-dev \
        libffi-dev \
        libssl-dev \
        libyaml-dev \
        libice-dev \
        libsm-dev\
        procps \
		ruby \
		tar \
		unzip \
		wget \
		zip \
		zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Build and Install Ruby
#   -- skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.2
ENV RUBY_VERSION 2.2.4
ENV RUBY_DOWNLOAD_SHA256 b6eff568b48e0fda76e5a36333175df049b204e91217aa32a65153cc0cdcb761
ENV RUBYGEMS_VERSION 2.6.6

# some of ruby's build scripts are written in ruby
# we purge this later to make sure our final image uses what we just built
RUN curl -fSL -o ruby.tar.gz "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.gz" | sha256sum -c - \
	&& mkdir -p /usr/src/ruby \
	&& tar -xzf ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.gz \
	&& cd /usr/src/ruby \
	&& { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c \
	&& autoconf \
	&& ./configure --disable-install-doc --enable-shared \
	&& make -j"$(nproc)" \
	&& make install \
	&& apt-get purge -y --auto-remove $buildDeps \
	&& gem update --system $RUBYGEMS_VERSION \
	&& rm -r /usr/src/ruby

ENV BUNDLER_VERSION 1.11.2

RUN gem install bundler --version "$BUNDLER_VERSION"

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_BIN="$GEM_HOME/bin" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

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

# Run this separate to cache the download
ENV OPENSTUDIO_VERSION 2.0.5
ENV OPENSTUDIO_SHA 31a1faa854

# Download from S3
ENV OPENSTUDIO_DOWNLOAD_BASE_URL https://s3.amazonaws.com/openstudio-builds/$OPENSTUDIO_VERSION
ENV OPENSTUDIO_DOWNLOAD_FILENAME OpenStudio-$OPENSTUDIO_VERSION.$OPENSTUDIO_SHA-Linux.deb
ENV OPENSTUDIO_DOWNLOAD_URL $OPENSTUDIO_DOWNLOAD_BASE_URL/$OPENSTUDIO_DOWNLOAD_FILENAME

# Install gdebi, then download and install OpenStudio, then clean up.
# gdebi handles the installation of OpenStudio's dependencies including Qt5,
# Boost, and Ruby 2.0.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libboost-thread1.55.0 \
    && curl -SLO $OPENSTUDIO_DOWNLOAD_URL \
    && gdebi -n $OPENSTUDIO_DOWNLOAD_FILENAME \
    && rm -f $OPENSTUDIO_DOWNLOAD_FILENAME \
    && rm -rf /usr/SketchUpPlugin \
    && rm -rf /var/lib/apt/lists/*

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
RUN bundle install $bundle_args

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
RUN bundle install

# forward request and error logs to docker log collector
# TODO: How to get logs out of this, mount shared volume?
#RUN ln -sf /dev/stdout /var/log/nginx/access.log
#RUN ln -sf /dev/stderr /var/log/nginx/error.log
RUN chmod 775 /opt/openstudio/server/log
RUN chmod 666 /opt/openstudio/server/log/*.log

ADD /docker/server/start-server.sh /usr/local/bin/start-server
ADD /docker/server/run-server-tests.sh /usr/local/bin/run-server-tests
RUN chmod +x /usr/local/bin/start-server
RUN chmod +x /usr/local/bin/run-server-tests

# set the permissions for windows users
RUN chmod +x /opt/openstudio/server/bin/*

# permissions on where server assets (e.g. paperclip, data points, R images, etc) are stored
RUN mkdir -p /mnt/openstudio/server/R && chmod 777 /mnt/openstudio/server/R
RUN mkdir -p /mnt/openstudio/server/assets && chmod 777 /mnt/openstudio/server/assets
#RUN mkdir -p /mnt/openstudio/server/assets/data_points && chmod 777 /mnt/openstudio/server/assets/data_points
#RUN mkdir -p /mnt/openstudio/server/assets/variables && chmod 777 /mnt/openstudio/server/assets/variables

# Test adding the git repo to the container for coveralls
# The #TEST# will be removed in the circleci test script to be run in the test container
#TEST#ADD .git /opt/openstudio/.git

CMD ["/usr/local/bin/start-server"]

# Expose ports.
EXPOSE 8080 9090

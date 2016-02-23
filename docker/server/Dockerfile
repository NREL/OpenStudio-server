# AUTHOR:           Nicholas Long
# DESCRIPTION:      OpenStudio Server Docker Container
# TO_BUILD_AND_RUN: docker-compose up

FROM ubuntu:14.04
MAINTAINER Nicholas Long nicholas.long@nrel.gov

# Install required libaries
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		bison \
	    build-essential \
		bzip2 \
		ca-certificates \
		curl \
		default-jre \
		imagemagick \
		git \
		libbz2-dev \
		libcurl4-openssl-dev \
		libgdbm3 \
		libgdbm-dev \
		libglib2.0-dev \
		libncurses-dev \
		libreadline-dev \
		libxml2-dev \
		libxslt-dev \
        libffi-dev \
        libssl-dev \
        libyaml-dev \
        procps \
		ruby \
		tar \
		wget \
		zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Build and Install Ruby
#   -- skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.0
ENV RUBY_VERSION 2.0.0-p648
ENV RUBY_DOWNLOAD_SHA256 8690bd6b4949c333b3919755c4e48885dbfed6fd055fe9ef89930bde0d2376f8
ENV RUBYGEMS_VERSION 2.5.2

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
	&& ./configure --disable-install-doc \
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
RUN gem install passenger
RUN passenger-install-nginx-module

# First upload the Gemfile* so that it can cache the Gems -- do this first because it is slow
WORKDIR /srv
ADD /server/Gemfile /srv/Gemfile
RUN bundle install

# Add the app assets and precompile assets. Do it this way so that when the app changes the assets don't
# have to be recompiled everytime
ADD /server/Rakefile /srv/Rakefile
ADD /server/config/ /srv/config/
ADD /server/app/assets/ /srv/app/assets/

# Now call precompile
RUN mkdir /srv/log
ENV RAILS_ENV docker
RUN env
RUN rake assets:precompile

# Bundle app source
ADD /server /srv

# Configure the nginx server
RUN mkdir /var/log/nginx
ADD /docker/server/nginx.conf /opt/nginx/conf/nginx.conf

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

#RUN ["passenger-config", "--validate-install"]
CMD ["/opt/nginx/sbin/nginx"]
#CMD ["/bin/true"]
#CMD ["ls", "-al", "/opt/nginx/sbin/nginx"]
#CMD ["/opt/nginx/sbin/nginx"]
#CMD []

# Expose ports.
EXPOSE 8080

############################################################
# Dockerfile to build base CentOS system to test the server against
# Based on CentOS 7.2.1511
############################################################

FROM centos:7.2.1511

MAINTAINER Henry R Horsey henry.horsey@nrel.gov, Nicholas L Long nicholas.long@nrel.gov

# Import required libraries
RUN yum -y update
RUN yum -y install \
	git-core \
	zlib \
	zlib-devel \
	gcc-c++ \
	patch \
	readline \
	readline-devel \
	libyaml-devel \
	libffi-devel \
	openssl-devel \
	make \
	bzip2 \
	autoconf \
	automake \
	libtool \
	bison \
	curl \
	sqlite-devel \
	initscripts
RUN yum clean all

# Build and configure ruby
RUN git clone git://github.com/sstephenson/rbenv.git /.rbenv
RUN git clone git://github.com/sstephenson/ruby-build.git /.rbenv/plugins/ruby-build
ENV PATH /.rbenv/bin:/.rbenv/shims:$PATH
ENV RBENV_ROOT /.rbenv
RUN /.rbenv/plugins/ruby-build/install.sh
RUN echo 'eval "$(rbenv init -)"' >> /.bashrc
RUN echo "gem: --no-rdoc --no-ri" >> /.gemrc
RUN exec $SHELL
ENV RUBY_CONFIGURE_OPTS="--enable-shared"
RUN rbenv install -v 2.0.0-p647
RUN rbenv global 2.0.0-p647
RUN rbenv rehash

# Install mongodb
RUN echo "[mongodb-org-3.0]" >> /etc/yum.repos.d/mongodb-org-3.0.repo
RUN echo "name=MongoDB Repository" >> /etc/yum.repos.d/mongodb-org-3.0.repo
RUN echo "baseurl=https://repo.mongodb.org/yum/redhat/7Server/mongodb-org/3.0/x86_64/" >> /etc/yum.repos.d/mongodb-org-3.0.repo
RUN echo "gpgcheck=0" >> /etc/yum.repos.d/mongodb-org-3.0.repo
RUN echo "enabled=1" >> /etc/yum.repos.d/mongodb-org-3.0.repo
RUN yum -y install mongodb-org
RUN yum clean all
RUN echo "SELINUX=permissive" >> /etc/selinux/config

# Download and install OpenStudio, then clean up
ENV OPENSTUDIO_VERSION 1.13.0
ENV OPENSTUDIO_SHA 2a84a34de5
ENV OPENSTUDIO_DOWNLOAD_BASE_URL https://openstudio-builds.s3.amazonaws.com/2.xDevBuilds
ENV OPENSTUDIO_DOWNLOAD_FILENAME OpenStudio2-$OPENSTUDIO_VERSION.$OPENSTUDIO_SHA-Redhat.tar.gz
ENV OPENSTUDIO_DOWNLOAD_URL $OPENSTUDIO_DOWNLOAD_BASE_URL/$OPENSTUDIO_DOWNLOAD_FILENAME
RUN curl -SLO $OPENSTUDIO_DOWNLOAD_URL
RUN mkdir ~/openstudio/
RUN tar --strip-components 1 -xvf OPENSTUDIO_DOWNLOAD_FILENAME -C ~/openstudio/
RUN rm -f $OPENSTUDIO_DOWNLOAD_FILENAME
RUN rm -rf ~/openstudio/SketchUpPlugin
RUN echo 'export RUBYLIB="$HOME/openstudio/Ruby/:$RUBYLIB"' >> ~/.bashrc
RUN echo 'export PATH="$HOME/openstudio/bin/:$PATH"' >> ~/.bashrc

CMD [ "/bin/bash" ]

# AUTHOR:           Nicholas Long
# DESCRIPTION:      OpenStudio Server Docker Container
# TO_BUILD_AND_RUN: docker-compose up
# Mod for Spawn     Brian Ball

#may include suffix
ARG OPENSTUDIO_VERSION=3.1.0
FROM nrel/openstudio:$OPENSTUDIO_VERSION as base
MAINTAINER Nicholas Long nicholas.long@nrel.gov

# Avoid warnings
# debconf: unable to initialize frontend: Dialog
# debconf: (TERM is not set, so the dialog frontend is not usable.)
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Install required libaries.
#   realpath - needed for wait-for-it
RUN apt-get update && apt-get install -y wget gnupg \
    && wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add - \
#RUN sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6 && \
    && echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.4 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-4.4.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        autoconf \
        bison \
        bsdtar \
        build-essential \
        bzip2 \
        ca-certificates \
        cmake \
        curl \
        default-jdk \
        dos2unix \
        emacs \
        imagemagick \
        gdebi-core \
        git \
        gfortran \
        g++ \
        libarchive-tools \
	    libblas-dev \
	    liblapack-dev \
        libbz2-dev \
        libboost-dev \
        libcurl4-openssl-dev \
        libdbus-glib-1-2 \
        libgdbm5 \
        libgdbm-dev \
        libgfortran3 \
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
        less \
        mongodb-database-tools \
        procps \
        python-dev \
        python-jpype \
        python-lxml \
        python-matplotlib \
        python-nose \
        python-numpy \
        python-pip \
        python-scipy \
        python-tk \
        python3-dev \
        python3-jpype \
        python3-lxml \
        python3-nose \
        python3-numpy \
        python3-pip \
        python3-scipy \
        python3-setuptools \
        python3-tk \
        procps \
        sudo \
        swig \
        tar \
        unzip \
        wget \
        zip \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
   
# Install passenger (this also installs nginx)
ENV PASSENGER_VERSION 6.0.2

RUN gem install passenger -v $PASSENGER_VERSION
RUN passenger-install-nginx-module

# Configure the nginx server
RUN mkdir /var/log/nginx
ADD /docker/server/nginx.conf /opt/nginx/conf/nginx.conf

# Radiance env vars. RUBYLIB is set in the base openstudio container
ENV OPENSTUDIO_SERVER 'true'
ARG OPENSTUDIO_VERSION
ENV OS_RAYPATH /usr/local/openstudio-$OPENSTUDIO_VERSION/Radiance
#make energyplus avail through PATH for EnergyPlusToFMU
ENV PATH="/usr/local/openstudio-$OPENSTUDIO_VERSION/EnergyPlus:${PATH}"
#get EPMacro and ReadVarsESO for EnergyPlusToFMU
COPY /docker/bin/EPMacro /usr/local/openstudio-$OPENSTUDIO_VERSION/EnergyPlus/EPMacro
COPY /docker/bin/ReadVarsESO /usr/local/openstudio-$OPENSTUDIO_VERSION/EnergyPlus/PostProcess/ReadVarsESO
RUN chmod +x /usr/local/openstudio-$OPENSTUDIO_VERSION/EnergyPlus/EPMacro
RUN chmod +x /usr/local/openstudio-$OPENSTUDIO_VERSION/EnergyPlus/PostProcess/ReadVarsESO

ENV PERL_EXE_PATH /usr/bin

# Specify a couple arguments here, after running the majority of the installation above
ARG rails_env=docker
ARG bundle_args="--without development test"
ENV OS_BUNDLER_VERSION=2.1.0

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
#ADD /spec /opt/openstudio/spec
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

#install SPAWN
RUN mkdir /usr/local/spawn && \
cd /usr/local/spawn/ && \
wget https://spawn.s3.amazonaws.com/latest/Spawn-latest-Linux.tar.gz && \
bsdtar --strip-components=1 -xvf Spawn-latest-Linux.tar.gz

#FMPy and dependencies (based on python3)
RUN pip3 install 'PyQt5==5.14.0'
RUN pip3 install PyQtGraph
RUN pip3 install matplotlib
#RUN pip3 install -e git+https://github.com/CATIA-Systems/FMPy@v0.2.14#egg=FMPy
ADD https://api.github.com/repos/brianlball/FMPy/git/refs/heads/run_dir version.json
RUN pip3 install -e git+https://github.com/brianlball/FMPy.git@run_dir#egg=FMPy --src /usr/local/lib/python3.6/dist-packages
#RUN pip3 install FMPy

#install PyFMI dependencies
RUN pip3 install numpy && \
    pip3 install scipy && \
    pip3 install lxml && \
    pip3 install cython

#install sundials
RUN mkdir /usr/local/src/sundials && \
cd /usr/local/src/sundials && \
wget https://github.com/LLNL/sundials/archive/v4.1.0.tar.gz && \
bsdtar --strip-components=1 -xvf v4.1.0.tar.gz && \
mkdir build && \
cd build && \
#cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/sundials && \
cmake -DLAPACK_ENABLE=ON ../. && \
make install

#install Assimulo
#sudo apt-get install libblas-dev liblapack-dev
RUN mkdir /usr/local/src/Assimulo && \
	cd /usr/local/src/Assimulo && \
	wget https://github.com/modelon-community/Assimulo/archive/Assimulo-3.2.tar.gz && \
	bsdtar --strip-components=1 -xvf Assimulo-3.2.tar.gz && \
	#python3 setup.py install --sundials-home=/usr/local/sundials --lapack-home=/usr/lib/x86_64-linux-gnu/lapack --blas-home=/usr/lib/x86_64-linux-gnu/blas
	python3 setup.py install --sundials-home=/usr/local --lapack-home=/usr/lib/x86_64-linux-gnu/lapack --blas-home=/usr/lib/x86_64-linux-gnu/blas
	RUN export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

#install FMI library
RUN mkdir /usr/local/src/fmi && \
	cd /usr/local/src/fmi && \
	wget https://github.com/modelon-community/fmi-library/archive/2.2.tar.gz && \
	bsdtar --strip-components=1 -xvf 2.2.tar.gz && \
	mkdir build-fmi && \
	cd build-fmi && \
	cmake -DFMILIB_INSTALL_PREFIX=/usr/local/fmi ../. && \
	make install test
RUN export LD_LIBRARY_PATH=/usr/local/fmi:$LD_LIBRARY_PATH

#install PyFMI
RUN mkdir /usr/local/src/pyfmi && \
	cd /usr/local/src/pyfmi && \
	wget https://github.com/modelon-community/PyFMI/archive/PyFMI-2.5.7.tar.gz && \
	bsdtar --strip-components=1 -xvf PyFMI-2.5.7.tar.gz && \
	python3 setup.py install --fmil-home=/usr/local/fmi/

ENV DISPLAY :0.0
# Avoid warning that Matplotlib is building the font cache using fc-list. This may take a moment.
# This needs to be towards the end of the script as the command writes data to
# /home/developer/.cache
RUN python -c "import matplotlib.pyplot"

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
# The #TEST# will be removed in the travis test script to be run in the test container
#TEST#COPY .git /opt/openstudio/.git
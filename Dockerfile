# AUTHOR:           Nicholas Long
# DESCRIPTION:      OpenStudio Server Docker Container
# TO_BUILD_AND_RUN: docker-compose up
# NOTES:            Currently this is one big dockerfile and non-optimal.

#may include suffix
ARG OPENSTUDIO_VERSION=3.0.0-beta
FROM nrel/openstudio:$OPENSTUDIO_VERSION as base
MAINTAINER Nicholas Long nicholas.long@nrel.gov

#install JModelica
# Revision numbers from svn
ENV REV_JMODELICA 14023
ENV REV_ASSIMULO 898
ENV SRC_DIR /usr/local/src

# Define the environmental variables needed by JModelica
# JModelica.org supports the following environment variables:
#
# - JMODELICA_HOME containing the path to the JModelica.org installation
#   directory (again, without spaces or ~ in the path).
# - PYTHONPATH containing the path to the directory $JMODELICA_HOME/Python.
# - JAVA_HOME containing the path to a Java JRE or SDK installation.
# - IPOPT_HOME containing the path to an Ipopt installation directory.
# - LD_LIBRARY_PATH containing the path to the $IPOPT_HOME/lib directory
#   (Linux only.)
# - MODELICAPATH containing a sequence of paths representing directories
#   where Modelica libraries are located, separated by colons.

ENV JMODELICA_HOME /usr/local/JModelica
ENV IPOPT_HOME /usr/local/Ipopt-3.12.4
ENV SUNDIALS_HOME $JMODELICA_HOME/ThirdParty/Sundials
ENV CASADI_LIB_HOME $JMODELICA_HOME/ThirdParty/CasADi/lib
ENV CASADI_INTERFACE_HOME $JMODELICA_HOME/lib/casadi_interface
ENV PYTHONPATH $JMODELICA_HOME/Python/:
ENV LD_LIBRARY_PATH $IPOPT_HOME/lib/:\
$JMODELICA_HOME/ThirdParty/Sundials/lib:\
$JMODELICA_HOME/ThirdParty/CasADi/lib
ENV MODELICAPATH $JMODELICA_HOME/ThirdParty/MSL:/home/developer/modelica
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV JCC_JDK=/usr/lib/jvm/java-8-openjdk-amd64
ENV SEPARATE_PROCESS_JVM /usr/lib/jvm/java-8-openjdk-amd64/

# Avoid warnings
# debconf: unable to initialize frontend: Dialog
# debconf: (TERM is not set, so the dialog frontend is not usable.)
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Install required libaries.
#   realpath - needed for wait-for-it
RUN sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv D68FA50FEA312927 && \
    echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | \
    sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list && \
    apt-get update \
	&& apt-get install -y \
        ant \
        apt-transport-https \
        autoconf \
        bison \
        build-essential \
        bzip2 \
        ca-certificates \
        cmake \
        curl \
        cython \
        default-jdk \
        dos2unix \
        emacs \
        imagemagick \
        ipython \
        gdebi-core \
        git \
        gfortran \
        g++ \
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
        mongodb-org-tools \
        openjdk-8-jdk \
        pkg-config \
        python-dev \
        python-jpype \
        python-lxml \
        python-matplotlib \
        python-nose \
        python-numpy \
        python-pip \
        python-scipy \
        python3-pip \
        procps \
        subversion \
        sudo \
        swig \
        tar \
        unzip \
        wget \
        zip \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install jcc-3.0 to avoid error in python -c "import jcc"
#RUN pip install --upgrade pip
RUN ln -s /usr/lib/jvm/java-8-openjdk-amd64 /usr/lib/jvm/java-8-oracle
RUN pip install --upgrade jcc==3.5

# Get Install Ipopt and JModelica, and delete source code with is more than 1GB 

# Replace 1000 with your user / group id
RUN export uid=1000 gid=1000 && \
    mkdir -p /home/developer && \
    mkdir -p /etc/sudoers.d && \
    echo "developer:x:${uid}:${gid}:Developer,,,:/home/developer:/bin/bash" >> /etc/passwd && \
    echo "developer:x:${uid}:" >> /etc/group && \
    echo "developer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/developer && \
    chmod 0440 /etc/sudoers.d/developer && \
    chown ${uid}:${gid} -R /home/developer

ENV DISPLAY :0.0
#FMPy and dependencies (based on python3)
RUN pip3 install 'PyQt5==5.14.0'
RUN pip3 install PyQtGraph
RUN pip3 install matplotlib
#RUN pip3 install -e git+https://github.com/CATIA-Systems/FMPy@v0.2.14#egg=FMPy
RUN pip3 install -e git+https://github.com/brianlball/FMPy.git@stop_time#egg=FMPy --src /usr/local/lib/python3.6/dist-packages
#RUN pip3 install FMPy

# Avoid warning that Matplotlib is building the font cache using fc-list. This may take a moment.
# This needs to be towards the end of the script as the command writes data to
# /home/developer/.cache
RUN python -c "import matplotlib.pyplot"
    
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
#hard code becasue of hacked OS version
#ENV PATH="/usr/local/openstudio-3.0.0-pre1/EnergyPlus/:${PATH}"
#get EPMacro and ReadVarsESO for EnergyPlusToFMU
COPY /docker/bin/EPMacro /usr/local/openstudio-$OPENSTUDIO_VERSION/EnergyPlus/EPMacro
#COPY /docker/bin/EPMacro /usr/local/openstudio-3.0.0-pre1/EnergyPlus/EPMacro
COPY /docker/bin/ReadVarsESO /usr/local/openstudio-$OPENSTUDIO_VERSION/EnergyPlus/PostProcess/ReadVarsESO
#COPY /docker/bin/ReadVarsESO /usr/local/openstudio-3.0.0-pre1/EnergyPlus/PostProcess/ReadVarsESO
RUN chmod +x /usr/local/openstudio-$OPENSTUDIO_VERSION/EnergyPlus/EPMacro
#RUN chmod +x /usr/local/openstudio-3.0.0-pre1/EnergyPlus/EPMacro
RUN chmod +x /usr/local/openstudio-$OPENSTUDIO_VERSION/EnergyPlus/PostProcess/ReadVarsESO
#RUN chmod +x /usr/local/openstudio-3.0.0-pre1/EnergyPlus/PostProcess/ReadVarsESO

ENV PERL_EXE_PATH /usr/bin

# Specify a couple arguments here, after running the majority of the installation above
ARG rails_env=docker
ARG bundle_args="--without development test"
ENV OS_BUNDLER_VERSION=1.17.1

# Set the rails env var
ENV RAILS_ENV $rails_env

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
ADD .rubocop.yml /opt/openstudio/.rubocop.yml
# Run bundle again, because if the user has a local Gemfile.lock it will have been overriden
RUN rm Gemfile.lock
RUN bundle install --jobs=3 --retry=3

# Configure IPVS keepalive
ADD /docker/server/ipvs-keepalive.conf /etc/sysctl.d/ipvs-keepalive.conf
RUN sudo sysctl --system

# Add in scripts for running server. This includes the wait-for-it scripts to ensure other processes (mongo, redis) have
# started before starting the main process.
COPY /docker/server/wait-for-it.sh /usr/local/bin/wait-for-it
COPY /docker/server/start-server.sh /usr/local/bin/start-server
COPY /docker/server/run-server-tests.sh /usr/local/bin/run-server-tests
COPY /docker/server/rails-entrypoint.sh /usr/local/bin/rails-entrypoint
COPY /docker/server/start-web-background.sh /usr/local/bin/start-web-background
COPY /docker/server/start-workers.sh /usr/local/bin/start-workers
COPY /docker/server/memfix-controller.rb /usr/local/lib/memfix-controller.rb
COPY /docker/server/memfix.rb /usr/local/lib/memfix.rb
RUN chmod 755 /usr/local/bin/wait-for-it
RUN chmod +x /usr/local/bin/start-server
RUN chmod +x /usr/local/bin/run-server-tests
RUN chmod 755 /usr/local/bin/rails-entrypoint
RUN chmod 755 /usr/local/bin/start-web-background
RUN chmod 755 /usr/local/bin/start-workers
RUN chmod +x /usr/local/lib/memfix-controller.rb
RUN chmod +x /usr/local/lib/memfix.rb

# set the permissions for windows users
RUN chmod +x /opt/openstudio/server/bin/*

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

# Test adding the git repo to the container for coveralls
# The #TEST# will be removed in the travis test script to be run in the test container
#TEST#COPY .git /opt/openstudio/.git

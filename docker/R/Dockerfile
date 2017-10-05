# AUTHOR:           Nicholas Long
# DESCRIPTION:      OpenStudio Server R Container
# TO_BUILD_AND_RUN: docker-compose up

FROM ubuntu:14.04
MAINTAINER Nicholas Long nicholas.long@nrel.gov

# Install a bunch of dependencies for building R
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        bison \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        imagemagick \
        gdebi-core \
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
        ruby-dev \
        tar \
        unzip \
        wget \
        zip \
        zlib1g-dev \
        debhelper \
        fonts-cabin \
        fonts-comfortaa \
        fonts-droid \
        fonts-font-awesome \
        fonts-freefont-otf \
        fonts-freefont-ttf \
        fonts-gfs-artemisia \
        fonts-gfs-complutum \
        fonts-gfs-didot \
        fonts-gfs-neohellenic \
        fonts-gfs-olga \
        fonts-gfs-solomos \
        fonts-inconsolata \
        fonts-junicode \
        fonts-lato \
        fonts-linuxlibertine \
        fonts-lobster \
        fonts-lobstertwo \
        fonts-oflb-asana-math \
        fonts-sil-gentium \
        fonts-sil-gentium-basic \
        fonts-stix \
        gfortran \
        gir1.2-freedesktop \
        gir1.2-pango-1.0 \
        libblas3 \
        libcairo-script-interpreter2 \
        libcairo2-dev \
        libgs9 \
        libintl-perl \
        libjbig-dev \
        libjpeg-dev \
        libkpathsea6 \
        liblapack-dev \
        liblzma-dev \
        libpoppler44 \
        libtcl8.5 \
        libtiff5-dev \
        libtk8.5 \
        libxml-libxml-perl \
        libxss1 \
        libxt-dev \
        mpack \
        tcl8.5 \
        tcl8.5-dev \
        tk8.5 \
        tk8.5-dev \
        ttf-adf-accanthis \
        ttf-adf-gillius \
    && rm -rf /var/lib/apt/lists/*

#### Build R and install R packages.
ENV R_VERSION 3.4.1
ENV R_MAJOR_VERSION 3
ENV R_SHA 02b1135d15ea969a3582caeb95594a05e830a6debcdb5b85ed2d5836a6a3fc78
RUN curl -fSL -o R.tar.gz "http://cran.fhcrc.org/src/base/R-$R_MAJOR_VERSION/R-$R_VERSION.tar.gz" \
    && echo "$R_SHA R.tar.gz" | sha256sum -c - \
    && mkdir /usr/src/R \
    && tar -xzf R.tar.gz -C /usr/src/R --strip-components=1 \
	&& rm R.tar.gz \
	&& cd /usr/src/R \
    && sed -i 's/NCONNECTIONS 128/NCONNECTIONS 2560/' src/main/connections.c \
    && ./configure --enable-R-shlib \
    && make -j$(nproc) \
    && make install


# Add in the additional R packages
ADD /install_packages.R install_packages.R
RUN Rscript install_packages.R

# Install custom packages
ADD /lib/R-packages /opt/openstudio/R/lib/R-packages
RUN R CMD INSTALL /opt/openstudio/R/lib/R-packages/NRELmoo*.tar.gz /opt/openstudio/R/lib/R-packages/NRELpso*.tar.gz

# Add the remaining files
ADD /lib /opt/openstudio/R/lib

# Install Gems
RUN gem install bundler
RUN cd /opt/openstudio/R/lib && bundle install

ADD /start.R /start.R
ADD /Rserv.conf /etc/Rserv.conf
RUN mkdir -p /mnt/openstudio/log && chmod 775 /mnt/openstudio/log

ADD /rserve-entrypoint.sh /usr/local/bin/rserve-entrypoint
RUN chmod 755 /usr/local/bin/rserve-entrypoint
ENTRYPOINT ["rserve-entrypoint"]

CMD Rscript start.R 2>&1 | tee /mnt/openstudio/log/Rserve.log

EXPOSE 6311



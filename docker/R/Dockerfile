# AUTHOR:           Nicholas Long
# DESCRIPTION:      OpenStudio Server R Container
# TO_BUILD_AND_RUN: docker compose up

ARG DOCKER_PLATFORM=linux/amd64
FROM --platform=${DOCKER_PLATFORM} nrel/openstudio-r:4.4.0
LABEL maintainer="Nicholas Long <nicholas.long@nlr.gov>"

RUN apt-get update \
    && apt-get install -y --no-install-recommends libuv1-dev \
    && rm -rf /var/lib/apt/lists/*

# Add in the additional R packages
ADD /install_packages.R install_packages.R
RUN Rscript install_packages.R

# Install custom packages
ADD /lib/R-packages /opt/openstudio/R/lib/R-packages
RUN R CMD INSTALL /opt/openstudio/R/lib/R-packages/NRELmoo*.tar.gz /opt/openstudio/R/lib/R-packages/NRELpso*.tar.gz /opt/openstudio/R/lib/R-packages/NRELGA*.tar.gz

# Add the remaining files
ADD /lib /opt/openstudio/R/lib

# Install Gems
RUN gem install bundler -v2.4.10
RUN cd /opt/openstudio/R/lib && bundle install --jobs=3 --retry=3

ADD /start.R /start.R
ADD /Rserv.conf /etc/Rserv.conf
RUN mkdir -p /mnt/openstudio/log && chmod 775 /mnt/openstudio/log

ADD /rserve-entrypoint.sh /usr/local/bin/rserve-entrypoint
RUN chmod 755 /usr/local/bin/rserve-entrypoint
ENTRYPOINT ["rserve-entrypoint"]

CMD Rscript start.R 2>&1 | tee /mnt/openstudio/log/Rserve.log

EXPOSE 6311

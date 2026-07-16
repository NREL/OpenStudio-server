# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Note that there are a bunch of base packages that are installed in the base
# OpenStudio-R image here:
# https://raw.githubusercontent.com/NREL/docker-openstudio-r/master/base_packages.R

# Install from a date-frozen CRAN snapshot (Posit Package Manager) so the UNPINNED
# dependencies of the pinned packages below also resolve deterministically. On
# 2026-07-16 a mid-day CRAN publish (ggrepel requiring ggplot2 >= 3.5.2/gtable >=
# 0.3.6) broke image rebuilds that had passed hours earlier. The __linux__/jammy
# path serves prebuilt binaries for the base image's Ubuntu 22.04 + R 4.4 (much
# faster than source compiles); the plain snapshot path is the source fallback.
# To take newer packages, bump the snapshot date deliberately.
snapshot_repos = c(
    'https://packagemanager.posit.co/cran/__linux__/jammy/2026-07-15',
    'https://packagemanager.posit.co/cran/2026-07-15'
)
# Posit Package Manager only serves Linux binaries to clients whose User-Agent
# announces the R version; set it explicitly so install.packages gets binaries.
options(HTTPUserAgent = sprintf('R/%s R (%s)', getRversion(),
    paste(getRversion(), R.version$platform, R.version$arch, R.version$os)))

# Function for installing and verifying that the package was installed correctly (i.e. can be loaded)
install_and_verify = function(package_name, version=NULL, configure.args=c(), repos=snapshot_repos){
    if (!is.null(version)) {
        print(paste("Installing package", package_name, "version", version))
        remotes::install_version(package_name, version=version, repos=repos)
    } else {
        print(paste('Calling install for package', package_name))
        install.packages(package_name, configure.args=configure.args, repos=repos)
    }

    if (!require(package_name, character.only = TRUE)){
        print('Error installing package, check log')
        quit(status=1)
    }
    print(paste('Successfully installed and test loaded', package_name))
}

# Install Probability / Optimization / Analysis Packages
install_and_verify('remotes')
install_and_verify('Matrix', version='1.6-5')
install_and_verify('lhs', version='1.1.6')
install_and_verify('e1071', version='1.7-14')
install_and_verify('triangle', version='1.0')
install_and_verify('NMOF', version='2.8-0')
install_and_verify('mco', version='1.16')
install_and_verify('rgenoud', version='5.9-0.10')
install_and_verify('conf.design', version='2.0.0')
install_and_verify('combinat', version='0.0-8')
install_and_verify('DoE.base', version='1.2-4')
install_and_verify('sensitivity', version='1.30.0')

# R Serve
install_and_verify('Rserve', configure.args=c('PKG_CPPFLAGS=-DNODAEMON'), repos=c('http://rforge.net'))

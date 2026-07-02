# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************
#
# Enhanced R package installation script for openstudio-rserve container.
#
# This script is a drop-in replacement for the external OpenStudio-server's
# install_packages.R with improved error handling and diagnostics. The Dockerfile
# is patched to install system dependencies (NodeJS, npm) before this script runs,
# which is necessary for packages like shiny, sass, and bslib to compile successfully.

# Function for installing and verifying that the package was installed correctly
install_and_verify = function(package_name, version=NULL, configure.args=c(), repos=c('http://cloud.r-project.org', 'http://cran.r-project.org')){
    if (!is.null(version)) {
        print(paste("Installing package", package_name, "version", version))
        remotes::install_version(package_name, version=version, repos=repos)
    } else {
        print(paste('Calling install for package', package_name))
        install.packages(package_name, configure.args=configure.args, repos=repos)
    }

    if (!require(package_name, character.only = TRUE)){
        print(paste('ERROR: Failed to load package', package_name, 'after installation'))
        quit(status=1)
    }
    print(paste('Successfully installed and verified', package_name))
}

print("=== Installing R packages ===")

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

print("=== All packages installed successfully ===")


# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Note that there are a bunch of base packages that are installed in the base
# OpenStudio-R image here:
# https://raw.githubusercontent.com/NREL/docker-openstudio-r/master/base_packages.R

# Function for installing and verifying that the package was installed correctly (i.e. can be loaded)
install_and_verify = function(package_name, version=NULL, configure.args=c(), repos=c('http://cloud.r-project.org', 'http://cran.r-project.org')){
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
install_and_verify('RSpectra', version='0.16-1')
install_and_verify('sensitivity', version='1.30.0')

# R Serve
install_and_verify('Rserve', configure.args=c('PKG_CPPFLAGS=-DNODAEMON'), repos=c('http://rforge.net'))

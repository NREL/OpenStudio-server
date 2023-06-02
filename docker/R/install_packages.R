# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Note that there are a bunch of base packages that are installed in the base
# OpenStudio-R image here:
# https://raw.githubusercontent.com/NREL/docker-openstudio-r/master/base_packages.R

# Function for installing and verifying that the package was installed correctly (i.e. can be loaded)
install_and_verify = function(package_name, configure.args=c(), repos=c('http://cloud.r-project.org','http://cran.r-project.org')){
    print(paste('Calling install for package ', package_name, sep=''))
    install.packages(package_name, configure.args=configure.args, repos=repos)
    if (!require(package_name, character.only = TRUE)){
        print('Error installing package, check log')
        quit(status=1)
    }
    print(paste('Successfully installed and test loaded ', package_name, sep=''))
}

# Install Probability / Optimization / Analysis Packages
install_and_verify('lhs')
install_and_verify('e1071')
install_and_verify('triangle')
install_and_verify('NMOF')
install_and_verify('mco')
install_and_verify('rgenoud')
install_and_verify('conf.design')
install_and_verify('combinat')
install_and_verify('DoE.base')
install_and_verify('sensitivity')

# R Serve
install_and_verify('Rserve', configure.args=c('PKG_CPPFLAGS=-DNODAEMON'), repos=c('http://rforge.net'))

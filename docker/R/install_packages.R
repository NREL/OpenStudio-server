# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

q# Install Packages
install.packages('lhs', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('e1071', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('triangle', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('RUnit', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('R.methodsS3', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('R.oo', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('R.utils', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('NMOF', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('mco', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('rgenoud', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('conf.design', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('vcd', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('combinat', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('DoE.base', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('xts', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('rjson', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('RSQLite', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('Rcpp', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('plyr', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('ggplot2', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('reshape2', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('cowplot', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('ggsci', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('sensitivity', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('foreach', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('iterators', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('doParallel', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('doMC', repos=c('http://cloud.r-project.org','http://cran.r-project.org'))
install.packages('Rserve', configure.args=c('PKG_CPPFLAGS=-DNODAEMON'), repos=c('http://rforge.net'))
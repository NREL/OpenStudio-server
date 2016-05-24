#*******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC.
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
#*******************************************************************************

name 'r-project'
description 'install r'

default_attributes(
  r: {
    version: '3.2.2',
    checksum: '9c9152e74134b68b0f3a1c7083764adc1cb56fd8336bec003fd0ca550cd2461d',
    install_repo: false,
    install_method: 'source',
    add_r_to_path: true,
    add_ld_path: true,
    prefix_bin: '/usr/local/bin',
    make_opts: ['-j4'],
    r_environment_site: {
      rubylib: '/usr/local/lib/site_ruby/2.0.0',
      path_additions: ['/usr/local/radiance/bin', '/opt/rbenv/shims']
    },
    libraries: [
      {
        name: 'Rserve',
        configure_flags: 'PKG_CPPFLAGS=-DNODAEMON'
      },
      {
        name: 'lhs'
      },
      {
        name: 'e1071'
      },
      {
        name: 'triangle'
      },
      {
        name: 'rJava'
      },
      {
        name: 'RUnit'
      },
      {
        name: 'RMongo'
      },
      {
        name: 'R.methodsS3'
      },
      {
        name: 'R.oo'
      },
      {
        name: 'R.utils'
      },
      {
        name: 'NMOF'
      },
      {
        name: 'mco'
      },
      {
        name: 'rjson'
      },
      {
        name: 'rgenoud'
      },
      {
        name: 'conf.design'
      },
      {
        name: 'vcd'
      },
      {
        name: 'combinat'
      },
      {
        name: 'DoE.base'
      },
      {
        name: 'NRELmoo',
        package_path: '/data/R-packages',
        version: '1.2.23',
        update_method: 'always_update'
      },
      {
        name: 'NRELpso',
        package_path: '/data/R-packages',
        version: '0.3.13',
        update_method: 'always_update'
      },
      {
        name: 'xts'
      },
      {
        name: 'RSQLite'
      },
      {
        name: 'Rcpp'
      },
      {
        name: 'plyr'
      },
      {
        name: 'ggplot2'
      },
      {
        name: 'sensitivity'
      }
    ]
  }
)

override_attributes(
  r: {
    config_opts: ['--enable-R-shlib'] # build with x11 support (removes "--with-x=no",)
  }
)

run_list(
  [
    'recipe[r::default]',
    'recipe[r::rserve]'
  ])

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

name 'passenger_apache'
description 'A default role for passenger through apache.'

run_list([
  'recipe[passenger_apache2]',
  'recipe[passenger_apache2::mod_rails]'
])

# TODO: check how many of these are now deprecated? https://github.com/opscode-cookbooks/passenger_apache2/blob/master/attributes/default.rb
default_attributes(
  passenger: {
    version: '4.0.50',

    # explicitly set the path so it know which ruby to use
    #:root_path => "/opt/rbenv/shims",

    # Run all passengers processes as the apache user.
    user_switching: false,
    default_user: 'apache',

    # Disable friendly error pages by default.
    friendly_error_pages: false,

    # Allow more application instances.
    max_pool_size: 16,

    # Ensure this is less than :max_pool_size, so there's always room for all
    # other apps, even if one app is popular.
    max_instances_per_app: 6,

    # Keep at least one instance running for all apps.
    min_instances: 1,

    # Increase an instance idle time to 15 minutes.
    pool_idle_time: 900,

    # Keep the spanwers alive indefinitely, so new app processes can spin up
    # quickly.
    rails_framework_spawner_idle_time: 0, # Not actually used since we use smart-lv2 spawning?
    rails_app_spawner_idle_time: 0
  }
)

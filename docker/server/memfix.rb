#!/usr/bin/env ruby

cmd_str = 'while [ "0" -eq "0" ]; do for pid in $(pidof "Passenger RubyApp: /opt/openstudio/server/public (docker)"); do memory=$(cat /proc/$pid/status | grep VmRSS | grep -o [0-9]*); if [ "$memory" -gt "500000" ]; then echo "Killing pid $pid using $memory kB of memory" >> "/opt/openstudio/server/log/mem_saver.log"; kill $pid; fi; done; sleep 901; done'
loop do
  system cmd_str
end


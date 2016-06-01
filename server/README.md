# OpenStudio Rails Application

## Starting Worker Pools

The server is required to have a running delayed job instances watching
the `analyses` queue. 

```
bin/delayed_job -i server stop && bin/delayed_job -i server --queue=analyses,background start
```

Depending on the resources available on the machine, the worker nodes
can be spun up with the following command. 

```
bin/delayed_job -i worker_1 stop && bin/delayed_job -i worker_1 --queue=simulations start
bin/delayed_job -i worker_2 stop && bin/delayed_job -i worker_2 --queue=simulations start
```


```
# All in one command
bin/delayed_job -i server stop && bin/delayed_job -i server --queue=analyses,background start && bin/delayed_job -i worker_1 stop && bin/delayed_job -i worker_1 --queue=simulations start
```

## Install Nokogiri (with Brew System Libraries)

```
gem install nokogiri -- --use-system-libraries --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/
gem install libxml-ruby -- --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/
```

# TODOs

* Rename Data Points to Datapoints
* Re-enable worker logs posting to Server
* Add LogStash (or something similar)


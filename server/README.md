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

For development in the foreground

```
bin/delayed_job -i server --queue=analyses,background run
bin/delayed_job -i worker_1 --queue=simulations run
```

## Install Nokogiri (with Brew System Libraries)

```
gem install nokogiri -- --use-system-libraries --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/
gem install libxml-ruby -- --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/
```

# Testing using Docker-compose

```
docker volume create --name=osdata
docker-compose -f docker-compose.yml -f docker-compose.test.yml build
docker-compose -f docker-compose.yml -f docker-compose.test.yml up
```

# TODOs

* Rename Data Points to Datapoints
* Re-enable worker logs posting to Server
* Add LogStash (or something similar)
* Move the remaining analyses to the R folder and break out from the ruby files
* Write tests for each analysis (expand existing SPEA test)
* Add CLI path to config.yml
* Add tests for embedded files on analysis model. Test result of R code that pushed to analysis model (i.e. best_point.json)


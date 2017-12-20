# OpenStudio Rails Application

## Algorithmic Development Dependencies

```bash
# Install R and packages in ../docker/R/install_packages.R
brew install ImageMagick
```
## Starting Worker Pools

The worker pool can be either Delayed Jobs or Resque depending on the Rails environment. The
delayed jobs queue is only for local and local-test environments. All other environments are 
assuming Resque.

There are 3 queues that need to be watched and are described below:

* *Background*: These are background tasks that run on the web server volume in order to execute long running tasks in the background. The only task currently is deleting the analysis directory.
* *Analyses*: This queues holds the analyses until all the simulations are complete.
* *Simulations*: This queue is the simulation queue which runs the simulations on worker nodes.
 
### Delayed Jobs

```
# Web Server
bin/delayed_job -i server stop && bin/delayed_job -i server --queue=analyses,background start

# Workers
# Change the number of workers based on the resources available
bin/delayed_job -i worker_1 stop && bin/delayed_job -i worker_1 --queue=simulations start
bin/delayed_job -i worker_2 stop && bin/delayed_job -i worker_2 --queue=simulations start

# All in one command
bin/delayed_job -i server stop && bin/delayed_job -i server --queue=analyses,background start && bin/delayed_job -i worker_1 stop && bin/delayed_job -i worker_1 --queue=simulations start
```

### Resque

```bash
# Foreground - one terminal for each command
QUEUES=background,analyses rake resque:work
COUNT=4 QUEUES=simulations rake resque:workers
```


## Starting Rserve for development in the foreground

```
R
libary(Rserve)
Rserve()

```

## Install Nokogiri (with Brew System Libraries)

```
gem install nokogiri -- --use-system-libraries --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/
gem install libxml-ruby -- --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/
```

# Testing using Docker-compose

```
docker volume create --name=osdata
docker-compose -f docker-compose.test.yml build
docker-compose -f docker-compose.test.yml up

# One line
docker-compose rm -f && docker-compose -f docker-compose.test.yml build && docker-compose -f docker-compose.test.yml up
```

# Testing Dependencies

If running the tests on a local machine, then make sure to install
geckodriver to run the webpage.

```
bundle install
brew install geckodriver
```
# TODOs

* Rename Data Points to Datapoints
* Re-enable worker logs posting to Server
* Add LogStash (or something similar)
* Write tests for each analysis (expand existing SPEA test)
* Add CLI path to config.yml
* Add tests for embedded files on analysis model. Test result of R code that pushed to analysis model (i.e. best_point.json)

# AWS Elastic Container Service

It is possible to use Amazon's Elastic Container Service but it will
be limited to only running one machine and it is not possible to add
more worker nodes. The preferred approach is to use docker-machine and 
docker-swarm or to custom deploy.

```
ecs-cli configure --cluster openstudio
ecs-cli up --keypair <key-pair-name> --capability-iam --size 1 --instance-type t2.medium --port 8080
ecs-cli compose -f docker-compose.deploy.yml up
# Get the IP address from the console `ecs-cli ps`
ecs-cli down --force
```

# Docker-Machine

## AWS

The easiest approach to using Docker-Machine is to export your keys as
environment variables.

```
export $AWS_ACCESS_KEY_ID=<your-access-key>
export $AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
```


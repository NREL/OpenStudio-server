# OpenStudio Rails Application

## Algorithmic Development Dependencies

```bash
# Install R and packages in ../docker/R/install_packages.R
brew install ImageMagick
```
## Starting Worker Pools

The server is required to have a running delayed job instance watching
the `analyses` queue. 

```
bin/delayed_job -i server stop && bin/delayed_job -i server --queue=analyses,background start
```

Depending on the resources available on the machine, the worker nodes
can be spun up with the following commands:

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

# Testing

If running the tests on a local machine, then make sure to install
geckodriver to run the webpage.

```
bundle install
brew install geckodriver
```

There are several layers of testing for OpenStudio Server and each uses a different software solution.

* Unit/Functional Tests: Unit tests are run using gitlab and a cluster of machines for Windows, Mac, and Linux. The functional tests use geckodriver and selenium to test the frontend end.
* Integration Tests: These tests verify that the version of OpenStudio works with the version of OpenStudio Server and the meta CLI. These are run as part of the Unit/Functional tests.
* Docker Tests and Publishing Containers: The Docker tests are run before publishing the new containers. The tests and publishing scripts are run}} on Circle CI because of the time needed to build the containers. These are only run the develop and master branch.
* Rubocop: These tests verify that the code meets the ruby / rails standard. These tests are currently run on travis but will be moved to gitlab.
 
# TODOs

* Rename Data Points to Datapoints
* Re-enable worker logs posting to Server
* Add LogStash (or something similar)
* Move the remaining analyses to the R folder and break out from the ruby files
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


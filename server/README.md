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

There are 4 queues that need to be watched and are described below:

* *Background*: These are background tasks that run on the web server volume in order to execute long running tasks in the background. The only task currently is deleting the analysis directory.
* *Analyses*: This queues holds the analyses until all the simulations are complete.
* *Simulations*: This queue is the simulation queue which runs the simulations on worker nodes.
* *Analysis Finalization*: This queue runs analysis finalization scripts on the web_1 node.
 
### Delayed Jobs

```
# Background and Analysis Jobs
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
QUEUES=background,analyses bundle exec rake environment resque:work
QUEUES=analysis_wrappers bundle exec rake environment resque:work
COUNT=2 QUEUES=simulations bundle exec rake environment resque:workers
```

### Running Simulations for development in the foreground

OpenStudio Server now runs the simulations through the OpenStudio CLI. In order for this to work on local development,
the gems need to be installed in the OpenStudio installation directory. Run the following for OSX:

```bash
cd /Applications/OpenStudio-x.y.z/Ruby
bundle install --path ./gems
```

## Starting Rserve for development in the foreground

```
R
libary(Rserve)
Rserve()
```

It is also possible to run Rserve from the docker container which contains all of the needed 
libraries already installed.

```bash
# from OpenStudio-server root directory
mkdir -p worker-nodes/server/R
cd worker-nodes
docker run -it -v $(pwd):$(pwd) -p 6311:6311 nrel/openstudio-rserve
```

## Install Nokogiri (with Brew System Libraries)

```
gem install nokogiri -- --use-system-libraries --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/
gem install libxml-ruby -- --with-xml2-include=/usr/include/libxml2 --with-xml2-lib=/usr/lib/
```

# Testing

If running the tests on a local machine, then make sure to install geckodriver to run the webpage.

```
bundle install
brew install geckodriver
```

There are several layers of testing for OpenStudio Server and each uses a different software solution.

* Unit/Functional Tests: Unit tests are run using TravisCI and AppVeyor. The functional tests use geckodriver and 
selenium to test the frontend end.
* Integration Tests: These tests verify that the version of OpenStudio works with the version of OpenStudio Server and
the meta CLI. These are run as part of the Unit/Functional tests.
* Docker Tests and Publishing Containers: The Docker tests are run before publishing the new containers. The tests and 
publishing scripts are run on TravisCI. These are only run the develop and master branch.
* Rubocop: These tests verify that the code meets the ruby / rails standard. These tests are currently run on travis.
 
# TODOs

* Rename Data Points to Datapoints
* Re-enable worker logs posting to Server
* Add LogStash (or something similar)
* Write tests for each analysis (expand existing SPEA test)
* Add CLI path to config.yml
* Add tests for embedded files on analysis model. Test result of R code that pushed to analysis model (i.e. best_point.json)

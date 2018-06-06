# OpenStudio Server

[![Build Status][circleci-img]][circleci-url] [![Coverage Status][coveralls-img]][coveralls-url]
OSX Build: [![Build Status][travis-img]][travis-url]
Windows Build (Under Development): [![Build status][appveyor-img]][appveyor-url]


## Standard Use Cases:

There are two primary ways for non-application-developers to use this codebase. The first is through the Parametric Analysis Tool (PAT) which both runs this codebase locally on a system and interfaces with local and AWS docker based instances. This can be accessed through downloading the [official OpenStudio release](https://www.openstudio.net/downloads). The second is through the OpenStudio Analysis Spreadsheet, (the Spreadsheet) which is can be downloaded or cloned from it's [github repository](https://github.com/NREL/OpenStudio-analysis-spreadsheet). 

## Application Development and Deployment:

There are primarily three ways to utilize and deploy this codebase. The first pathway is through the [openstudio_meta](./bin/openstudio_meta) CLI. This deployment strategy allows for the server to be deployed on a local desktop without docker through a pre-compilation process of all required gem dependencies. Additionally, it allows for cloud instances to be created and analyses run on them. The second pathway utilizes [Docker Compose](https://docs.docker.com/compose/). This is the preferred environment for application development, as it is allows for rapid iteration and does not encumber developers with deployment configuration details. The recommended deployment pathway uses [Docker Swarm](https://docs.docker.com/engine/swarm/), an orchestration engine which allows for multi-node clusters and provides significant benefits in the forms of customization and hardening of network and storage fundamentals.

### openstudio_meta:

The [openstudio_meta](./bin/openstudio_meta) file is a ruby script which provides access to packaging and execution commands which allow for this codebase to be embedded in applications deployed to computers without docker. Deployment requires that [MongoDB v3.2](https://www.mongodb.com/download-center#previous) and [Ruby v2.2](https://www.ruby-lang.org/en/news/2014/12/25/ruby-2-2-0-released/) are additionally packaged. For an example of cross-platform deployment please see the OpenStudio build guide for the [2.X releases](https://github.com/NREL/OpenStudio/wiki/Configuring-OpenStudio-Build-Environments) and the [CMake lists](https://github.com/NREL/OpenStudio/blob/develop/openstudiocore/CMakeLists.txt). 

The openstudio_meta deployment relies on the `install_gems` command, which uses local system libraries to build all required gem dependencies of the server. Additionally, the export flag allows for the resulting package to be automatically assembled and zipped for deployment. It is important to note that when used on OSX and Linux systems, it is critical to not specify the export path with home (`~`) substitution. Instead, pass a fully specified path to the desired output directory. 

Once compiled or unpacked, the openstudio_meta file can be used for starting and stopping local and remote server, and submitting analyses to both. Assembling the required files for the analysis is left to either the OpenStudio Analysis Spreadsheet (the Spreadsheet) or the Parametric Assessment Tool (PAT). The Spreadsheet has a similar interface for submitting analyses to servers, and PAT makes complete use of the openstudio_meta features. For more details, please refer to the [wiki](https://github.com/NREL/OpenStudio-server/wiki/CLI).

### Local Docker Development:

To develop locally the following dependency stack is recommended. First, please install Docker. The recommended path for OSX users is to install Docker CE for Mac](https://docs.docker.com/docker-for-mac/install/). If using Windows 10, please use [Docker CE for Windows](https://docs.docker.com/docker-for-windows/install/); if using a Windows version pre 10, please use Docker Toolbox. You will need to install and configure dependencies, including [VirtualBox](https://docs.docker.com/toolbox/toolbox_install_windows/#next-steps). Please refer to [this guide]() from Docker on configuring your system pre Windows 10, [this guide](https://docs.docker.com/docker-for-windows/) if using Docker CE on Windows 10, and [this guide](https://docs.docker.com/docker-for-mac/) if using Docker CE on OSX. If using a linux flavour, please follow the instructions in the [appropriate guide](https://www.docker.com/community-edition) to install Docker CE on your system and configure it. Note that Docker Compose version 1.13.0 or higher is required, and that Docker Server version 17.9.01 is strongly recommended. Although generally newer versions of docker will behave as expected, certain CLI interactions change between releases, leading to scripts breaking and default behaviours, particularly regarding persistence, changing. The docker version installed and running can be found by typing `docker info` on the command line.

#### Run Docker Compose 
```
docker-compose build
```
... [be patient](https://www.youtube.com/watch?v=f4hkPn0Un_Q) ... If the containers build successfully start them by running `docker volume create --name=osdata && docker volume create --name=dbdata && OS_SERVER_NUMBER_OF_WORKERS=5 docker-compose up` where N is equal to the number of worker nodes you wish to run. For single node servers this should not be greater than the total number of available cores minus 4.

Resetting the containers can be accomplished by running:
``` 
docker-compose rm -f
docker volume rm osdata dbdata
docker volume create --name=osdata
docker volume create --name=dbdata
docker-compose up
docker-compose scale worker=N

# Or one line
docker-compose rm -f && docker-compose build && docker volume rm osdata dbdata && docker volume create --name=osdata && docker volume create --name=dbdata && OS_SERVER_NUMBER_OF_WORKERS=5 docker-compose up && docker-compose scale worker=N
```

Congratulations! Visit `http://localhost:8080` to see the OpenStudio Server Management Console.

#### Running the Docker CI testing locally

```
docker-compose rm -f
docker volume rm osdata
docker volume create --name=osdata
export RAILS_ENV=docker-test
export CI=true
export CIRCLECI=true
sed -i -E "s/#TEST#//g" Dockerfile
sed -i -E "s/.git//g" .dockerignore
docker-compose -f docker-compose.test.yml build
docker-compose -f docker-compose.test.yml run -d rserve
docker-compose -f docker-compose.test.yml run -d web-background
docker-compose -f docker-compose.test.yml run -d db
mkdir -p reports/rspec
docker-compose -f docker-compose.test.yml run web

# Or condenced
sed -i -E "s/#TEST#//g" Dockerfilesu
sed -i -E "s/.git//g" .dockerignore
docker-compose rm -f && docker-compose -f docker-compose.test.yml build && docker volume rm osdata && docker volume create --name=osdata && docker-compose -f docker-compose.test.yml up
git checkout -- Dockerfile .dockerignore
```

### Docker Deployment:

To deploy the OpenStudio Server in a docker-based production environment one or more machines need to be running Docker Server version 17.9.01. If using docker on a linux machine it is recommended that significant storage be available to the `/var` folder. This is where Docker reads and writes all data to by default. In addition, advanced users may wish to consider using specialized [storage drivers](https://docs.docker.com/engine/userguide/storagedriver/). Please refer to the [wiki](https://github.com/NREL/OpenStudio-server/wiki) page for additional details and a [configuration and reset guide](). Deploying a production docker swarm system outside of AWS (where complications are managed and support by NREL) can be a non-trivial problem that may require significant systems administration experience. Those embarking on this process are encouraged to refer to the scripts used by Packer to configure [Ubuntu](https://github.com/NREL/OpenStudio-server/blob/develop/docker/deployment/scripts/aws_system_init.sh) and [docker](https://github.com/NREL/OpenStudio-server/blob/develop/docker/deployment/scripts/aws_osserver_init.sh) in the base AMI images, as well as the scripts used to provision the [server](https://github.com/NREL/OpenStudio-server/blob/develop/docker/deployment/scripts/server_provision.sh) and [worker](https://github.com/NREL/OpenStudio-server/blob/develop/docker/deployment/scripts/worker_provision.sh) nodes upon instantiation in a cluster.

## Testing procedure:

The OpenStudio Server project uses several CI systems to test both local and cloud deployments across multiple platforms. CircleCI is used to build and test docker containers for each commit. TravisCI is used to build and test local deployments of the server on OSX hardware for each commit. It is important to note that durring the middle of the day, these tests can take several hours to begin. Finally, AppVeyor is used to build and test local deployments against Windows. 

In the case of local deployments, (Travis and AppVeyor,) the build step uses the meta-cli's install_gems command to create a new set of cached ruby dependencies to test against. The test phase is made up of two spereate testing methodologies. The first uses rspec to run a number of unit tests against using a locally instantiated server. The second instantiates the server in the same maner as PAT, runs analyses against said server, and ensures that it stops as expected, using the meta-cli.

For cloud deployments, the two critical artifacts are the docker containers and AMIs. Currently AMI testing is not automated, and unlikely to be automated for several reason. The docker containers, however, are extensivly tested using the same rspec functionality as mentioned above. 

For a pull request to be merged under regular order, 5 CI tests need to return green: TravisCI PR and push, AppVeyor PR and push, and CircleCI PR. All of these tests, except for the CircleCI tests, write verbose results and logs on failure, which should allow for local reproduction of the bug and subsequent fixes. In the case of a failure of the CI infrastructure, please open an issue in the repository regarding the failure. 

## Commands to update gems used in PAT manually:

To test the impact of upgraded gems on PAT's functionality the currently recommended path is to manually remove and recreate the cached set of gems, including compiled binary components. This process is platform specific. Currently instructions are only available for OSX, due to complications compiling the binary component of gems with the ruby instillation provided in the OpenStudio installer package.

### OSX:

```
cd /Applications/OpenStudio-X.Y.Z/ParametricAnalysisTool.app/Contents/Resources/OpenStudio-server # Change directory to the install location of the Server
rm -rf /gems # Remove the pre-packaged gems
vi server/Gemfile # Edit the Gemfile
rm server/Gemfile.lock # Remove the cached gem specifications
../ruby/bin/ruby ./bin/openstudio_meta install_gems # Reinstall the gems required (including new gems)
chmod -R 777 gems # Modify privileges on the installed gems
```

## Questions?

Please contact @rhorsey, @bball, or @nllong with any question regarding this project. Thanks for you interest!

[circleci-img]: https://circleci.com/gh/NREL/OpenStudio-server/tree/dockerize.svg?style=svg
[circleci-url]: https://circleci.com/gh/NREL/OpenStudio-server
[coveralls-img]: https://coveralls.io/repos/github/NREL/OpenStudio-server/badge.svg?branch=dockerize
[coveralls-url]: https://coveralls.io/github/NREL/OpenStudio-server
[travis-img]: https://travis-ci.org/NREL/OpenStudio-server.svg?branch=dockerize-travis
[travis-url]: https://travis-ci.org/NREL/OpenStudio-server
[appveyor-img]: https://ci.appveyor.com/api/projects/status/j7hqgh2p7bae9xn8/branch/dockerize-appveyor?svg=true
[appveyor-url]: https://ci.appveyor.com/project/rHorsey/openstudio-server/branch/dockerize-appveyor

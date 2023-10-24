# OpenStudio(R) Server

[![Build Status][gh-img]][gh-url] 
[![Coverage Status][coveralls-img]][coveralls-url]

Please refer to the [wiki](https://github.com/NREL/OpenStudio-server/wiki) for additional documentation.

<img src="https://github.com/NREL/OpenStudio-server/assets/2235296/fe91da7d-9e3f-4459-ac5d-579444e6125e" width=50% height=50%>
<img src="https://github.com/NREL/OpenStudio-server/assets/2235296/c4a75731-72f7-42e6-afc7-d24b9e835a2e" width=50% height=50%>

## About

OpenStudio Server is a web application and distributed computing tool, which is the backbone of the OpenStudio Analysis Framework (OSAF).
It is intended to make parametric analysis of building energy models accessible to architects, engineers, and designers via the [OpenStudio PAT](http://nrel.github.io/OpenStudio-user-documentation/reference/parametric_studies/) GUI or the [OpenStudio Analysis Gem](https://github.com/NREL/OpenStudio-analysis-gem). 
OpenStudio Server analyses are defined by PAT projects or OSA's.  Each analysis may include many OpenStudio simulations, as determined by project configuration.

Journal of Building Performance Simulation article: [An open source analysis framework for large-scale building energy modeling](https://www.tandfonline.com/doi/full/10.1080/19401493.2020.1778788)

## Application Development and Deployment

There are primarily two ways to utilize and deploy this codebase.
 
* [openstudio-server-helm](https://github.com/NREL/openstudio-server-helm) This helm chart installs a OpenStudio-server instance deployment on a AWS, Azure, or Google Kubernetes cluster using the Helm package manager. You can interface with the OpenStudio-server cluster using the Parametric Analysis Tool or the [openstudio_meta](./bin/openstudio_meta) CLI.
   
* [Docker Swarm](https://docs.docker.com/engine/swarm/): This is the recommended local deployment pathway. Swarm is an 
orchestration engine which allows for multi-node clusters and provides significant benefits in the forms of 
customization and hardening of network and storage 
fundamentals.

### openstudio_meta

The [openstudio_meta](./bin/openstudio_meta) file is a ruby script which provides access to packaging and execution 
commands which allow for this codebase to be embedded in applications deployed to computers without docker. Deployment 
requires that [MongoDB 6.0.7](https://www.mongodb.com/download-center/community/releases/archive) and [Ruby v2.7](https://www.ruby-lang.org/en/downloads/) 
are additionally packaged. 

The openstudio_meta deployment relies on the `install_gems` command, which uses local system libraries to build all 
required gem dependencies of the server. Additionally, the export flag allows for the resulting package to be 
automatically assembled and zipped for deployment. It is important to note that when used on OSX and Linux systems, 
it is critical to not specify the export path with home (`~`) substitution. Instead, pass a fully specified path to the 
desired output directory. 

Once compiled or unpacked, the openstudio_meta file can be used for starting and stopping the local server for the [Parametric Analysis Tool (PAT)](https://github.com/NREL/OpenStudio-PAT) and 
submitting analyses to it. Assembling the required files for the analysis is done with the [Analysis-gem](https://github.com/NREL/OpenStudio-analysis-gem) or the export OSA function in PAT. For more details, please 
refer to the [wiki](https://github.com/NREL/OpenStudio-server/wiki/CLI).  For examples, please refer to [OSAF notebooks](https://github.com/NREL/docker-openstudio-jupyter/tree/master).

### Local Docker Development

To develop locally the following dependency stack is recommended. 

* Install Docker (Version 20.10.5 or greater is required)
    * OSX Users: [install Docker CE for Mac](https://docs.docker.com/docker-for-mac/install/). Please refer to [this guide](https://docs.docker.com/docker-for-mac/install/)
    * Windows 10 Users: [Docker Desktop](https://www.docker.com/products/docker-desktop/).
    * Linux Users: Follow the instructions in the [appropriate guide](https://www.docker.com/community-edition)
    
    *Note: Although generally newer versions of docker will behave as expected, certain CLI interactions change between
    releases, leading to scripts breaking and default behaviours, particularly regarding persistence, changing. The 
    docker version installed and running can be found by typing `docker info` on the command line.*
    
#### Docker Compose 

```bash
docker-compose build
```
... [be patient](https://www.youtube.com/watch?v=f4hkPn0Un_Q) ... If the containers build successfully start them by 
running `docker volume create --name=osdata && docker volume create --name=dbdata && OS_SERVER_NUMBER_OF_WORKERS=4 docker-compose up` 
where 4 is equal to the number of worker nodes you wish to run. For single node servers this should not be greater 
than the total number of available cores minus 4.

Resetting the containers can be accomplished by running:

```bash
docker-compose rm -f
docker volume rm osdata dbdata
docker volume create --name=osdata
docker volume create --name=dbdata
OS_SERVER_NUMBER_OF_WORKERS=N docker-compose up
docker-compose service scale worker=N

# Or one line
docker-compose rm -f && docker-compose build && docker volume rm osdata dbdata && docker volume create --name=osdata && docker volume create --name=dbdata && OS_SERVER_NUMBER_OF_WORKERS=N docker-compose up && docker-compose service scale worker=N
```

Congratulations! Visit `http://localhost:8080` to see the OpenStudio Server Management Console.

#### Running the Docker CI testing locally

```bash
export OPENSTUDIO_TAG=develop
export RAILS_ENV=docker-test

docker-compose rm -f
docker volume rm osdata
sed -i -E "s/.git//g" .dockerignore
docker volume create --name=osdata
docker-compose -f docker-compose.test.yml pull
docker-compose -f docker-compose.test.yml build --build-arg OPENSTUDIO_VERSION=$OPENSTUDIO_TAG
docker-compose -f docker-compose.test.yml up -d
docker-compose exec -T web /usr/local/bin/run-server-tests
docker-compose stop
git checkout -- .dockerignore && git checkout -- Dockerfile
docker-compose rm -f
```

### Local Docker Swarm Deployment

To deploy the OpenStudio Server in a docker-based production environment one or more machines need to be running Docker 
Server version 20.10.05. If using docker on a Linux machine it is recommended that significant storage be available to 
the `/var` folder. This is where Docker reads and writes all data to by default unless changed in the docker-compose.yml file. 
There are scripts to help with docker swarm deployment [here](https://github.com/NREL/OpenStudio-server/tree/develop/local_setup_scripts).
Make sure to change the defaults to be applicable to your hardware requirements.

## Testing procedure

The OpenStudio Server project uses several CI systems to test both local and cloud deployments across multiple 
platforms. GitHub Actions is used to build and test local deployments of the server on OSX hardware for each commit, as well 
as to build and test docker containers for each commit. It is important to note that during the middle of the 
day, these tests can take several hours to begin. Finally, AppVeyor is used to build and test local deployments against
Windows. 

In the case of local deployments (non-docker deployments) the build step uses the meta-cli's install_gems command to 
create a new set of cached ruby dependencies to test against. The test phase is made up of two separate testing 
methodologies. The first uses rspec to run a number of unit tests against a locally instantiated server. The 
second instantiates the server in the same manner as PAT, runs analyses against said server, and ensures that it stops 
as expected, using the meta-cli.

For cloud deployments, the two critical artifacts are the docker containers and AMIs. Currently AMI testing is not 
automated, and unlikely to be automated for several reason. The docker containers, however, are extensively tested using 
the same rspec functionality as mentioned above. 

For a pull request to be merged under regular order, all CI tests need to return green: GitHub Actions and AppVeyor 
PR and push. All of these tests write verbose results and logs on failure, which should allow for local reproduction 
of the bug and subsequent fixes. In the case of a failure of the CI infrastructure, please open an issue in the 
repository regarding the failure. 

## Commands to update gems used in PAT manually

To test the impact of upgraded gems on PAT's functionality the currently recommended path is to manually remove and 
recreate the cached set of gems, including compiled binary components. This process is platform specific. Currently 
instructions are only available for OSX, due to complications compiling the binary component of gems with the ruby 
instillation provided in the OpenStudio installer package.

### OSX

```bash
# Change directory to the install location of the Server
cd /Applications/OpenStudio-X.Y.Z/ParametricAnalysisTool.app/Contents/Resources/OpenStudio-server 
rm -rf /gems # Remove the pre-packaged gems
vi server/Gemfile # Edit the Gemfile
rm server/Gemfile.lock # Remove the cached gem specifications
../ruby/bin/ruby ./bin/openstudio_meta install_gems # Reinstall the gems required (including new gems)
chmod -R 777 gems # Modify privileges on the installed gems
```

## Questions?

Please contact @tijcolem, @bball, or @nllong with any question regarding this project. Thanks for you interest!

[coveralls-img]: https://coveralls.io/repos/github/NREL/OpenStudio-server/badge.svg?branch=develop
[coveralls-url]: https://coveralls.io/github/NREL/OpenStudio-server
[gh-img]: https://github.com/nrel/openstudio-server/actions/workflows/openstudio-server-tests.yml/badge.svg?branch=develop
[gh-url]: https://github.com/nrel/openstudio-server/actions
[appveyor-img]: https://ci.appveyor.com/api/projects/status/j7hqgh2p7bae9xn8/branch/dockerize-appveyor?svg=true
[appveyor-url]: https://ci.appveyor.com/project/rHorsey/openstudio-server/branch/dockerize-appveyor


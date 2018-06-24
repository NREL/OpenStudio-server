# CI (continuous integration) testing regime

This folder contains scripts specific to each CI to allow for automated testing and deployment of the project. 
Two platforms are used for testing the server: TravisCI and AppVeyor. This document begins by describing the overall 
strategy of the various testing frameworks, followed by sections on each CI platform.

## Testing strategy

The goals for the testing of OpenStudio Server are to ensure that there are not regressions in packaging or deployment 
of successive versions of the OpenStudio Server code. To do so, we focus around semi-redundant unit and integration 
tests across each deployment mechanism. This requires testing the desktop deployed gem packages on both Windows and OSX 
for packaging with the PAT local server use case, and then in a docker container with the deployed server / AMI use 
case. Finally, we test on vanilla ubuntu, because why not.

### PAT local server use case

To test the PAT use case requires us to first create the library of gems shipped with the PAT application. To do this, 
we run [openstudio_meta's](https://github.com/NREL/OpenStudio-server/blob/develop/bin/openstudio_meta) `install_gems` 
command to build the package of gems and pre-compile all assets. Included is the `--with_test_develop` flag, to ensure 
rspec and other testing libraries are included. We next need to test the packages in two contexts. The first is 
integration tests. These focus on exercising the package in the same end-to-end manner as in deployment. This is done 
using the `start_local`, `run_analysis`, and `stop_local` commands. Secondly, unit tests are run using the rspec 
framework within the same gem package. This ensures individual methods and features are tested to ensure compliance 
with expectations. Currently, the same gem package is used for both of these tests, even though the gems provided 
through the `--with_test_develop` flag are only needed in the unit test. It would be preferable to instead run the unit 
tests first with the extended set of gems, and then re-create the gem package through running `install_gems` again 
without the additional flag. This would allow for a more realistic integration test environment.

### Docker-based use case

To test the application as deployed via docker new test docker images are required of both 
[`openstudio-server`](https://hub.docker.com/r/hhorsey/openstudio-server/tags/) and [`openstudio-rserve`](https://hub.docker.com/r/hhorsey/openstudio-rserve/tags/). 
The first implicit test is that these two images build. Typically they do. A known issue is that to retrieve Mozilla 
and gecko-driver sourceforge must be queried, which can lead to failures due to its rather dubious availability 
statistics. If the images fail to build, and the end of the build log talks about gecko-driver, mozilla, sourceforge, 
or http(s), try rebuilding the commit. After obtaining new test images the docker-compose.test.yml file is used, with 
the `docker-compose` CLI, to turn on the server and then to run the unit tests on the deployed docker containers. If 
the test is being run against the develop or master branch, then a final deploy step is implemented to build non-test 
images and push them to [DockerHub](https://github.com/NREL/OpenStudio-server/blob/develop/docker/deployment/scripts/deploy_docker.sh). 
Released tags are created from master, and new latest images from develop.

### Pure ubuntu

I don't know quite why we test on pure ubuntu, but we do, and if the tests break there, that's definitely wrong.

## Testing platforms

Tests are run on Travis, Circle, and AppVeyor. A few comments on each.

### Travis

This is currently the projects preferred testing platform. Build stages are not enabled yet, however they should be. We 
test pure ubuntu and OSX on Travis. All scripts live in the travis folder. Green tests are required for both commits 
and PRs, which is to say the commit SHA code has to pass, as well as the merge of the PR, before a PR can be merged 
into develop. Worth noting that travis.org has a hard one hour time-limit for builds, so we can't test our docker-based 
use case on travis until we speed up build time, or switch over to travis.com with its two hour build limit.

### AppVeyor

This is the projects most appreciated testing platform, so long as it doesn't make us write any more powershell. 
Critical scripts are in the appveyor folder. Both powershell and command prompt scripts exist. Green appveyor tests are 
also required for both commit and PR before merges can take place on develop. AppVeyor is exclusively used for Windows 
testing. There are times when the integration test must be retried up to three times before success - the reason for 
this is not clearly understood, however the retry mechanic is implemented and working successfully. 

### Circle

Circle 2.0 presents significant challenges for the docker-deployment use case. As such, the project is still using the 
1.0 circle framework. This has significant limitations. It would be nice to migrate this use case to Travis if at all
possible. Circle 1.0 only supports commit tests. This test must be green before merging to develop. The circle testing 
scripts live implicitly in the [docker-compose testing template](https://github.com/NREL/OpenStudio-server/blob/develop/docker-compose.test.yml) 
in the repo root and in [run-server-tests.sh](https://github.com/NREL/OpenStudio-server/blob/develop/docker/server/run-server-tests.sh) 
in the /docker/server folder.

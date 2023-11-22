OpenStudio Server
=================

Version 3.7.0
-------------
* update Analysis-gem to 1.3.5 in https://github.com/NREL/OpenStudio-server/pull/722
* update Mongo to 6.0.9 in https://github.com/NREL/OpenStudio-server/pull/709
* update Passenger to 6.0.18 in https://github.com/NREL/OpenStudio-server/pull/714
* Fix indicies in Mongo Database in https://github.com/NREL/OpenStudio-server/pull/713
* add XML and MAT files as valid downloadable Report Types https://github.com/NREL/OpenStudio-server/pull/720


Version 3.5.1
-------------
* update urbanopt to 0.9.0
* update OpenStudio to 3.5.1


Version 3.5.0
------------- 
* update mongoid queries in https://github.com/NREL/OpenStudio-server/pull/662
* fix Radar plo in https://github.com/NREL/OpenStudio-server/pull/664
* fix #539 and add significant digit toggle in https://github.com/NREL/OpenStudio-server/pull/658
* update plots with display name choices in https://github.com/NREL/OpenStudio-server/pull/665
* Ubuntu 20.04 in https://github.com/NREL/OpenStudio-server/pull/670
* Sobol and morris fix  in https://github.com/NREL/OpenStudio-server/pull/668
* Uo update in https://github.com/NREL/OpenStudio-server/pull/671
* add URBANopt template OSA for single_run in https://github.com/NREL/OpenStudio-server/pull/672

Version 3.4.0
-------------
* pass in allow_disk_usage to mongoin https://github.com/NREL/OpenStudio-server/pull/642
* Remove references to travis in documentation and fix badges in https://github.com/NREL/OpenStudio-server/pull/646
* update rails for security patches in https://github.com/NREL/OpenStudio-server/pull/647
* update rails for security patchesin https://github.com/NREL/OpenStudio-server/pull/647
* show CLI version on admin page in https://github.com/NREL/OpenStudio-server/pull/655
* Pareto by @brianlball in https://github.com/NREL/OpenStudio-server/pull/657
* fix mongorestore and mongodump commands in https://github.com/NREL/OpenStudio-server/pull/656

Version 3.3.0
-------------
* [#633](https://github.com/NREL/OpenStudio-server/pull/633) - Merge urbanopt/reopt
* [#634](https://github.com/NREL/OpenStudio-server/pull/634) - Fix in.osm not downloadable
* [#635](https://github.com/NREL/OpenStudio-server/pull/635) - Bump puma version for security
* [#636](https://github.com/NREL/OpenStudio-server/pull/636) - Add docker container scanning using Trivy
* [#641](https://github.com/NREL/OpenStudio-server/issues/641) - Fix mongo memory limitation for large sort ops 

Version 3.2.0
-------------
 * [#627](https://github.com/NREL/OpenStudio-server/pull/627)  Update to OpenStudio SDK v3.2.0 and EnergyPlus 9.5
 * [#615](https://github.com/NREL/OpenStudio-server/pull/615) Include optional UrbanOpt
 to run UrbanOpt workflows
 * [$625](https://github.com/NREL/OpenStudio-server/pull/625) Update rails to 6.1.3.1 and ruby to use 2.7.2 along with other core dependency gems.
 * [#617](https://github.com/NREL/OpenStudio-server/pull/617) Move CI from Travis to GitHub actions
 * [#613](https://github.com/NREL/OpenStudio-server/pull/613) Update mongo to 4.4.2 and redis 6.0.9 and allow for optional authetication of mongo and redis.

Version 3.1.0-1
-------------

* #[613](https://github.com/NREL/OpenStudio-server/pull/613/files) Update Mongo and Redis versions and allow for custom password for both Redis and Mongo when launching OpenStudio-server.  


Version 3.1.0
-------------

Date Range 06/26/20 - 10/26/20

* [#555](https://github.com/NREL/OpenStudio-server/pull/555) - Update Ruby gem envs in the openstudio_meta cli  
* [#561](https://github.com/NREL/OpenStudio-server/pull/561) - Fixes [#560](https://github.com/NREL/OpenStudio-server/issues/560) - Fixes unzip method
* [#563](https://github.com/NREL/OpenStudio-server/pull/563) - Add linux support for extracted gems. 
* [#564](https://github.com/NREL/OpenStudio-server/pull/564) - Remove hardcoded openstudio version and sha
* [#566](https://github.com/NREL/OpenStudio-server/pull/566) - Make tmpname deprecate
* [#571](https://github.com/NREL/OpenStudio-server/pull/571) - Make downloading files back to server optional 
* [#602](https://github.com/NREL/OpenStudio-server/pull/602) - Add algorithmic test suites
* [#597](https://github.com/NREL/OpenStudio-server/pull/597) - Save the travis gem package artifacts
* [#599](https://github.com/NREL/OpenStudio-server/pull/599) - Save the windows gem package artifacts
* [#580](https://github.com/NREL/OpenStudio-server/issues/580) - add report capability to PSO 
* [#579](https://github.com/NREL/OpenStudio-server/pull/579) - Update nokogiri
* [#585](https://github.com/NREL/OpenStudio-server/pull/585) - Update docker-compose version
* [#589](https://github.com/NREL/OpenStudio-server/pull/589) - Use most recent rubocop rules


Version 3.0.1
-------------
Date Range 04/28/20 - 06/26/20

* Updated OpenStudio SDK from v3.0.0 to v3.0.1
* Fixed [#561](https://github.com/NREL/OpenStudio-server/issues/561) #561 Fix unzipping issue.


Version 3.0.0
-------------
Date Range 12/9/19 - 04/27/20

* Updated OpenStudio SDK from v2.9.1 to v3.0.0
* Updated EnergyPlus from v9.2.0 to v9.3.0
* Updated Ruby from 2.2.4 to Ruby 2.5.5
* Fixed [#543](https://github.com/NREL/OpenStudio-server/issues/543) Increased the scp timeouts for larger data files.
* Fixed [#537](https://github.com/NREL/OpenStudio-server/issues/537) Added timeout settings as user args


Version 2.9.1
-------------

Date Range 10/11/19 - 12/9/2019

* Fixed [#526](https://github.com/NREL/OpenStudio-server/issues/526) Adding checks for valid CLI options and adding debug flag as optional. 
* Updating to bson 4.50 for MongoDB support


Version 2.9.0
-------------

Date Range 6/5/19 - 10/11/19

* [#483](https://github.com/NREL/OpenStudio-server/issues/483) Added support for develop3 (3.x OpenStudio releases) 
* [#507](https://github.com/NREL/OpenStudio-server/issues/507) Update server/Gemfile to openstudio-analysis 1.0.2 once available develop3 
* [#503](https://github.com/NREL/OpenStudio-server/issues/503) Updated local Linux/OSX testing for 3x


Version 2.8.1
-------------

Date Range 4/13/19 - 6/5/19

* Update AWS Gem
* Added support for pre-releases: both using pre-release versions of OpenStudio and publishing pre-release builds of OpenStudio Server
* Updated handling of environment variables for OpenStudio CLI

Accepted Pull Requests: 8
- Fixed [#472]( https://github.com/NREL/OpenStudio-server/pull/472 ), add rstan and field to R
- Fixed [#473]( https://github.com/NREL/OpenStudio-server/pull/473 ), set up CI to work w/pre-release OpenStudio packages by adding OPENSTUDIO_VERSION_EXT.
- Fixed [#482]( https://github.com/NREL/OpenStudio-server/pull/482 ), Worker Init/Final Log on Datapoint
- Fixed [#484]( https://github.com/NREL/OpenStudio-server/pull/484 ), Copyrights and Set Gem Version Update
- Fixed [#485]( https://github.com/NREL/OpenStudio-server/pull/485 ), rubocop-rspec 1.32.0
- Fixed [#487]( https://github.com/NREL/OpenStudio-server/pull/487 ), Prepare 2.8.1
- Fixed [#488]( https://github.com/NREL/OpenStudio-server/pull/488 ), fix redis to 4.1.0 since 4.1.2 needs ruby 2.3.0
- Fixed [#492]( https://github.com/NREL/OpenStudio-server/pull/492 ), 2.8.1-rc1

Version 2.8.0
-------------
Date Range 11/17/18 - 4/12/19

Closed Issues: 11
- Fixed [#422]( https://github.com/NREL/OpenStudio-server/issues/422 ), Sobol method plots
- Fixed [#425]( https://github.com/NREL/OpenStudio-server/issues/425 ), analysis marked "complete" before finalization scripts run
- Fixed [#437]( https://github.com/NREL/OpenStudio-server/issues/437 ), cancel run does not work anymore
- Fixed [#448]( https://github.com/NREL/OpenStudio-server/issues/448 ), New AWS YML configuration leads to rails & mongo throttling issues
- Fixed [#461]( https://github.com/NREL/OpenStudio-server/issues/461 ), Timed out openstudio processes aren't terminating

Accepted Pull Requests: 14
- Fixed [#442]( https://github.com/NREL/OpenStudio-server/pull/442 ), add param to do out of bounds check for morris
- Fixed [#443]( https://github.com/NREL/OpenStudio-server/pull/443 ), 2.7.1 unexpected return
- Fixed [#447]( https://github.com/NREL/OpenStudio-server/pull/447 ), Hack into analysis status method to return "completed" only when fina…
- Fixed [#450]( https://github.com/NREL/OpenStudio-server/pull/450 ), Dockertag
- Fixed [#451]( https://github.com/NREL/OpenStudio-server/pull/451 ), change limits back to reservations in docker swarm config file
- Fixed [#453]( https://github.com/NREL/OpenStudio-server/pull/453 ), support publishing custom docker image
- Fixed [#454]( https://github.com/NREL/OpenStudio-server/pull/454 ), manage roo and bundler versions
- Fixed [#462]( https://github.com/NREL/OpenStudio-server/pull/462 ), OpenStudio runs in a child of the spawned process. We need to kill bo…
- Fixed [#463]( https://github.com/NREL/OpenStudio-server/pull/463 ), Fix cancel
- Fixed [#465]( https://github.com/NREL/OpenStudio-server/pull/465 ), bump up timeouts until they can be made user selectable
- Fixed [#466]( https://github.com/NREL/OpenStudio-server/pull/466 ), Code cleanup


Version 2.7.1 
-------------

Date Range: 10/16/18 - 11/16/18:

New Issues: 11 (#420, #421, #422, #424, #425, #429, #430, #432, #435, #437, #438)

Closed Issues: 9
- Fixed [#384]( https://github.com/NREL/OpenStudio-server/issues/384 ), logs from finalize and initialize scripts should be accessible via web dashboard
- Fixed [#418]( https://github.com/NREL/OpenStudio-server/issues/418 ), Standardize calls to Oscli
- Fixed [#420]( https://github.com/NREL/OpenStudio-server/issues/420 ), include oscli output with data point log
- Fixed [#421]( https://github.com/NREL/OpenStudio-server/issues/421 ), Need to escape some characters in Oscli calls.
- Fixed [#424]( https://github.com/NREL/OpenStudio-server/issues/424 ), run data point initialization script after worker_initialization
- Fixed [#430]( https://github.com/NREL/OpenStudio-server/issues/430 ), Morris method can create points that dont satisfy boundary
- Fixed [#435]( https://github.com/NREL/OpenStudio-server/issues/435 ), Incomplete datapoints are created causing server hang

Accepted Pull Requests: 11
- Fixed [#423]( https://github.com/NREL/OpenStudio-server/pull/423 ), Check if R libraries install correctly
- Fixed [#426]( https://github.com/NREL/OpenStudio-server/pull/426 ), run data_point initialize scripts only once: at the end of initialize…
- Fixed [#427]( https://github.com/NREL/OpenStudio-server/pull/427 ), Oscli output
- Fixed [#428]( https://github.com/NREL/OpenStudio-server/pull/428 ), function to encapsulate the platform- and config- specific logic for Oscli calls
- Fixed [#431]( https://github.com/NREL/OpenStudio-server/pull/431 ), add boundary checks to make sure solution space is within min/max
- Fixed [#434]( https://github.com/NREL/OpenStudio-server/pull/434 ), Algorithm upgrade
- Fixed [#436]( https://github.com/NREL/OpenStudio-server/pull/436 ), Restclient retry


Version 2.7.0 
-------------

Date Range: 09/05/18 - 10/15/18:

New Issues: 15 (#390, #391, #392, #394, #396, #397, #398, #399, #400, #403, #404, #405, #409, #411, #412)

Closed Issues: 5
- Fixed [#396]( https://github.com/NREL/OpenStudio-server/issues/396 ), print_logs.sh doesn't run on travis/ubuntu
- Fixed [#398]( https://github.com/NREL/OpenStudio-server/issues/398 ), nokogiri error on travis (ubuntu/osx)
- Fixed [#399]( https://github.com/NREL/OpenStudio-server/issues/399 ), supported platforms error on appveyor
- Fixed [#403]( https://github.com/NREL/OpenStudio-server/issues/403 ), Appveyor VMs not failing when unable to discover openstudio.exe
- Fixed [#405]( https://github.com/NREL/OpenStudio-server/issues/405 ), Ensuring openstudio.exe discovery process on Windows is reflected in Appveyor

Accepted Pull Requests: 11

- Fixed [#401]( https://github.com/NREL/OpenStudio-server/pull/401 ), Add require 'openstudio-standards' to measure
- Fixed [#402]( https://github.com/NREL/OpenStudio-server/pull/402 ), remove sudo from install scripts for openstudio and ruby
- Fixed [#410]( https://github.com/NREL/OpenStudio-server/pull/410 ), check OpenStudio Standards version via Oscli.
- Fixed [#413]( https://github.com/NREL/OpenStudio-server/pull/413 ), control sassc version in Gemfile.

Version 2.6.2
-------------

Major Changes: 
- Models are run via the OpenStudio Command Line Interface rather than Workflow Gem.
- OpenStudio gems (bundle) can be customized independent of OpenStudio Server bundle.  See [Wiki](https://github.com/NREL/OpenStudio-server/wiki/Gem-Bundle-used-by-OpenStudio) for additional details.
- Analysis Initialize and Finalize Scripts can be run for Resque-based environments (ie not on local PAT). See [Wiki](https://github.com/NREL/OpenStudio-server/wiki/Analysis-Scripts) for additional details.
- Datapoint Initialize and Finalize Scripts have been restructured and can be run on Resque-based environments. See [Wiki](https://github.com/NREL/OpenStudio-server/wiki/Data-Point-Scripts) for additional details.

Date Range: 08/07/18 - 09/04/18:

New Issues: 3 (#384, #386, #388)

Closed Issues: 4
- Fixed [#248]( https://github.com/NREL/OpenStudio-server/issues/248 ), Implement server & worker init & final scripts
- Improved [#269]( https://github.com/NREL/OpenStudio-server/issues/269 ), Migrate to the openstudio CLI
- Improved [#316]( https://github.com/NREL/OpenStudio-server/issues/316 ), Remove sourceforge build dependency
- Fixed [#378]( https://github.com/NREL/OpenStudio-server/issues/378 ), Unable to run_single when seed value is set

Accepted Pull Requests: 7
- Fixed [#324]( https://github.com/NREL/OpenStudio-server/pull/324 ), OpenStudio CLI
- Fixed [#381]( https://github.com/NREL/OpenStudio-server/pull/381 ), Bundle enablement for Oscli PR
...

Version 2.6.1
-------------

Date Range: 06/24/18 - 08/06/18:

Closed Issues: 3
- Fixed [#333]( https://github.com/NREL/OpenStudio-server/issues/333 ), audit, consolidate & upgrade docker compose files

Accepted Pull Requests: 10
- Fixed [#367]( https://github.com/NREL/OpenStudio-server/pull/367 ), Add version of openstudio to server admin page
- Fixed [#368]( https://github.com/NREL/OpenStudio-server/pull/368 ), ignore gemfile and rvml
- Fixed [#371]( https://github.com/NREL/OpenStudio-server/pull/371 ), add wait-for-it to ensure processes start  in the correct order
- Fixed [#374]( https://github.com/NREL/OpenStudio-server/pull/374 ), replace reservations with limits except for AWS_MONGO_CORES and AWS_W…

Version 2.6.0
-------------

Date Range: 2018-06-14 to 2018-06-24

* Update version of OpenStudio

Version 2.5.2
-------------

Date Range: 2018-06-08 to 2018-06-14

* Fix cursor deleted with accessing /analyses/<id>/analysis_data
* OpenStudio Standards 2.2.
* Set version of mongo and redis for docker deploys

Version 2.5.1
-------------
Version 2.5.0 did not include a changelog, therefore, the list below includes updates to 2.5.0 as well.

Major Changes:
* Backend for Docker deployment now used Resque with Redis instead of delayed jobs.

Date Range: 2018-03-21 to 2018-06-07

Closed Issues: 5
- Improved [#50]( https://github.com/NREL/OpenStudio-server/issues/50 ), Add OpenStudio Server Icon to the place where Icons go in web browsers
- Fixed [#249]( https://github.com/NREL/OpenStudio-server/issues/249 ), Large Uploads to Server (i.e. lots of weather files) Seem to Timeout
- Fixed [#328]( https://github.com/NREL/OpenStudio-server/issues/328 ), Travis test.sh not running unit tests for OSX / test
- Fixed [#329]( https://github.com/NREL/OpenStudio-server/issues/329 ), output from unit tests should be available for appveyor, travis

Accepted Pull Requests: 16
- Fixed [#325]( https://github.com/NREL/OpenStudio-server/pull/325 ), Code cleanup
- Fixed [#327]( https://github.com/NREL/OpenStudio-server/pull/327 ), Updates openstudio-standards to 0.2.1
- Fixed [#334]( https://github.com/NREL/OpenStudio-server/pull/334 ), Added btap download features
- Fixed [#335]( https://github.com/NREL/OpenStudio-server/pull/335 ), Bumping the wfg to 1.3.3
- Fixed [#336]( https://github.com/NREL/OpenStudio-server/pull/336 ), use win_platform?
- Fixed [#338]( https://github.com/NREL/OpenStudio-server/pull/338 ), Pad nrcan 2.4.3
- Fixed [#339]( https://github.com/NREL/OpenStudio-server/pull/339 ), Ci refactor
- Fixed [#341]( https://github.com/NREL/OpenStudio-server/pull/341 ), NRCAN OS-Server[2.5.0] AWS AMI creation: latest tag not found for MongoDB and Redis fix
- Fixed [#343]( https://github.com/NREL/OpenStudio-server/pull/343 ), cleanup deploy script

Version 2.4.3
-------------
The CHANGELOG has not been updated lately. These changes are fixes/updates that have occurred between 01-01-2018 and 03-20-2018.

Closed Issues: 27
- Fixed [#13]( https://github.com/NREL/OpenStudio-server/issues/13 ), data_type vs value_type
- Fixed [#14]( https://github.com/NREL/OpenStudio-server/issues/14 ), enforce unique measure names in analyses
- Fixed [#116]( https://github.com/NREL/OpenStudio-server/issues/116 ), End time and duration of Analysis incorrect
- Fixed [#203]( https://github.com/NREL/OpenStudio-server/issues/203 ), Parallel Coord Filtering Is Bogus
- Fixed [#204]( https://github.com/NREL/OpenStudio-server/issues/204 ), Rgenoud is Not Completing
- Fixed [#205]( https://github.com/NREL/OpenStudio-server/issues/205 ), Pareto Front Calculation Fails
- Fixed [#240]( https://github.com/NREL/OpenStudio-server/issues/240 ), openstudio-server and openstudio-rserve latest tags out of state
- Fixed [#241]( https://github.com/NREL/OpenStudio-server/issues/241 ), OS Server Dies Mid-Analysis
- Fixed [#245]( https://github.com/NREL/OpenStudio-server/issues/245 ), PAT run fails due to mongo validation, starts E+ over and over again
- Fixed [#247]( https://github.com/NREL/OpenStudio-server/issues/247 ), Cancel run from PAT prevents later analyses from starting
- Fixed [#252]( https://github.com/NREL/OpenStudio-server/issues/252 ), PAT RUNS FOR EVER
- Fixed [#256]( https://github.com/NREL/OpenStudio-server/issues/256 ), OS Server hangs at end of analysis
- Fixed [#257]( https://github.com/NREL/OpenStudio-server/issues/257 ), Electricity CVRMSE Limit is not populating correctly in OS Server
- Fixed [#258]( https://github.com/NREL/OpenStudio-server/issues/258 ), Filtered Datapoints Listed Below Parallel Coordinates Plot Are Wrong
- Fixed [#266]( https://github.com/NREL/OpenStudio-server/issues/266 ), openstudio_meta install_gems certificate verify failed for rubygems
- Fixed [#282]( https://github.com/NREL/OpenStudio-server/issues/282 ), Update to bundler version 1.14.4 in openstudio_meta
- Fixed [#308]( https://github.com/NREL/OpenStudio-server/issues/308 ), timeout is too short for large datapoints
- Fixed [#310]( https://github.com/NREL/OpenStudio-server/issues/310 ), nginx file size too small

Accepted Pull Requests: 41
- Fixed [#254]( https://github.com/NREL/OpenStudio-server/pull/254 ), New rubocop syntax
- Fixed [#262]( https://github.com/NREL/OpenStudio-server/pull/262 ), Visualization fixes
- Fixed [#263]( https://github.com/NREL/OpenStudio-server/pull/263 ), Cleanup Test Scripts
- Fixed [#264]( https://github.com/NREL/OpenStudio-server/pull/264 ), Update Copyright / License for 2018
- Fixed [#277]( https://github.com/NREL/OpenStudio-server/pull/277 ), AMI automation script and documentation
- Fixed [#280]( https://github.com/NREL/OpenStudio-server/pull/280 ), Reenable DockerHub release process with new functionality
- Fixed [#281]( https://github.com/NREL/OpenStudio-server/pull/281 ), Updating WFG.
- Fixed [#283]( https://github.com/NREL/OpenStudio-server/pull/283 ), Update bundler installed by openstudio_meta to 1.14.4
- Fixed [#288]( https://github.com/NREL/OpenStudio-server/pull/288 ), parseFloat for cases where numbers are mistakenly sent as strings
- Fixed [#291]( https://github.com/NREL/OpenStudio-server/pull/291 ), Doe
- Fixed [#293]( https://github.com/NREL/OpenStudio-server/pull/293 ), Fix install_gems requirement of rspec and rubocop.
- Fixed [#296]( https://github.com/NREL/OpenStudio-server/pull/296 ), Documentation Update
- Fixed [#297]( https://github.com/NREL/OpenStudio-server/pull/297 ), Fix formatting
- Fixed [#302]( https://github.com/NREL/OpenStudio-server/pull/302 ), add new depenendency to install openstudio 2.4.3
- Fixed [#311]( https://github.com/NREL/OpenStudio-server/pull/311 ), bump datapoint limit to 1000MB
- Fixed [#312]( https://github.com/NREL/OpenStudio-server/pull/312 ), Updates openstudio-standards to 0.2.0.rc2

Version 1.21.16
---------------
* GET data point includes data_point root element.

Version 1.21.15
---------------
* GET analysis know includes analysis root element. 

Version 1.19.1-OS.1.12.6.c58ea292f1
-----------------------------------
* OpenStudio 1.12.6.c58ea292f1

Version 1.19.1-rc5
------------------
* OpenStudio 1.12.2.462ae9e746

Version 2.0.0-PAT Pre-Releases
------------------------------
* Added in a version of the Meta-CLI to the root bin dir to allow for automated packaging, deployment (both local and remote) and analysis submission
* Updated gems to ensure the OpenStudio Analysis Framework can be deployed together through this repo
* Added in tzinfo-data for Windows deployment support
* Requires use of RubyGems version ~>2.5, note that the 2.6 series has a breaking bug for Ruby 2.0
* Using cross-platform-ed delayed_job to manage analysis, backaground, and worker queues
* Hardcoded the Meta-CLI in the root bin dir to use the local server code, allowing for the code to be self-contained

Version 1.19.1-rc3
------------------
* OpenStudio 1.12.1.7d1634ec2e

Version 1.19.1-rc2
------------------
* OpenStudio 1.12.1.7d1634ec2e

Version 1.19.1-rc1
------------------
* OpenStudio 1.12.1.7d1634ec2e

Version 1.19.1-OS-1.12.1.7d1634ec2e
-----------------------------------
* OpenStudio 1.12.1.7d1634ec2e

Version 1.19.0-OS-1.12.0.ef50b89958
-----------------------------------
* OpenStudio 1.12.0.ef50b89958

Version 1.18.1-OS-1.11.6.28148a307b
-----------------------------------
* OpenStudio 1.11.6.28148a307b

Version 1.16.0-OS-1.11.5.458a1f041d
-----------------------------------
* OpenStudio 1.11.5.458a1f041d

Version 1.17.0
--------------
* OpenStudio 1.11.4

Version 1.15.20
---------------
* OpenStudio 1.11.3

Version 1.15.18
---------------
* OpenStudio 1.11.2

Version 1.15.17
---------------
* OpenStudio 1.11.1

Version 1.15.15
---------------
* OpenStudio 1.11.0

Version 1.15.7
--------------
* OpenStudio 1.10.6

Version 1.15.5
--------------
* OpenStudio 1.10.5

Version 1.15.4
--------------
* OpenStudio 1.10.4

Version 1.15.3
--------------
* OpenStudio 1.10.3

Version 1.15.2
--------------
* OpenStudio 1.10.2

Version 1.15.0
--------------
* OpenStudio 1.10.0

Version 1.14.10
---------------
* OpenStudio 1.9.5

Version 1.14.6
--------------
* OpenStudio 1.9.4

Version 1.13.5
--------------
* OpenStudio 1.9.3

Version 1.12.14
--------------
* OpenStudio 1.9.2

Version 1.12.13
---------------
* OpenStudio 1.9.1

Version 1.12.9
--------------
* OpenStudio 1.9.0

Version 1.12.7
--------------
* Render JSON and HTML reports from datapoints.
* Add new R libraries for worker nodes. Allow measures to run R scripts.
* OpenStudio 1.8.5

Version 1.12.6
--------------
* OpenStudio 1.8.5

Version 1.12.5
--------------
* OpenStudio 1.8.4

Version 1.12.4
--------------
* OpenStudio 1.8.3

Version 1.12.3
--------------
* OpenStudio 1.8.2

Version 1.12.2
--------------
* OpenStudio 1.8.1

Version 1.12.1
--------------
* OpenStudio 1.8.0

Version 1.12.0
--------------
* Default to using EnergyPlus 8.3.
* OpenStudio 1.7.5

Version 1.11.0-pre1
-------------------
* Remove password-based authentication
* Requires new host file entry of openstudio.server to run R cluster
* Deprecated system_information call in cluster. This will prevent ami_id and instance_id from appearing in the cluster information.
* Add route to download analysis zip
* Worker initialization now downloads the analysis zip instead of the server scp'ing the file over to the worker nodes
* OpenStudio 1.7.1

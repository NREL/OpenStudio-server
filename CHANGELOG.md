OpenStudio Server
=================

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

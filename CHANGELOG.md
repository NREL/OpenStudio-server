OpenStudio Server
=================

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

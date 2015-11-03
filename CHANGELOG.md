OpenStudio Server
==================================

Version 1.12.14
--------------
* OpenStudio 1.9.2

Version 1.12.13
--------------
* OpenStudio 1.9.1

Version 1.12.9
--------------
* OpenStudio 1.9.0

Version 1.12.7
--------------
* Render JSON and HTML reports from data points.
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
OpenStudio Server
==================================

Version 1.11.0-pre1
-------------------
* Remove password-based authentication
* Requires new host file energy of openstudio.server to run R cluster
* Deprecated system_information call in cluster. This will prevent ami_id and instance_id from appearing in the cluster information.
* Add route to download analysis zip
* Worker initialization now downloads the analysis zip instead of the server scp'ing the file over to the worker nodes
* OpenStudio 1.7.1
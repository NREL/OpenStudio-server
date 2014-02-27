# Worker Node Readme

This lib directory is to store all the files that need to be pushed to any worker node that is created.  Note that all files in this directory will be copied over.  During provision, this folder is mounted as /data/worker_nodes, but in the future that may not be the case, plus, the server should be self contained including the logic to spin up any other worker node.
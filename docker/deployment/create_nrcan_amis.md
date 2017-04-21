# Creating a new image for standards work.
Requirements: 
* BTAP-Developement-Environment https://github.com/canmet-energy/btap-development-environment
* Amazon Account AWS_ACCESS_KEY and AWS_SECRET_KEY (You can obtain this from your Amazon Account or from your Amazon organization admin..see here https://aws.amazon.com/blogs/security/wheres-my-secret-access-key/)

## 1. Download OpenStudio-server branch
Download our branch of the openstudio-server and enter that directory. In the case of nrcan....
``bash
git clone https://github.com/NREL/OpenStudio-server.git -b nrcan &&
cd OpenStudio-server
``
## 2. Merge to the SHA version that the most recent docker hub was created into nrcan branch. 
Find the most recent SHA. Have a look at this json file http://s3.amazonaws.com/openstudio-resources/server/api/v3/amis.json, look for the most recent version and find the SHA. 
For example, version 2.1.1 you will find the SHA ref to be **079c2b89bd41126f3a6d364df257c26c4add8b27**. Merge those changes and push them to the repository.  
``bash
git merge <most_recent-sha> &&
git push
``
Then go to https://circleci.com/gh/NREL/OpenStudio-server and wait for the nrcan branch to finish building successfully.

## 3. Merge to nrcan branch into the nrcan-master branch.
These commands will switch to the nrcan-master branch, merge the nrcan branch and push to git, which will also start the circle-ci build.  
``bash
git checkout nrcan-master &&
git merge nrcan &&
git push
``
Then go to https://circleci.com/gh/NREL/OpenStudio-server and wait for the nrcan-master branch to finish building successfully

## 4.Create Amazon AMI
Now once the build is complete, you will see it listed on DockerHub here https://hub.docker.com/r/nrel/openstudio-server/tags.  You now need to create the image on Amazon for others to use. Go into your OpenStudio-server/docker/deployment folder. Open the file user_variables.json.template in an editor. Change the "version" and "openstudio_server_base_version" to the same name to reflect the version of Openstudio.  

So your file may look like this if your version of OS was 2.1.1
``
{
  "version": "2.1.1-nrcan",
  "docker_machine_version": "1.13.0",
  "docker_compose_version": "1.10.0",
  "openstudio_server_base_version": "2.1.1-nrcan",
  "generated_by": "Phylroy Lopez NRCan"
}
``
Save this file as **user_variables.json** in the deployment folder. 

## 5.Creating the Amazon AMI
Set you Amazon creditials in your environmenr if you have not already. 
``
	export AWS_ACCESS_KEY=<your access key> &&
	export AWS_SECRET_KEY=<your secret key>
``

Run packer to create the AMI from the OpenStudio-server/docker/deployment
``
	packer build --var-file=user_variables.json openstudio_server_docker_base.json
``

Wait about 30mins until it completes. Then take note of the AMI name and sha that were created.
## 6.Get the AMI ID
You should see some text like this with your version, yours may differ slightly. The ami-xxxxxxxx is your ami id. 
``
==> amazon-ebs: Creating the AMI: OpenStudio-Server-Docker-2.1.1-nrcan
    amazon-ebs: AMI: ami-f8ae3cee
``

## 7.Get the revision number of the nrcan-master
Enter this command to get the currrent SHA of nrcan-master. Copy this down somewhere as well. 
``
	git rev-parse HEAD
``
## 8.Send JSON data for NREL to update. 
Switch to the nrcan branch. 
``
git checkout nrcan
``
Examine the http://s3.amazonaws.com/openstudio-resources/server/api/v3/amis.json file determine the most recent version, use that as a basis and change only the name: , the server:ref: and the ami: values. 

So change the three lines below from this...
``
    {
      "name": "2.1.1",
      "standards": {
        "ref": "0.1.13",
        "repo": "nrel/openstudio-standards"
      },
      "workflow": {
        "ref": "1.2.2",
        "repo": "nrel/openstudio-workflow-gem"
      },
      "energyplus": "8.7",
      "radiance": "5.0.a.12",
      "analysis": {
        "ref": "1.0.0.rc18",
        "repo": "nrel/openstudio-analysis-gem"
      },
      "openstudio": {
        "version_number": "2.1.1",
        "version_sha": "141d4b9cb6",
        "url_base": "https://s3.amazonaws.com/openstudio-builds/NUMBER/OpenStudio-NUMBER.SHA-Linux.deb"
      },
      "server": {
        "ref": "079c2b89bd41126f3a6d364df257c26c4add8b27",
        "repo": "nrel/openstudio-server"
      },
      "R": "3.2.3",
      "ami": "ami-01ff6317"
    }
``
 to this
``
     {
      "name": "2.1.1-nrcan",
      "standards": {
        "ref": "0.1.13",
        "repo": "nrel/openstudio-standards"
      },
      "workflow": {
        "ref": "1.2.2",
        "repo": "nrel/openstudio-workflow-gem"
      },
      "energyplus": "8.7",
      "radiance": "5.0.a.12",
      "analysis": {
        "ref": "1.0.0.rc18",
        "repo": "nrel/openstudio-analysis-gem"
      },
      "openstudio": {
        "version_number": "2.1.1",
        "version_sha": "141d4b9cb6",
        "url_base": "https://s3.amazonaws.com/openstudio-builds/NUMBER/OpenStudio-NUMBER.SHA-Linux.deb"
      },
      "server": {
        "ref": "<the revision sha from step 5>",
        "repo": "nrel/openstudio-server"
      },
      "R": "3.2.3",
      "ami": "ami-<the new ami from step 5>"
    }
``

You can add it to the nrcan-amis.json and commit it the nrcan branch.  Then send the link to henry.horsey@nrel.gov to update the json file that PAT and OS Spreadsheet use. 

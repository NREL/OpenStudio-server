# Automation scripts for CI

Currently, the only automation process for the OpenStudio Server repository that is being migrated to an Internal CI is 
Amazon Machine Image (AMI) generation for commits to the master branch of the repository. This script, however, can 
also be used to create custom one-off AMIs. This README begins by defining requirements for running the AMI generation 
script, followed by specification of the script user interface. The process for official AMI releases is the specified,
followed by the recommended process for one-off releases. 

## AMI generation requirements

To execute the AMI automation script `build_deploy_ami.py` in this folder several software dependencies are required. 
Please note that this script was written for execution on Ubuntu 17.04. First, docker version 17.09.01-ce is required. 
Notes for installing this are available on [the wiki](http://github.com/NREL/OpenStudio-server/wiki/User-OpenStudio-Server-Deployment). 
Next, [packer](http://www.packer.io/) version 1.1.3 or later is required. Finally, python version Python 3.6.3 or 
later is required, as well as the python extension pip. To ensure that docker, packer, and python are available, 
please run the following in a bourne-again shell.

```bash
$ docker --version

Docker version 17.12.0-ce, build c97c6d6

$ packer --version

1.1.3

$ python --version

Python 3.6.3
```

Once the above dependencies are installed, please execute the following command in a bash shell in this folder.

```bash
$ pip install -r requirements.txt

Collecting boto3 (from -r requirements.txt (line 1))
  Downloading boto3-1.5.31-py2.py3-none-any.whl (128kB)
    100% |████████████████████████████████| 133kB 1.5MB/s
Collecting s3transfer<0.2.0,>=0.1.10 (from boto3->-r requirements.txt (line 1))
<output omitted>
Successfully installed boto3-1.5.31 botocore-1.8.45 docutils-0.14 futures-3.2.0 jmespath-0.9.3 python-dateutil-2.6.1 s3transfer-0.1.13 six-1.11.0

$ pip list

boto3 (1.5.31)
botocore (1.8.45)
docutils (0.14)
futures (3.2.0)
jmespath (0.9.3)
pip (9.0.1)
python-dateutil (2.6.1)
s3transfer (0.1.13)
setuptools (38.5.1)
six (1.11.0)
wheel (0.30.0)
```

## AMI generation script

Please ensure all packages listed are not older than those listed above. When installing against a clean python build,
this should not present an issue. At this point, the only remaining dependency is an access key and secret key for the
appropriate aws account. If you don't know what these are and are trying to make official releases, you probably 
should not have them, but feel free to ask. If you are trying to make a one-off release, please create an AWS account 
and retrieve an access and secret key for the EC2 service. In this example, the fake access key will be 
`ABCDEFABCDEFABCDEF` and the fake secret key will be `!1qa@2ws#3ed$4rf%5tg^6yh&7uj*8ik(9ol)0p;`. The automated AMI 
generation command is documented in the shell as follows.

```bash
$ python build_deploy_ami.py -h

usage: build_deploy_ami.py [-h] [-o OUTPUT_DIR] [-n NOTES] [-v]
                           [--generated_by GENERATED_BY]
                           [--docker_version DOCKER_VERSION]
                           [--ami_version AMI_VERSION]
                           [--ami_extension AMI_EXTENSION]
                           [--dockerhub_repo DOCKERHUB_REPO] [--write_json]
                           [--disable_public] [--enable_custom_build]

optional arguments:
  -h, --help            show this help message and exit
  -o OUTPUT_DIR, --output_dir OUTPUT_DIR
                        Absolute path to the directory to write the output log
                        to
  -n NOTES, --notes NOTES
                        Provide notes to be persisted in the amis.json entry
  -v, --verbose         Verbose output
  --generated_by GENERATED_BY
                        Set the Author metadata field
  --docker_version DOCKER_VERSION
                        Overwrite the docker version in the AMI
  --ami_version AMI_VERSION
                        Overwrite the AMI version
  --ami_extension AMI_EXTENSION
                        Overwrite the AMI version extension
  --dockerhub_repo DOCKERHUB_REPO
                        Release from a non-NREL DockerHub repository
  --write_json          Write AMI JSON specification to file instead of S3
  --disable_public      Do not make the AMI public
  --enable_custom_build
                        Flag to allow non-standard AMI release
```

For official release use, the only flags used are `-v` to enable verbose outputs (useful in the logs should things go 
awry), `-o` to allow for the log of the `packer` build process to be stored as an artefact in case of automation 
failure, and `-n` to provide provenance information to consumers of the AMI. Currently, the preferred text in notes is 
`Official automated release of OpenStudio Server X.Y.Z by NREL`. To use other flags, the `--enable_custom_build` flag 
must additionally be passed, to signal the users recognition that they are not following the standard release process 
for AMIs.

The below is an example of executing this script.

```bash
$ export AWS_ACCESS_KEY_ID=ABCDEFABCDEFABCDEF

$ export AWS_SECRET_ACCESS_KEY=!1qa@2ws#3ed$4rf%5tg^6yh&7uj*8ik(9ol)0p;

$ python build_deploy_ami.py -o /Path/to/log/artifact/ -n "Official automated release of OpenStudio Server 2.4.1 by NREL" -v

OSS version retrieval command is: ruby -r /Path/to/openstudio-server/server/lib/openstudio_server/version.rb -e "puts OpenstudioServer::VERSION"
OSS version retrieved is 2.4.1

OSS version extension retrieval command is: ruby -r /Path/to/openstudio-server/server/lib/openstudio_server/version.rb -e "puts OpenstudioServer::VERSION_EXT"
OSS version extension retrieved is

Packer command is: packer build -machine-readable -var-file=user_variables.json openstudio_server_docker_base.json 2>&1 | tee /Path/to/log/artifact/build.log
<remaining output omitted>
```

## Build process for official release

This script should only ever be run after the successful completion of a build of the master branch of this repo on 
[TravisCI](https://travis-ci.org/NREL/OpenStudio-server). This automatically pushes tested docker images to 
[DockerHub](http://hub.docker.com/r/nrel) for both the [OpenStudio Server](http://hub.docker.com/r/nrel/openstudio-server/tags/) 
and [OpenStudio Rserve](http://hub.docker.com/r/nrel/openstudio-rserve/tags/) images. These two images are what is 
provisioned within the AMI built, and as such have to be created as DockerHub artefacts beforehand. For the purposes of
automation, however, a successful TravisCI build on the master branch is sufficient for executing the 
`build_deploy_ami.py` script.

This script begins by collecting version information from the repository. This requires the cloned repository to have 
the same SHA as the successful TravisCI build, i.e. latest master. This information, along with the AWS access and 
secret keys, is used to execute packer. Packer spins up a small (c3.xlarge) server from a base Ubuntu AMI. This server
then is configured based off of the [packer JSON file](http://github.com/NREL/OpenStudio-server/blob/develop/docker/deployment/openstudio_server_docker_base.json). 
The log file of this process is written to the output directory as `build.log` and should be persisted in case of a 
failure. Upon successful completion of this command, the configured server will be persisted as an AMI before being
terminated. 

Following the generation of the AMI, the only remaining tasks are to make the AMI public, and to update the 
[amis.json](http://s3.amazonaws.com/openstudio-resources/server/api/v3/amis.json) file stored on S3 that defines the
available set of AMIs. To ensure the accuracy of all information, the individual docker images used the the AMI are 
retrieved from DockerHub and commands executed to determine software versions. Upon completion of these steps, the 
amis.json file is updated on S3. 

## Build process for one-off release

The first step in building a one-off AMI is ensuring that the `openstudio-server` and `openstudio-rserve` containers 
that should be deployed are publicly available on a [DockerHub](http://hub.docker.com) repository. This repository does
not [need to be the official NREL repository](http://hub.docker.com/r/hhorsey/openstudio-server/tags/) however it does
need to be available publicly. For this example, we will use the `2.3.0-test1` tag from `hhorsey`'s 
[openstudio-server](http://hub.docker.com/r/hhorsey/openstudio-server/tags/) and [openstudio-rserve](http://hub.docker.com/r/hhorsey/openstudio-rserve/tags/) 
DockerHub repositories. In addition, we assume that the account creating this build is not the official NREL AMI release
account, and as such cannot alter the amis.json file persisted to S3. Instead, the JSON document specifying the AMI will 
be persisted as `amis_extension.json`. The command for this situation would be as follows.

```bash
$ export AWS_ACCESS_KEY_ID=ABCDEFABCDEFABCDEF

$ export AWS_SECRET_ACCESS_KEY=!1qa@2ws#3ed$4rf%5tg^6yh&7uj*8ik(9ol)0p;

$ python build_deploy_ami.py -o /Path/to/artifacts/ -n 'Test release of the 2.3.0-test1 tagged docker images from the hhorsey dockerhub repository.' -v --generated_by 'README Author' --ami_version '2.3.0' --ami_extension 'test1' --dockerhub_repo 'hhorsey' --write_json --enable_custom_build

<output omitted>
```

### Additional options

`--docker_version` allows for custom docker version releases to be specified other than the default. This allows for newdocker releases to be tested, and old releases specified for customization of legacy AMIs.

`--disable_public` disables the code which sets the generated AMI's availability status to public. This can be reversed at a later date through the AWS web console, or by executing the disabled code in an interactive python terminal.

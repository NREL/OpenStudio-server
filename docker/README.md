# Development with Docker

* [Install Docker Toolbox](https://www.docker.com/products/docker-toolbox). This installs Docker, Docker-Machine, and Docker-Compose

## Create Docker-Machine Image
If using Docker on Windows with VirtualBox then make sure to create a larger volume (e.g. 100GB) for development with 
more memory and cores (if possible)


```
docker-machine create --virtualbox-disk-size 100000 --virtualbox-cpu-count 4 --virtualbox-memory 4096 -d virtualbox dev
```

## Start Docker-Machine Image
```
docker-machine start dev  # if not already running
eval $(docker-machine env dev)
```

## Run Docker Compose 
```
docker-compose build
```
... [be patient](https://www.youtube.com/watch?v=f4hkPn0Un_Q) ... If the containers build successfully, then start the containers

``` 
docker-compose rm -f
docker volume rm osdata
docker volume create --name=osdata
docker-compose up
```

## Testing

```
docker volume create --name=osdata
export RAILS_ENV=docker-test
export CI=true
export CIRCLECI=true
docker-compose -f docker-compose.test.yml build
docker-compose -f docker-compose.test.yml run -d rserve
docker-compose -f docker-compose.test.yml run -d web-background
docker-compose -f docker-compose.test.yml run -d db
mkdir -p reports/rspec
docker-compose -f docker-compose.test.yml run web
```

#### You're done ####
Get the Docker IP address (`docker-machine ip dev`) and point your browser at [http://`ip-address`:8000](http://`ip-address`:8000)


# Deploying with Docker Machine

## Installation

* Install Docker-Machine
    * *Windows*: [Install Docker Toolbox](https://www.docker.com/products/docker-toolbox)
    * *OSX*: [Install Docker for Mac](https://docs.docker.com/docker-for-mac/) 
    
## Configuration

## AWS

* If there is a firewall between your computer and AWS, then allow `port 2376` communication between the two. 
(This type of firewall is commonly seen in large companies with IT departments).
* Create a new VPC to house the analysis containers
    * Log in to AWS Console
    * From dashboard, select *VPC*
    * Select *Start VPC Wizard* for the quickest setup
    * Select *VPC with Single Public Subnet*
    * Assign *VPC name*, example: OpenStudio-Docker
    * Click *Create VPC*
    * Return to AWS Console
* Determine VPC IDs
    * Log in to AWS Console
    * From dashboard, select *VPC*
    * On the left, click on *Your VPCs*
    * Copy for later use the VPC ID previously created for the analysis (e.g. OpenStudio-Docker's VPC is vpc-e33af1db)
    * On the left, click on *Your Subnets*
    * Copy for later use the subnet id, region, and availability zone (e.g. subnet-24fda94a and us-east-1e)
    [us-east-1 is region, a is availability zone])
* Export AWS keys as environment variables
    * *OSX*
    
        ```
        export AWS_ACCESS_KEY_ID=<your-key>
        export AWS_SECRET_ACCESS_KEY=<your-secret-key>
        ```
    * *Windows*
    
        ```
        set AWS_ACCESS_KEY_ID=<your-key>
        set AWS_SECRET_ACCESS_KEY=<your-secret-key>
        ```
* Checkout OpenStudio-server repo and change to dockerize branch

    ```
    git clone git@github.com:NREL/OpenStudio-server.git
    ```
    
        
## Starting Cluster

* In root of OpenStudio-server checkout (on dockerize branch)
* Determine the save of the machine desired. Best to use http://www.ec2instances.info/ to select an m4.* instance. 
*(NOTE: Do not use T2 instances unless testing connectivity. For analysis use m4.xlarge and greater)*
* Make sure to create a larger root-size for the initial volume as this instance will store the results from the 
simulations.
* `awsdocker` is a user defined field defining the instance of the machine.
* Run the following command replacing your copied vpc, zone, subnet values. Select the best instance-type and Increase the root-size if needed.
       
    ```
    docker-machine create -d amazonec2 \
        --amazonec2-instance-type m4.xlarge \
        --amazonec2-zone e \
        --amazonec2-region us-east-1 \
        --amazonec2-vpc-id vpc-e33af1db \
        --amazonec2-subnet-id subnet-24fda94a \
        --amazonec2-root-size 500 \
        awsdocker
    ```    

* After the instance is running, export the docker environment variables
    * *OSX*
    
        ```
        eval $(docker-machine env awsdocker)
        ```
    * *Windows*
    
        ```
        <tbd>
        ```

* Configure Machine for OpenStudio-server
   
    ```
    docker volume create --name=osdata
    docker-compose -f docker-compose.deploy.yml up
    ```

* **IMPORTANT** If this is the first time running a cluster, then the security group that is automatically created needs
to be updated.
    * In the AWS Console, select *EC2*
    * On the left, select *Security Groups*
    * Find and select the docker-machine security group in the correct VPC
    * In the inbound tab on the bottom, click *Edit*
    * Click *Add Rule* and add a *Custom TCP Rule*, *port 8080*, from *Anywhere*.
    * Optional: It is possible to tighten the security here if desired (e.g. allow access from *My IP*). 

### Docker-Swarm
If there is a need for more that 32 cores connected in a cluster, then use Docker-Swarm. Instructions to follow.

## Running an Analysis

* Copy for later use the IP

    The command below returns the IP address. Note that the server is running on port 8080. 

    ```
    docker-machine ip awsdocker
    ```

* See instructions on running analysis from the [OpenStudio Analysis Spreadsheet repo](https://github.com/NREL/OpenStudio-analysis-spreadsheet#running-analyses)
under the *Pre-configured cluster from external source* section.

## Inspection

* Viewing logs
    
    Use `-f` to follow the logs

    ```
    docker-compose logs -f
    ```
* Logging into Docker instance

    *Note that everything is in Docker, so inspection is a bit harder*
    
    ```
    cd ~/.docker/machine/machines/awsdocker
    ssh -i id_rsa ubuntu@54.197.129.12
    ```

    



# Docker, Docker Machine, and Docker Compose

* [Install Docker](https://docs.docker.com/installation/)
* [Install Docker-Machine](https://docs.docker.com/machine/install-machine/)
* [Install Docker-Compose](https://docs.docker.com/compose/install/)

## Create Docker-Machine Image
The command below will create a 100GB volume for development. This is a very large volume and can be adjusted. Make sure to create a volume greater than 30GB.

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
docker-compose up
```

**Note that you may need to build the containers a couple times for everything to converge**

#### You're done!!! ####
Get the Docker IP address (`docker-machine ip dev`) and point your browser at [http://`ip-address`:8000](http://`ip-address`:8000)

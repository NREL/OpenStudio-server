# Docker, Docker Machine, and Docker Compose

* [Install Docker Toolbox](https://www.docker.com/products/docker-toolbox). This installs Docker, Docker-Machine, and Docker-Compose

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
docker-compose rm -f
docker volume rm osdata
docker volume create --name=osdata
docker-compose up
```

**Note that you may need to build the containers a couple times for everything to converge**

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

#### You're done!!! ####
Get the Docker IP address (`docker-machine ip dev`) and point your browser at [http://`ip-address`:8000](http://`ip-address`:8000)

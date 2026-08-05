#prepration
docker volume create --name=osdata
docker volume create --name=dbdata

#start the oss
docker compose -f docker-compose.yml up --scale worker=8

#cleanup if you finished the work
docker container rm -f $(docker container ls -aq)
docker volume rm dbdata osdata -f
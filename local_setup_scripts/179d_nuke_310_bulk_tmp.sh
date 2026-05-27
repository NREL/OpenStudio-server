#!/usr/bin/env bash
# Robust bulk redeploy script (debug-enabled)
set -euxo pipefail
LOG="/tmp/179d_nuke_310_bulk_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "=== OpenStudio bulk redeploy start (OS version: ${1:-unknown}) ==="

# Cleanup existing stack
docker stack rm osserver || true
docker service rm $(docker service ls -q) || true
docker swarm leave -f || true

echo "Removing all containers…"
docker rm -f $(docker ps -aq) || true

echo "Removing all volumes…"
docker volume rm $(docker volume ls -q) || true

echo "Removing all images…"
docker image rm -f $(docker image ls -aq) || true

echo "Cleaning DB data directory…"
rm -rf /data/dbdata/*

# Pull required images
echo "Pulling base images…"
docker pull registry:2.6
docker pull nrel/openstudio-server:3.10.0-bulk
docker pull nrel/openstudio-rserve:3.10.0-pandas
docker pull mongo:6.0.7
docker pull redis:6.0.9

# Initialise local registry
echo "Creating local registry volume…"
docker volume create --name=regdata || true

echo "Initialising Docker Swarm (if not already)…"
docker swarm init || true

echo "Starting local registry service…"
# Correct registry service creation – name, publish, mount, and image
docker service create \
  --name registry \
  --publish 5000:5000 \
  --mount type=volume,source=regdata,destination=/var/lib/registry \
  registry:2.6 || true

# Give registry a moment to start
sleep 10

# Tag and push images to the local registry
echo "Tagging images for local registry…"
docker tag nrel/openstudio-server:3.10.0-bulk 127.0.0.1:5000/openstudio-server
docker tag nrel/openstudio-rserve:3.10.0-pandas 127.0.0.1:5000/openstudio-rserve
docker tag mongo:6.0.7 127.0.0.1:5000/mongo
docker tag redis:6.0.9 127.0.0.1:5000/redis

echo "Pushing images to local registry…"
docker push 127.0.0.1:5000/openstudio-server
docker push 127.0.0.1:5000/openstudio-rserve
docker push 127.0.0.1:5000/mongo
docker push 127.0.0.1:5000/redis

# Deploy the stack
echo "Deploying OpenStudio stack…"
docker stack deploy osserver --compose-file=docker-compose.yml

# Wait for core services to become healthy (adjust list as needed)
EXPECTED_SERVICES=("osserver_db" "osserver_web" "osserver_worker" "osserver_rserve")
for svc in "${EXPECTED_SERVICES[@]}"; do
  echo "Waiting for $svc to be ready…"
  while ! docker service ls --filter name="$svc" --format '{{.Replicas}}' | grep -q '^1/1'; do
    sleep 3
done
  echo "$svc is healthy"
done

# Simple TCP check for the public port (80)
echo "Waiting for port 80 to accept connections…"
until nc -z 127.0.0.1 80; do
  echo "Port 80 not ready – sleeping 5s"
  sleep 5
done

echo "Port 80 is now reachable"

# Ensure worker service exists before scaling
echo "Ensuring osserver_worker service exists before scaling…"
while ! docker service ls --filter name=osserver_worker --format '{{.Name}}' | grep -q osserver_worker; do
  echo "Worker service not yet present – sleeping 2s"
  sleep 2
done

echo "Scaling worker service to 106 replicas…"
docker service scale osserver_worker=106

echo "=== OpenStudio bulk redeploy completed successfully ==="

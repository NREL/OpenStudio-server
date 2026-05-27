#!/usr/bin/env bash
# Fixed bulk redeploy script – ensures node is a manager and adds timeout
set -euxo pipefail

LOG="/tmp/179d_nuke_310_bulk_fixed_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

echo "=== OpenStudio bulk redeploy start (OS version: ${1:-unknown}) ==="

# Cleanup existing stack
docker stack rm osserver || true
docker service rm $(docker service ls -q) || true
# Ensure we leave any existing swarm first
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

echo "Initialising Docker Swarm as manager…"
# Force a new cluster to guarantee manager role
docker swarm init --force-new-cluster || true
# Promote any node to manager (id may be empty if already manager)
NODE_ID=$(docker node ls -q | head -n1 || true)
if [ -n "$NODE_ID" ]; then
  docker node update --role manager "$NODE_ID" || true
fi

echo "Starting local registry service…"
docker service create \
  --name registry \
  --publish 5000:5000 \
  --mount type=volume,source=regdata,destination=/var/lib/registry \
  registry:2.6 || true

sleep 10

# Tag & push images to local registry
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

# Helper function to wait for a service with timeout
wait_service() {
  local name="$1"
  local timeout_secs=300   # 5 minutes
  local elapsed=0
  echo "Waiting for $name to reach 1/1 replicas (max $timeout_secs secs)…"
  while true; do
    replicas=$(docker service ls --filter name="$name" --format '{{.Replicas}}' | grep -q '^1/1' && echo ok || echo not)
    if [ "$replicas" = "ok" ]; then
      echo "$name is healthy"
      break
    fi
    sleep 3
    elapsed=$((elapsed+3))
    if [ $elapsed -ge $timeout_secs ]; then
      echo "ERROR: $name did not become ready within $timeout_secs seconds"
      exit 1
    fi
  done
}

# Wait for core services (adjust list as needed)
for svc in osserver_db osserver_web osserver_worker osserver_rserve; do
  wait_service "$svc"
done

# Simple TCP check for port 80
echo "Waiting for port 80 to accept connections…"
for i in {1..60}; do
  if nc -z 127.0.0.1 80; then
    echo "Port 80 is reachable"
    break
  fi
  sleep 5
done

# Ensure worker service exists before scaling (already waited above)
echo "Scaling worker service to 106 replicas…"
docker service scale osserver_worker=106

echo "=== OpenStudio bulk redeploy completed successfully ==="

# Network setup for Vagrant Boxes

## Server Configuration

- Log into 192.168.33.10 either via `vagrant ssh` or putty.

```sh
cd /data/launch-instance
./configure_vagrant_server.sh
```

- check that Rserve is running

```sh
ps -A | grep Rserve
```

- if no Rserve is running then start it by

```sh
sudo /etc/init.d/Rserved
```

## Worker Configuration

- Log into 192.168.33.11 either via `vagrant ssh` or putty.

```sh
cd /data/launch-instance
./configure_vagrant_server.sh
```


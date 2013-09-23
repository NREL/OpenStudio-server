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
sudo service Rserved start
```

## Worker Configuration

- Log into 192.168.33.11 either via `vagrant ssh` or putty.

```sh
cd /data/launch-instance
./configure_vagrant_worker.sh
```

## Logging Information

- Rserve - /var/log/Rserve.log (print messages in R commands)
- delayed_jobs - /var/www/rails/openstudio/log/delayed_jobs.log
- apache 
  + /var/log/apache2/error.log (http errors like malformed urls)
  + /var/log/apache2/access.log (ip address, client)
- rails - /var/www/rails/openstudio/log/development.log (rails stack)

# Network setup for Vagrant Boxes

## Server Configuration

- Log into 192.168.33.10 either via `vagrant ssh` or putty.

```sh
/data/launch-instance/configure_vagrant_server.sh
```

- check that Rserve is running

```sh
ps -A | grep Rserve
```

- if no Rserve is running then start it by

```sh
sudo service Rserved start
```

- start or restart delayed_job

```sh
cd /var/www/rails/openstudio
sudo ./script/delayed_job restart
```

## Worker Configuration

- Log into 192.168.33.11 either via `vagrant ssh` or putty.

```sh
/data/launch-instance/configure_vagrant_worker.sh
```

## Logging Information (in order of importance)

- rails - /var/www/rails/openstudio/log/development.log (rails stack)
- Rserve - /var/www/rails/openstudio/Rserve.log (print messages in R commands)
- rails child processes
  + download files - /tmp/download-output.log*
- delayed_jobs - /var/www/rails/openstudio/log/delayed_jobs.log
- apache 
  + /var/log/apache2/error.log (http errors like malformed urls)
  + /var/log/apache2/access.log (ip address, client)


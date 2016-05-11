# OpenStudio Rails Application

## Starting Worker Pools

The server is required to have a running delayed job instances watching
the `analyses` queue. 

```
bin/delayed_job -i server stop && bin/delayed_job -i server --queue=analyses,background start
```

Depending on the resources available on the machine, the worker nodes
can be spun up with the following command. 

```
bin/delayed_job -i worker_1 stop && bin/delayed_job -i worker_1 --queue=simulations start
```

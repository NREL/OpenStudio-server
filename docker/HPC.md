# Docker daemon configuration: HPC edition

## Intro

### Why

Deploying docker in highly constrained environments (like those typically found in managed HPC systems) can present 
unique (in a bad way) problems. This document serves as a knowledge store for how to circumvent / circumscribe around 
known ones.

### What

This page is organized around general classes of issues. Current classes include [GID](#group-based-issues). Please add
additional issues and solutions so others can minimize frustration! In each section problems are described in detail, a
problem presented, and useful resources for others noted. Given that many docker issues are OS-specific (in solution if 
not nature) attaching relevant resources serves as an excellent starting place for others attempting to solve the same 
issue on a different OS.

## [Group based issues](#group-based-issues)

### Group `docker` is already taken on the system

#### Detailed problem

The GID namespace docker is critical for [allowing users to use docker on a managed system without sudo rights](https://docs.docker.com/engine/installation/) 
(click on your system for more information.) Unfortunately, in centrally managed systems the docker GID namespace may 
already be allocated and mannaged through an upstream system. If so, short of finding the setter of the GID namespace 
and adding additional users there are minimal options for running docker without sudo. However, by creating a new group,
adding users to said group, and reconfiguring the docker daemon, it is possible to use a self-defined GID namespace.

#### Solution

The docker daemon is defaulted through the [docker.socket config file](https://github.com/docker/docker/blob/master/contrib/init/systemd/docker.socket) 
in the docker project. The `SocketGroup` config option sets the GID namespace used for non-sudo access to the docker
executable. To override this requires passing additional commands to the [dockerd CLI](https://docs.docker.com/engine/reference/commandline/dockerd/), 
specifically the `-G [groupname]` option. To do so is a system-specific affair, and will almost certainly require sudo
rights to implement. See the [OS-specific instructions](https://docs.docker.com/engine/admin/) for which files to 
override and how.

#### CentOS Example

This makes a new group, osdocker, assigns the current user to it, alters the daemon invocation by systemd, and reloads 
the daemon. The text to go in the `docker.conf` file is:
```bash
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -G osdocker
```
The commands are:
```bash
sudo groupadd osdocker
sudo usermod -aG osdocker ${USER}
sudo mkdir /etc/systemd/system/docker.service.d
sudo vi /etc/systemd/system/docker.service.d/docker.conf
< type above text here >
sudo systemctl daemon-reload
sudo systemctl restart docker
ps aux | grep docker | grep -v grep
```
The last command should verify that `dockerd` is running on the machine.

#### Critical resources

[Highly useful GitHub issue](https://github.com/docker/docker/issues/9889)

[Official OS-specific instructions](https://docs.docker.com/engine/admin/)

[CLI docs for dockerd](https://docs.docker.com/engine/reference/commandline/dockerd/)

[Default docker.socket config file](https://github.com/docker/docker/blob/master/contrib/init/systemd/docker.socket)
#Network setup for Vagrant Boxes

## Instructions

 ssh into server @ 192.168.33.10

- add os-worker to /etc/hosts on os-server
```sh
sudo -i
echo 192.168.33.11 os-worker >> /etc/hosts
exit
sudo service networking restart
```

- create the id_rsa and id_rsa.pub files
```sh
cd ~/.ssh
/usr/bin/ssh-keygen -t rsa
```
Hit return three times

- put id_rsa.pub in the authorized_keys file
```sh
cat id_rsa.pub >> authorized_keys
```

- copy public key to worker node
```sh
/usr/bin/ssh-copy-id vagrant@192.168.33.11
```
If prompted, answer yes.  Enter password vagrant

- test passwordless login
```sh
ssh vagrant@192.168.33.11
```
no password should be required


ssh into worker @ 192.168.33.11

- add os-worker to /etc/hosts on os-server

```sh
sudo -i
echo 192.168.33.10 os-server >> /etc/hosts
exit
sudo service networking restart
```
# SSH material for the Nomad rsync bridge

This directory is bind-mounted read-only into the `web` and `web-background`
containers at `/config/ssh`. Everything in it except this README is
gitignored — never commit keys.

To enable package/results rsync to a Nomad cluster, place here:

- `id_rsync` — private key authorized on the Nomad server
  (e.g. `ssh-keygen -t ed25519 -f external_batch/nomad/ssh/id_rsync`)
- `known_hosts` — optional; `submit_nomad.rb` uses `StrictHostKeyChecking=no`

The container-side default key path is `/config/ssh/id_rsync`
(`submit_nomad.rb --ssh-key` overrides it).

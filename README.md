# omarchy-proxy-control

An Omarchy bar widget for `proxyctl`: switch the system between a direct
connection and the phone HTTP proxy, set how Tor reaches its first relay, ask
for a new Tor identity or rotate it on a timer, and open Tor Browser over the
system Tor.

The widget holds no logic of its own. It reads `proxyctl status --json` every
five seconds and runs `proxyctl` for every action, so `proxyctl` has to be on
the shell's `PATH` (`~/.local/bin`). Actions that need root show the polkit
prompt.

## Install

```bash
ln -s ~/Documents/Code/omarchy-proxy-control ~/.config/omarchy/plugins/sups.proxyctl
omarchy bar put sups.proxyctl --section right
```

## Test

```bash
test/check.sh
```

Runs the model tests (node), `qmllint`, and checks that every `Text` item
renders plain text.

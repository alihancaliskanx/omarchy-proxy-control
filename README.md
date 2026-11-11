# omarchy-proxy-control

An Omarchy bar widget for `proxyctl`: switch the system between a direct
connection and the phone HTTP proxy, set how Tor reaches its first relay, and
ask for a new Tor identity or rotate it on a timer.

The widget holds no logic of its own. It reads `proxyctl status --json` every
five seconds and runs `proxyctl` for every action. Actions that need root show
the polkit prompt.

## Requirements

- [`proxyctl`](https://github.com/alihancaliskanx/dotfiles/blob/omarchy/scripts/.local/bin/proxyctl)
  somewhere on the shell's `PATH`, for example `~/.local/bin`.
- What `proxyctl` uses: `glider`, `nftables`, `tor`, and `corkscrew` or `ncat`
  for the ssh rule; `gum` only for its terminal menu.
- Set the proxy address once: `proxyctl addr host:port`.

## Install

```bash
omarchy plugin add https://github.com/alihancaliskanx/omarchy-proxy-control.git --enable
```

This clones the plugin into `~/.config/omarchy/plugins/sups.proxyctl` and puts
it in the right section of the bar.

To work on it from a clone of your own instead, link the clone into the
plugins directory and enable it:

```bash
ln -s "$PWD" ~/.config/omarchy/plugins/sups.proxyctl
omarchy plugin enable sups.proxyctl
```

Run those two from inside the clone.

## Test

```bash
test/check.sh
```

Runs the model tests (node), `qmllint`, and checks that every `Text` item
renders plain text.

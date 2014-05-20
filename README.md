# GUPnP RUI Server

This serves UPnP RemoteUIs listed in the given config file (see config/config.json for an example).

## Getting Source

    git clone https://github.com/cablelabs/gupnp-rui-server.git
    cd gupnp-rui-server

## Build

    ./build.sh

While developing, it can be useful to leave `tup` running in the background, autocompiling every time anything changes:

    tup monitor -a
    # stop with 'tup stop'

There is also a `clean.sh` script if you need it for some reason, but usually tup will take care of that automatically.

## Run

    ./src/server -c config/config.json

You should now be able to discover the server with your client. Adding `-w` will make the server watch the config file for changes and send UIListingUpdate events when the RUI list changes. You can use `--help` to list all options.

On Fedora, you may need to disable the firewall:

    sudo systemctl stop firewalld

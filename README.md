## Dependencies

On Ubuntu 14.04:

    sudo apt-get install git valac libgupnp-dev libgee-dev libjson-glib-dev

    # tup build tool
    # see: http://gittup.org/tup/
    sudo apt-add-repository 'deb http://ppa.launchpad.net/anatol/tup/ubuntu precise main'
    sudo apt-get update
    sudo apt-get install tup

## Getting Source

    git clone https://github.com/cablelabs/gupnp-rui-server.git
    cd gupnp-rui-server

## Build

    tup init
    tup upd

While developing, it can be useful to leave `tup` running in the background, autocompiling every time anything changes:

    tup monitor -a
    # stop with 'tup stop'

## Run

    ./server --root-device-xml RemoteUIServerDevice1.xml \
        --service-directory src

You should now be able to discover the server with your client.

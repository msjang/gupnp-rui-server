## Dependencies

On Ubuntu 14.04:

    sudo apt-get install valac libgupnp-dev libgee-dev libjson-glib-dev

    # tup build tool
    # see: http://gittup.org/tup/
    sudo apt-add-repository 'deb http://ppa.launchpad.net/anatol/tup/ubuntu precise main'
    sudo apt-get update
    sudo apt-get install tup

## Build

    tup upd

While developing, it can be useful to leave `tup` running in the background, autocompiling every time anything changes:

    tup monitor -a
    # stop with 'tup stop'

## Run

    ./server

The server output will say something like:

> Starting HTTP server on http://localhost:37229

Visit that page in your browser to see the discovered remote UIs.

You can pick the port with the `-p` option:

    ./server -p 8080

> Starting UPnP server on 10.43.0.93:40418
>
> Starting HTTP server on http://localhost:8080

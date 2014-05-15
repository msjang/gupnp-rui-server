#!/bin/bash -e
TUP=tup
TUP_CHECKOUT=deps/.tup-checkout

FEDORA_PACKAGES="gcc vala gupnp-devel libgee-devel json-glib-devel fuse-devel"
UBUNTU_PACKAGES="gcc valac libgupnp-dev libgee-0.8-dev libjson-glib-dev libfuse-dev"

if [ -f /etc/fedora-release ]; then
    for package in $FEDORA_PACKAGES ; do
        if ! rpm -q $package > /dev/null ; then
            echo "Installing packages: $FEDORA_PACKAGES"
            sudo yum install -y $FEDORA_PACKAGES
            break
        fi
    done
elif hash apt-get 2> /dev/null ; then
    for package in $UBUNTU_PACKAGES ; do
        if ! dpkg -s $package > /dev/null 2>&1 ; then
            echo "Installing packages: $UBUNTU_PACKAGES"
            sudo apt-get install -y $UBUNTU_PACKAGES
            break
        fi
    done
else
    echo "Unable to auto-install dependencies. Here's what we need one some distros:"
    echo "On Fedora: sudo yum install $FEDORA_PACKAGES"
    echo "On Ubuntu: sudo apt-get install $UBUNTU_PACKAGES"
fi

git submodule init
git submodule update

# Install tup if it doesn't exist
if ! hash tup 2> /dev/null; then
    TUP=$TUP_CHECKOUT/tup
    if [ ! -f $TUP ] ; then
        if [ ! -d $TUP_CHECKOUT ]; then
            git clone git://github.com/gittup/tup.git $TUP_CHECKOUT
        fi
        cd $TUP_CHECKOUT
        echo $PWD
        ./bootstrap.sh
        cd ../..
    fi
fi

if ! [ -d .tup ]; then
    $TUP init
fi

$TUP upd

echo "Done, now run:"
echo "  ./src/server -c config/config.json"

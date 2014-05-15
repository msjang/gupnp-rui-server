#!/bin/bash
echo "This command will delete everything that's not checked into this repo and its submodules."
read -r -p "Are you sure? [y/N] " response
case $response in
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        exit
        ;;
esac

if ! hash tup 2> /dev/null; then
    if [ -f deps/.tup-checkout/tup ]; then
        deps/.tup-checkout/tup stop
    fi
else
    tup stop
fi

git clean -dxf
git submodule foreach git clean -dxf

echo "Done. You can also remove deps/.tup-checkout if you don't want tup either."

#patch dependency
sed -i 's/libgee-0.8-dev/libgee-dev/g' build.sh
sed -i 's/gee-0.8/gee-1.0/g' src/Tupfile

#sudo apt-get install gcc valac libgupnp-1.0-dev libgee-dev libjson-glib-dev libfuse-dev
#sudo apt-get --reinstall install gir1.2-gssdp-1.0 libgssdp-1.0-3 libgssdp-1.0-dbg libgssdp-1.0-dev gssdp-tools gupnp-vala

#go to src dir
cd src

#create executable via valac
#create c files
valac --ccode config-file-reader.vala main.vala remote-ui.vala server.vala xml-builder.vala --vapidir=./../vapi --pkg=gupnp-1.0 --pkg=gee-1.0 --pkg=gio-2.0 --pkg=posix --pkg=json-glib-1.0

#create obj
LIBs="-L/usr/lib -L/usr/lib/x86_64-linux-gnu -lglib-2.0 -lgupnp-1.0 -lgupnp-av-1.0 -lgssdp-1.0 -ljson-glib-1.0 -lgee"
INCLs="-I/usr/include/libxml2 -I/usr/include/libsoup-2.4 -I/usr/include/gupnp-1.0 -I/usr/include/gupnp-av-1.0/libgupnp-av -I/usr/include/gssdp-1.0 -I/usr/include/glib-2.0 -I/usr/include/gee-1.0 -I/usr/include/json-glib-1.0"
PKGcfg="`pkg-config --cflags --libs glib-2.0`"
gcc main.c -o main.o -c $LIBs $INCLs $PKGcfg
gcc remote-ui.c -o remote-ui.o -c $LIBs $INCLs $PKGcfg
gcc config-file-reader.c -o config-file-reader.o -c $LIBs $INCLs $PKGcfg
gcc server.c -o server.o -c $LIBs $INCLs $PKGcfg
gcc xml-builder.c -o xml-builder.o -c $LIBs $INCLs $PKGcfg

#create executable via gcc
gcc -o serv *.o $LIBs $INCLs $PKGcfg

#describe commands
echo ""
echo "run the below"
echo "src/serv -c config/config.json -i eth0"
echo ""

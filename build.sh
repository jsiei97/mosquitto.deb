#!/bin/bash

base=$PWD

#Make sure we dont have any old debs here...
rm *.deb 

# First part: 
# collect data and create a control file.

pushd mosquitto || exit 2

APP="mosquitto"
#Or some git info...
VER=$(date +'%Y%m%d%H%M')
NUM="1"
ARCH=$(dpkg --print-architecture)

GITUSER=$(git config user.name)
MAIL=$(git config user.email)

NAME=$APP"_"$VER"-"$NUM"_"$ARCH

mkdir -p $base/$NAME/DEBIAN || exit 10
control=$base/$NAME/DEBIAN/control

echo "Package: "$APP        >  $control
echo "Version: "$VER"-"$NUM >> $control
echo "Section: base"        >> $control
echo "Priority: optional"   >> $control
echo "Architecture: "$ARCH  >> $control

echo "Depends: libwebsockets, monit" >>  $control
echo "Maintainer: "$GITUSER" <"$MAIL">" >>  $control

cat >> $control << EOF
Description: Mosquitto is an open source message broker that implements the MQ Telemetry Transport protocol versions 3.1 and 3.1.1.
  deb created for the Funtech House project.
EOF

#Misc git info...
echo "  git describe: "$(git describe --tags)     >> $control
echo "  git log: "$(git log --oneline | head -n1) >> $control

# Second part:
# build it and populate the DEBIAN dir

#Enable websockets
sed -i 's/\(WITH_WEBSOCKETS:=\).*/\1yes/g' config.mk || exit 26

make -j || exit 28
make install prefix=/usr/ DESTDIR=$base/$NAME/ || exit 30

mkdir -p $base/$NAME/etc/monit/conf.d
cp service/monit/mosquitto.monit $base/$NAME/etc/monit/conf.d/ || exit 100


# And the create the package
popd

mkdir -p $NAME/etc/init.d/
cp files/mosquitto.init $NAME/etc/init.d/mosquitto || exit 102

pushd $NAME/etc/mosquitto/ || exit 104
cat > mosquitto.conf << EOF
# Add both normal mqtt on port 1883
# and websockets on port 9001
listener 1883
listener 9001 127.0.0.1
protocol websockets

EOF
cat mosquitto.conf.example >> mosquitto.conf || exit 106
sed -i "s/#user .*/user $USER/g" mosquitto.conf || exit 108
popd


dpkg-deb --build $NAME || exit 40

#And install it...
sudo dpkg -i $NAME.deb || exit 60

# Cleanup
rm -rf $NAME/ || exit 50

echo "Done..."
exit 0

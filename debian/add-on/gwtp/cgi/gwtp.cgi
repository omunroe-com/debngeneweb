#!/bin/sh
#
# Written for Debian package by Christian Perrier <bubulle@debian.org>
#   based on example given in gwtp's README file

GWTP_ETC=/etc/geneweb/gwtp
GENEWEB_DBS=/var/lib/geneweb
LOGDIR=/var/log
TMPDIR=/var/run/gwtp
SITE=http://${SERVER_NAME}:2317/

# /var/run/gwtp no longer provided in the package as /var/run might be 
# a tmpfs, so create the directory if it is not there

[ -d $TMPDIR ] || mkdir $TMPDIR

# set umask for token to be created 666
umask 007
/usr/lib/geneweb/gwtp \
   -etc $GWTP_ETC \
   -dst $GENEWEB_DBS \
   -log /var/log \
   -tmp /var/run/gwtp \
   -site $SITE



	   
	   

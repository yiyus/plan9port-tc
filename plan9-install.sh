#!/bin/sh
#
# -- Jesus Galan (yiyus). 2015

USAGE='Usage: plan9-install.sh [ TARGET ]

Create a plan9.tcz extension from $PLAN9, if available, or from the latest
version in github. In the former case, create also a plan9-local.tcz
extension that loads plan9.tcz when the original $PLAN9 is not found.
If TARGET is specified, install there first, later create plan9-local.tcz
and, if installing from github, plan9.tcz'

: ${TMP:=/tmp/plan9port}
: ${URL:=https://github.com/9fans/plan9port}

P9="/usr/local/plan9"

# Load dependencies
loaddeps() {
	for DEP in "$@"; do
		tce-load -i "$DEP" || tce-load -wi "$DEP" || fatal "loading $DEP"
	done
}

# With wrong arguments or -h, display help and exit
if [ $# = 1 ] && [ "$1" = "-h" ] || [ $# -gt 1 ]; then
	echo "$USAGE" 1>&2
	shift
	exit $#
fi

# Configure
FINAL="$P9"
TARGET="${TMP}"/plan9"${FINAL}"
unset FROMTCZ
[ "$(readlink "$PLAN9"/bin/rc)" == "/tmp/tcloop/plan9${P9}/bin/rc" ] && FROMTCZ=1
if [ $# -eq 1 ]; then
	FINAL="$1"
	TARGET="$1"
elif [ -n "$FROMTCZ" ]; then
	echo "plan9.tcz already loaded, unset PLAN9 to regenerate from $URL"
	exit
fi
# Exit if $PLAN9 does not contain a valid tree
if [ -n "$PLAN9" ] && [ ! -x "$PLAN9"/bin/rc ]; then
	echo 'ERROR: $PLAN9 does not contain a valid tree (rc not found)' 1>&2
	exit 1
fi
mkdir -p "$TMP" "$TARGET"

echo -n "Installing in $TARGET from " 1>&2
[ -n "$PLAN9" ] && echo "$PLAN9" || echo "$URL" 1>&2

# Send everything to the log file, use fatal to exit on error
# stderr will be 3, 1 and 2 go to $TMP/log
exec 3>&1 >"$TMP"/log 2>&1
fatal() {
	MSG="ERROR $1"
	echo "$MSG" 1>&2
	echo "$MSG" 1>&3
	echo "For more info see $TMP/log" 1>&3
	exit 1
}

# mktcz creates a tcz extension from the $TMP directory
# writing stdin to the profile.d file of the extension
mktcz() {
	loaddeps "squashfs-tools"
	TCZ="$1"
	PRD="$TCZ"/etc/profile.d/"$TCZ".sh
	OPT="/etc/sysconfig/tcedir/optional"
	rm -f "$TCZ".tcz
	mkdir -p "$TMP"/"$1"/etc/profile.d \
		 && cat > "${TMP}/${PRD}" \
		 && mksquashfs "$TMP"/"$TCZ" /tmp/"$TCZ".tcz -all-root \
		 && sudo mv /tmp/"$TCZ".tcz "$OPT" || fatal "making $TCZ".tcz
	echo "$1.tcz copied to $OPT" 1>&3
}

# Install and create the packages
if [ -n "$PLAN9" ]; then
	if [ "$TARGET" = "$FINAL" ] || [ -z "$FROMTCZ" ]; then
		cp -LR "$PLAN9"/* "$TARGET" || fatal "copying $PLAN9 to $TARGET"
		( cd "$TARGET"; sudo ./INSTALL -c -r "$FINAL" ) || fatal "$TARGET/INSTALL -c failed"
		PLAN9=""
	fi
	if [ -z "$FROMTCZ" ]; then
		cat <<-EOD | mktcz plan9-local || exit 1
			# Generated by plan9-install
			if [ -x "$PLAN9/bin/rc" ]; then
			    PLAN9="$PLAN9" export PLAN9
			    PATH="\$PATH:\$PLAN9/bin" export PATH
			else
			    tce-load -i plan9 && . /etc/profile.d/plan9
			fi
			EOD
	fi
else
	loaddeps "git" "compiletc" "binutils" "Xorg-7.7-dev"
	# BusyBox ar does not have all the needed options.
	# The one in binutils is fine, but p9p INSTALL sets PATH to /usr/bin
	sudo mv /usr/bin/ar /usr/bin/ar-busybox
	git clone --depth 1 "$URL" "$TARGET" || fatal "cloning $URL"
	( cd "$TARGET"; sudo ./INSTALL -r "$FINAL" ) || fatal "$TARGET/INSTALL failed"
	sudo mv /usr/bin/ar-busybox /usr/bin/ar
	if [ "$TARGET" = "$FINAL" ]; then
		mv "$TMP"/log "$TMP"/log-local
		PLAN9="$TARGET" "$0" 1>&3 2>&3
		exit $?
	fi
fi

# If not running from tcz, build a new plan9.tcz extension
[ -n "$FROMTCZ" ]  && exit
cat <<-EOD | mktcz plan9 "$PLAN9" || exit 1
	# Generated by plan9-install
	PLAN9="$FINAL" export PLAN9
	PATH="\$PATH:\$PLAN9/bin" export PATH
	EOD

# $Id: vos.sh,v 1.0 2001-12-11 09:30:00-05 Green Exp $

# This is a hints file for Stratus VOS, using the POSIX environment
# in VOS 14.4.0 and higher.
#
# VOS POSIX is based on POSIX.1-1996.  It ships with gcc as the standard
# compiler.
#
# Paul Green (Paul.Green@stratus.com)

# C compiler and default options.
cc=gcc
ccflags="-D_BSD_SOURCE -D_POSIX_C_SOURCE=199509L"

# Make command.
make="/system/gnu_library/bin/gmake"

# Architecture name
archname="hppa1.1"

# POSIX commands are here.
# paths="/system/gnu_library/bin"

# Executable suffix.
# No, this is not a typo.  The ".pm" really is the native
# executable suffix in VOS.  Talk about cosmic resonance.
_exe=".pm"

# Object library paths.
loclibpth="/system/stcp/object_library"
loclibpth="$loclibpth /system/stcp/object_library/common"
loclibpth="$loclibpth /system/stcp/object_library/net"
loclibpth="$loclibpth /system/stcp/object_library/socket"
loclibpth="$loclibpth /system/posix_object_library/sysv"
loclibpth="$loclibpth /system/posix_object_library"
loclibpth="$loclibpth /system/c_object_library"
loclibpth="$loclibpth /system/object_library"
glibpth="$loclibpth"

# Include library paths
locincpth="/system/stcp/include_library"
locincpth="$locincpth /system/stcp/include_library/arpa"
locincpth="$locincpth /system/stcp/include_library/net"
locincpth="$locincpth /system/stcp/include_library/netinet"
locincpth="$locincpth /system/stcp/include_library/protocols"
usrinc="/system/include_library"

# Where to install perl5.
prefix=/system/ported/perl5

# Linker is gcc.
ld="gcc"

# No shared libraries.
so="none"

# Don't use nm.
usenm="n"

# Make the default be no large file support.
uselargefiles="n"

# Don't use malloc that comes with perl.
usemymalloc="n"


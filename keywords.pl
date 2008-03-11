#!/usr/bin/perl -w
use strict;

require 'regen_lib.pl';

open(KW, ">keywords.h-new") || die "Can't create keywords.h: $!\n";
binmode KW;
select KW;

print <<EOM;
/* -*- buffer-read-only: t -*-
 *
 *    keywords.h
 *
 *    Copyright (C) 1994, 1995, 1996, 1997, 1999, 2000, 2001, 2002, 2005,
 *    2006, 2007, by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 * !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
 *  This file is built by keywords.pl from its data.  Any changes made here
 *  will be lost!
 */
EOM

# Read & print data.

my $keynum = 0;
while (<DATA>) {
    chop;
    next unless $_;
    next if /^#/;
    my ($keyword) = split;
    print &tab(5, "#define KEY_$keyword"), $keynum++, "\n";
}

print KW "\n/* ex: set ro: */\n";

close KW or die "Error closing keywords.h: $!";

safer_rename("keywords.h-new", "keywords.h");

###########################################################################
sub tab {
    my ($l, $t) = @_;
    $t .= "\t" x ($l - (length($t) + 1) / 8);
    $t;
}
###########################################################################
__END__

NULL
__FILE__
__LINE__
__PACKAGE__
__DATA__
__END__
AUTOLOAD
BEGIN
UNITCHECK
CORE
DESTROY
END
INIT
CHECK
abs
accept
alarm
and
atan2
bind
binmode
bless
break
caller
chdir
chmod
chomp
chop
chown
chr
chroot
close
closedir
cmp
connect
continue
cos
crypt
dbmclose
dbmopen
default
defined
delete
die
do
dump
each
else
elsif
endgrent
endhostent
endnetent
endprotoent
endpwent
endservent
eof
eq
eval
exec
exists
exit
exp
fcntl
fileno
flock
for
foreach
fork
format
formline
ge
getc
getgrent
getgrgid
getgrnam
gethostbyaddr
gethostbyname
gethostent
getlogin
getnetbyaddr
getnetbyname
getnetent
getpeername
getpgrp
getppid
getpriority
getprotobyname
getprotobynumber
getprotoent
getpwent
getpwnam
getpwuid
getservbyname
getservbyport
getservent
getsockname
getsockopt
given
glob
gmtime
goto
grep
gt
hex
if
index
int
ioctl
join
keys
kill
last
lc
lcfirst
le
length
link
listen
local
localtime
lock
log
lstat
lt
m
map
mkdir
msgctl
msgget
msgrcv
msgsnd
my
ne
next
no
not
oct
open
opendir
or
ord
our
pack
package
pipe
pop
pos
print
printf
prototype
push
q
qq
qr
quotemeta
qw
qx
rand
read
readdir
readline
readlink
readpipe
recv
redo
ref
rename
require
reset
return
reverse
rewinddir
rindex
rmdir
s
say
scalar
seek
seekdir
select
semctl
semget
semop
send
setgrent
sethostent
setnetent
setpgrp
setpriority
setprotoent
setpwent
setservent
setsockopt
shift
shmctl
shmget
shmread
shmwrite
shutdown
sin
sleep
socket
socketpair
sort
splice
split
sprintf
sqrt
srand
stat
state
study
sub
substr
symlink
syscall
sysopen
sysread
sysseek
system
syswrite
tell
telldir
tie
tied
time
times
tr
truncate
uc
ucfirst
umask
undef
unless
unlink
unpack
unshift
untie
until
use
utime
values
vec
wait
waitpid
wantarray
warn
when
while
write
x
xor
y

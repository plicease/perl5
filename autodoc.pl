#!/usr/bin/perl -w

require 5.003;	# keep this compatible, an old perl is all we may have before
                # we build the new one

BEGIN {  push @INC, 'lib' }	# glob() below requires File::Glob


#
# See database of global and static function prototypes at the __END__.
# This is used to generate prototype headers under various configurations,
# export symbols lists for different platforms, and macros to provide an
# implicit interpreter context argument.
#

open IN, "embed.fnc" or die $!;

# walk table providing an array of components in each line to
# subroutine, printing the result
sub walk_table (&@) {
    my $function = shift;
    my $filename = shift || '-';
    my $leader = shift;
    my $trailer = shift;
    my $F;
    local *F;
    if (ref $filename) {	# filehandle
	$F = $filename;
    }
    else {
	open F, ">$filename" or die "Can't open $filename: $!";
	$F = \*F;
    }
    print $F $leader if $leader;
    seek IN, 0, 0;		# so we may restart
    while (<IN>) {
	chomp;
	next if /^:/;
	while (s|\\$||) {
	    $_ .= <IN>;
	    chomp;
	}
	my @args;
	if (/^\s*(#|$)/) {
	    @args = $_;
	}
	else {
	    @args = split /\s*\|\s*/, $_;
	}
	print $F $function->(@args);
    }
    print $F $trailer if $trailer;
    close $F unless ref $filename;
}

my %apidocs;
my %gutsdocs;
my %docfuncs;

my $curheader = "Unknown section";

sub autodoc ($$) { # parse a file and extract documentation info
    my($fh,$file) = @_;
    my($in, $doc, $line);
FUNC:
    while (defined($in = <$fh>)) {
        if ($in=~ /^=head1 (.*)/) {
            $curheader = $1;
            next FUNC;
        }
	$line++;
	if ($in =~ /^=for\s+apidoc\s+(.*)\n/) {
	    my $proto = $1;
	    $proto = "||$proto" unless $proto =~ /\|/;
	    my($flags, $ret, $name, @args) = split /\|/, $proto;
	    my $docs = "";
DOC:
	    while (defined($doc = <$fh>)) {
                if ($doc =~ /^=head1 (.*)/) {
                    $curheader = $1;
                    next DOC;
                }
		$line++;
		last DOC if $doc =~ /^=\w+/;
		if ($doc =~ m:^\*/$:) {
		    warn "=cut missing? $file:$line:$doc";;
		    last DOC;
		}
		$docs .= $doc;
	    }
	    $docs = "\n$docs" if $docs and $docs !~ /^\n/;
	    if ($flags =~ /m/) {
		if ($flags =~ /A/) {
		    $apidocs{$curheader}{$name} = [$flags, $docs, $ret, $file, @args];
		}
		else {
		    $gutsdocs{$curheader}{$name} = [$flags, $docs, $ret, $file, @args];
		}
	    }
	    else {
		$docfuncs{$name} = [$flags, $docs, $ret, $file, $curheader, @args];
	    }
	    if (defined $doc) {
		if ($doc =~ /^=for/) {
		    $in = $doc;
		    redo FUNC;
		}
	    } else {
		warn "$file:$line:$in";
	    }
	}
    }
}

sub docout ($$$) { # output the docs for one function
    my($fh, $name, $docref) = @_;
    my($flags, $docs, $ret, $file, @args) = @$docref;

    $docs .= "NOTE: this function is experimental and may change or be
removed without notice.\n\n" if $flags =~ /x/;
    $docs .= "NOTE: the perl_ form of this function is deprecated.\n\n"
	if $flags =~ /p/;

    print $fh "=item $name\n$docs";

    if ($flags =~ /U/) { # no usage
	# nothing
    } elsif ($flags =~ /s/) { # semicolon ("dTHR;")
	print $fh "\t\t$name;\n\n";
    } elsif ($flags =~ /n/) { # no args
	print $fh "\t$ret\t$name\n\n";
    } else { # full usage
	print $fh "\t$ret\t$name";
	print $fh "(" . join(", ", @args) . ")";
	print $fh "\n\n";
    }
    print $fh "=for hackers\nFound in file $file\n\n";
}

my $file;
for $file (glob('*.c'), glob('*.h')) {
    open F, "< $file" or die "Cannot open $file for docs: $!\n";
    $curheader = "Functions in file $file\n";
    autodoc(\*F,$file);
    close F or die "Error closing $file: $!\n";
}

unlink "pod/perlapi.pod";
open (DOC, ">pod/perlapi.pod") or
	die "Can't create pod/perlapi.pod: $!\n";

walk_table {	# load documented functions into approriate hash
    if (@_ > 1) {
	my($flags, $retval, $func, @args) = @_;
	return "" unless $flags =~ /d/;
	$func =~ s/\t//g; $flags =~ s/p//; # clean up fields from embed.pl
	$retval =~ s/\t//;
	if ($flags =~ /A/) {
	    my $docref = delete $docfuncs{$func};
	    warn "no docs for $func\n" unless $docref and @$docref;
            $docref->[0].="x" if $flags =~ /M/;
	    $apidocs{$docref->[4]}{$func} = 
                [$docref->[0] . 'A', $docref->[1], $retval, $docref->[3], @args];
	} else {
	    my $docref = delete $docfuncs{$func};
	    $gutsdocs{$docref->[4]}{$func} = 
                [$docref->[0], $docref->[1], $retval, $docref->[3], @args];
	}
    }
    return "";
} \*DOC;

for (sort keys %docfuncs) {
    # Have you used a full for apidoc or just a func name?
    # Have you used Ap instead of Am in the for apidoc?
    warn "Unable to place $_!\n";
}

print DOC <<'_EOB_';
=head1 NAME

perlapi - autogenerated documentation for the perl public API

=head1 DESCRIPTION

This file contains the documentation of the perl public API generated by
embed.pl, specifically a listing of functions, macros, flags, and variables
that may be used by extension writers.  The interfaces of any functions that
are not listed here are subject to change without notice.  For this reason,
blindly using functions listed in proto.h is to be avoided when writing
extensions.

Note that all Perl API global variables must be referenced with the C<PL_>
prefix.  Some macros are provided for compatibility with the older,
unadorned names, but this support may be disabled in a future release.

The listing is alphabetical, case insensitive.

_EOB_

my $key;
for $key (sort { uc($a) cmp uc($b); } keys %apidocs) { # case insensitive sort
    my $section = $apidocs{$key}; 
    print DOC "\n=head1 $key\n\n=over 8\n\n";
    for my $key (sort { uc($a) cmp uc($b); } keys %$section) {
        docout(\*DOC, $key, $section->{$key});
    }
    print DOC "\n=back\n";
}

print DOC <<'_EOE_';

=head1 AUTHORS

Until May 1997, this document was maintained by Jeff Okamoto
<okamoto@corp.hp.com>.  It is now maintained as part of Perl itself.

With lots of help and suggestions from Dean Roehrich, Malcolm Beattie,
Andreas Koenig, Paul Hudson, Ilya Zakharevich, Paul Marquess, Neil
Bowers, Matthew Green, Tim Bunce, Spider Boardman, Ulrich Pfeifer,
Stephen McCamant, and Gurusamy Sarathy.

API Listing originally by Dean Roehrich <roehrich@cray.com>.

Updated to be autogenerated from comments in the source by Benjamin Stuhl.

=head1 SEE ALSO

perlguts(1), perlxs(1), perlxstut(1), perlintern(1)

_EOE_


close(DOC);

open(GUTS, ">pod/perlintern.pod") or
		die "Unable to create pod/perlintern.pod: $!\n";
print GUTS <<'END';
=head1 NAME

perlintern - autogenerated documentation of purely B<internal>
		 Perl functions

=head1 DESCRIPTION

This file is the autogenerated documentation of functions in the
Perl interpreter that are documented using Perl's internal documentation
format but are not marked as part of the Perl API. In other words,
B<they are not for use in extensions>!

END

for $key (sort { uc($a) cmp uc($b); } keys %gutsdocs) {
    my $section = $gutsdocs{$key}; 
    print GUTS "\n=head1 $key\n\n=over 8\n\n";
    for my $key (sort { uc($a) cmp uc($b); } keys %$section) {
        docout(\*GUTS, $key, $section->{$key});
    }
    print GUTS "\n=back\n";
}

print GUTS <<'END';

=head1 AUTHORS

The autodocumentation system was originally added to the Perl core by
Benjamin Stuhl. Documentation is by whoever was kind enough to
document their functions.

=head1 SEE ALSO

perlguts(1), perlapi(1)

END

close GUTS;


package Encode;

$VERSION = 0.01;

require DynaLoader;
require Exporter;

@ISA = qw(Exporter DynaLoader);

# Public, encouraged API is exported by default
@EXPORT = qw (
  encode
  decode
  encode_utf8
  decode_utf8
  find_encoding
);

@EXPORT_OK =
    qw(
       encodings
       from_to
       is_utf8
       is_8bit
       is_16bit
       utf8_upgrade
       utf8_downgrade
       _utf8_on
       _utf8_off
      );

bootstrap Encode ();

# Documentation moved after __END__ for speed - NI-S

use Carp;

# The global hash is declared in XS code
$encoding{Unicode}      = bless({},'Encode::Unicode');
$encoding{utf8}         = bless({},'Encode::utf8');
$encoding{'iso10646-1'} = bless({},'Encode::iso10646_1');

sub encodings
{
 my ($class) = @_;
 foreach my $dir (@INC)
  {
   if (opendir(my $dh,"$dir/Encode"))
    {
     while (defined(my $name = readdir($dh)))
      {
       if ($name =~ /^(.*)\.enc$/)
        {
         next if exists $encoding{$1};
         $encoding{$1} = "$dir/$name";
        }
      }
     closedir($dh);
    }
  }
 return keys %encoding;
}

sub loadEncoding
{
 my ($class,$name,$file) = @_;
 if (open(my $fh,$file))
  {
   my $type;
   while (1)
    {
     my $line = <$fh>;
     $type = substr($line,0,1);
     last unless $type eq '#';
    }
   $class .= ('::'.(($type eq 'E') ? 'Escape' : 'Table'));
   #warn "Loading $file";
   return $class->read($fh,$name,$type);
  }
 else
  {
   return undef;
  }
}

sub getEncoding
{
 my ($class,$name) = @_;
 my $enc;
 unless (ref($enc = $encoding{$name}))
  {
   $enc = $class->loadEncoding($name,$enc) if defined $enc;
   unless (ref($enc))
    {
     foreach my $dir (@INC)
      {
       last if ($enc = $class->loadEncoding($name,"$dir/Encode/$name.enc"));
      }
    }
   $encoding{$name} = $enc;
  }
 return $enc;
}

sub find_encoding
{
 my ($name) = @_;
 return __PACKAGE__->getEncoding($name);
}

sub encode
{
 my ($name,$string,$check) = @_;
 my $enc = find_encoding($name);
 croak("Unknown encoding '$name'") unless defined $enc;
 my $octets = $enc->encode($string,$check);
 return undef if ($check && length($string));
 return $octets;
}

sub decode
{
 my ($name,$octets,$check) = @_;
 my $enc = find_encoding($name);
 croak("Unknown encoding '$name'") unless defined $enc;
 my $string = $enc->decode($octets,$check);
 return undef if ($check && length($octets));
 return $string;
}

sub from_to
{
 my ($string,$from,$to,$check) = @_;
 my $f = find_encoding($from);
 croak("Unknown encoding '$from'") unless defined $f;
 my $t = find_encoding($to);
 croak("Unknown encoding '$to'") unless defined $t;
 my $uni = $f->decode($string,$check);
 return undef if ($check && length($string));
 $string = $t->encode($uni,$check);
 return undef if ($check && length($uni));
 return length($_[0] = $string);
}

sub encode_utf8
{
 my ($str) = @_;
 utf8_encode($str);
 return $str;
}

sub decode_utf8
{
 my ($str) = @_;
 return undef unless utf8_decode($str);
 return $str;
}

package Encode::Encoding;
# Base class for classes which implement encodings

# Temporary legacy methods
sub toUnicode    { shift->decode(@_) }
sub fromUnicode  { shift->encode(@_) }

sub new_sequence { return $_[0] }

package Encode::XS;
use base 'Encode::Encoding';

package Encode::Unicode;
use base 'Encode::Encoding';

# Dummy package that provides the encode interface but leaves data
# as UTF-8 encoded. It is here so that from_to() works.

sub name { 'Unicode' }

sub decode
{
 my ($obj,$str,$chk) = @_;
 Encode::utf8_upgrade($str);
 $_[1] = '' if $chk;
 return $str;
}

*encode = \&decode;

package Encode::utf8;
use base 'Encode::Encoding';

# package to allow long-hand
#   $octets = encode( utf8 => $string );
#

sub name { 'utf8' }

sub decode
{
 my ($obj,$octets,$chk) = @_;
 my $str = Encode::decode_utf8($octets);
 if (defined $str)
  {
   $_[1] = '' if $chk;
   return $str;
  }
 return undef;
}

sub encode
{
 my ($obj,$string,$chk) = @_;
 my $octets = Encode::encode_utf8($string);
 $_[1] = '' if $chk;
 return $octets;
}

package Encode::Table;
use base 'Encode::Encoding';

sub read
{
 my ($class,$fh,$name,$type) = @_;
 my $rep = $class->can("rep_$type");
 my ($def,$sym,$pages) = split(/\s+/,scalar(<$fh>));
 my @touni;
 my %fmuni;
 my $count = 0;
 $def = hex($def);
 while ($pages--)
  {
   my $line = <$fh>;
   chomp($line);
   my $page = hex($line);
   my @page;
   my $ch = $page * 256;
   for (my $i = 0; $i < 16; $i++)
    {
     my $line = <$fh>;
     for (my $j = 0; $j < 16; $j++)
      {
       my $val = hex(substr($line,0,4,''));
       if ($val || !$ch)
        {
         my $uch = chr($val);
         push(@page,$uch);
         $fmuni{$uch} = $ch;
         $count++;
        }
       else
        {
         push(@page,undef);
        }
       $ch++;
      }
    }
   $touni[$page] = \@page;
  }

 return bless {Name  => $name,
               Rep   => $rep,
               ToUni => \@touni,
               FmUni => \%fmuni,
               Def   => $def,
               Num   => $count,
              },$class;
}

sub name { shift->{'Name'} }

sub rep_S { 'C' }

sub rep_D { 'n' }

sub rep_M { ($_[0] > 255) ? 'n' : 'C' }

sub representation
{
 my ($obj,$ch) = @_;
 $ch = 0 unless @_ > 1;
 $obj-{'Rep'}->($ch);
}

sub decode
{
 my ($obj,$str,$chk) = @_;
 my $rep   = $obj->{'Rep'};
 my $touni = $obj->{'ToUni'};
 my $uni   = '';
 while (length($str))
  {
   my $ch = ord(substr($str,0,1,''));
   my $x;
   if (&$rep($ch) eq 'C')
    {
     $x = $touni->[0][$ch];
    }
   else
    {
     $x = $touni->[$ch][ord(substr($str,0,1,''))];
    }
   unless (defined $x)
    {
     last if $chk;
     # What do we do here ?
     $x = '';
    }
   $uni .= $x;
  }
 $_[1] = $str if $chk;
 return $uni;
}

sub encode
{
 my ($obj,$uni,$chk) = @_;
 my $fmuni = $obj->{'FmUni'};
 my $str   = '';
 my $def   = $obj->{'Def'};
 my $rep   = $obj->{'Rep'};
 while (length($uni))
  {
   my $ch = substr($uni,0,1,'');
   my $x  = $fmuni->{chr(ord($ch))};
   unless (defined $x)
    {
     last if ($chk);
     $x = $def;
    }
   $str .= pack(&$rep($x),$x);
  }
 $_[1] = $uni if $chk;
 return $str;
}

package Encode::iso10646_1;
use base 'Encode::Encoding';

# Encoding is 16-bit network order Unicode
# Used for X font encodings

sub name { 'iso10646-1' }

sub decode
{
 my ($obj,$str,$chk) = @_;
 my $uni   = '';
 while (length($str))
  {
   my $code = unpack('n',substr($str,0,2,'')) & 0xffff;
   $uni .= chr($code);
  }
 $_[1] = $str if $chk;
 Encode::utf8_upgrade($uni);
 return $uni;
}

sub encode
{
 my ($obj,$uni,$chk) = @_;
 my $str   = '';
 while (length($uni))
  {
   my $ch = substr($uni,0,1,'');
   my $x  = ord($ch);
   unless ($x < 32768)
    {
     last if ($chk);
     $x = 0;
    }
   $str .= pack('n',$x);
  }
 $_[1] = $uni if $chk;
 return $str;
}


package Encode::Escape;
use base 'Encode::Encoding';

use Carp;

sub read
{
 my ($class,$fh,$name) = @_;
 my %self = (Name => $name, Num => 0);
 while (<$fh>)
  {
   my ($key,$val) = /^(\S+)\s+(.*)$/;
   $val =~ s/^\{(.*?)\}/$1/g;
   $val =~ s/\\x([0-9a-f]{2})/chr(hex($1))/ge;
   $self{$key} = $val;
  }
 return bless \%self,$class;
}

sub name { shift->{'Name'} }

sub decode
{
 croak("Not implemented yet");
}

sub encode
{
 croak("Not implemented yet");
}

# switch back to Encode package in case we ever add AutoLoader
package Encode;

1;

__END__

=head1 NAME

Encode - character encodings

=head1 SYNOPSIS

    use Encode;

=head1 DESCRIPTION

The C<Encode> module provides the interfaces between perl's strings
and the rest of the system. Perl strings are sequences of B<characters>.

The repertoire of characters that Perl can represent is at least that
defined by the Unicode Consortium. On most platforms the ordinal values
of the  characters (as returned by C<ord(ch)>) is the "Unicode codepoint" for
the character (the exceptions are those platforms where the legacy
encoding is some variant of EBCDIC rather than a super-set of ASCII
- see L<perlebcdic>).

Traditionaly computer data has been moved around in 8-bit chunks
often called "bytes". These chunks are also known as "octets" in
networking standards. Perl is widely used to manipulate data of
many types - not only strings of characters representing human or
computer languages but also "binary" data being the machines representation
of numbers, pixels in an image - or just about anything.

When perl is processing "binary data" the programmer wants perl to process
"sequences of bytes". This is not a problem for perl - as a byte has 256
possible values it easily fits in perl's much larger "logical character".

=head2 TERMINOLOGY

=over 4

=item *

I<character>: a character in the range 0..(2**32-1) (or more).
(What perl's strings are made of.)

=item *

I<byte>: a character in the range 0..255
(A special case of a perl character.)

=item *

I<octet>: 8 bits of data, with ordinal values 0..255
(Term for bytes passed to or from a non-perl context, e.g. disk file.)

=back

The marker [INTERNAL] marks Internal Implementation Details, in
general meant only for those who think they know what they are doing,
and such details may change in future releases.

=head1 ENCODINGS

=head2 Characteristics of an Encoding

An encoding has a "repertoire" of characters that it can represent,
and for each representable character there is at least one sequence of
octets that represents it.

=head2 Types of Encodings

Encodings can be divided into the following types:

=over 4

=item * Fixed length 8-bit (or less) encodings.

Each character is a single octet so may have a repertoire of up to
256 characters. ASCII and iso-8859-* are typical examples.

=item * Fixed length 16-bit encodings

Each character is two octets so may have a repertoire of up to
65,536 characters. Unicode's UCS-2 is an example. Also used for
encodings for East Asian languages.

=item * Fixed length 32-bit encodings.

Not really very "encoded" encodings. The Unicode code points
are just represented as 4-octet integers. None the less because
different architectures use different representations of integers
(so called "endian") there at least two disctinct encodings.

=item * Multi-byte encodings

The number of octets needed to represent a character varies.
UTF-8 is a particularly complex but regular case of a multi-byte
encoding. Several East Asian countries use a multi-byte encoding
where 1-octet is used to cover western roman characters and Asian
characters get 2-octets.
(UTF-16 is strictly a multi-byte encoding taking either 2 or 4 octets
to represent a Unicode code point.)

=item * "Escape" encodings.

These encodings embed "escape sequences" into the octet sequence
which describe how the following octets are to be interpreted.
The iso-2022-* family is typical. Following the escape sequence
octets are encoded by an "embedded" encoding (which will be one
of the above types) until another escape sequence switches to
a different "embedded" encoding.

These schemes are very flexible and can handle mixed languages but are
very complex to process (and have state).
No escape encodings are implemented for perl yet.

=back

=head2 Specifying Encodings

Encodings can be specified to the API described below in two ways:

=over 4

=item 1. By name

Encoding names are strings with characters taken from a restricted repertoire.
See L</"Encoding Names">.

=item 2. As an object

Encoding objects are returned by C<find_encoding($name)>.

=back

=head2 Encoding Names

Encoding names are case insensitive. White space in names is ignored.
In addition an encoding may have aliases. Each encoding has one "canonical" name.
The "canonical" name is chosen from the names of the encoding by picking
the first in the following sequence:

=over 4

=item * The MIME name as defined in IETF RFC-XXXX.

=item * The name in the IANA registry.

=item * The name used by the the organization that defined it.

=back

Because of all the alias issues, and because in the general case
encodings have state C<Encode> uses the encoding object internally
once an operation is in progress.

I<Aliasing is not yet implemented.>

=head1 PERL ENCODING API

=head2 Generic Encoding Interface

=over 4

=item *

        $bytes  = encode(ENCODING, $string[, CHECK])

Encodes string from perl's internal form into I<ENCODING> and returns a
sequence of octets.
See L</"Handling Malformed Data">.

=item *

        $string = decode(ENCODING, $bytes[, CHECK])

Decode sequence of octets assumed to be in I<ENCODING> into perls internal
form and returns the resuting string.
See L</"Handling Malformed Data">.

=back

=head2 Handling Malformed Data

If CHECK is not set, C<undef> is returned.  If the data is supposed to
be UTF-8, an optional lexical warning (category utf8) is given.
If CHECK is true but not a code reference, dies.

It would desirable to have a way to indicate that transform should use the
encodings "replacement character" - no such mechanism is defined yet.

It is also planned to allow I<CHECK> to be a code reference.

This is not yet implemented as there are design issues with what its arguments
should be and how it returns its results.

=over 4

=item Scheme 1

Passed remaining fragment of string being processed.
Modifies it in place to remove bytes/characters it can understand
and returns a string used to represent them.
e.g.

 sub fixup {
   my $ch = substr($_[0],0,1,'');
   return sprintf("\x{%02X}",ord($ch);
 }

This scheme is close to how underlying C code for Encode works, but gives
the fixup routine very little context.

=item Scheme 2

Passed original string, and an index into it of the problem area,
and output string so far.
Appends what it will to output string and returns new index into
original string.
e.g.

 sub fixup {
   # my ($s,$i,$d) = @_;
   my $ch = substr($_[0],$_[1],1);
   $_[2] .= sprintf("\x{%02X}",ord($ch);
   return $_[1]+1;
 }

This scheme gives maximal control to the fixup routine but is more complicated
to code, and may need internals of Encode to be tweaked to keep original
string intact.

=item Other Schemes

Hybrids of above.

Multiple return values rather than in-place modifications.

Index into the string could be pos($str) allowing s/\G...//.

=back

=head2 UTF-8 / utf8

The Unicode consortium defines the UTF-8 standard as a way of encoding
the entire Unicode repertiore as sequences of octets. This encoding
is expected to become very widespread. Perl can use this form internaly
to represent strings, so conversions to and from this form are particularly
efficient (as octets in memory do not have to change, just the meta-data
that tells perl how to treat them).

=over 4

=item *

        $bytes = encode_utf8($string);

The characters that comprise string are encoded in perl's superset of UTF-8
and the resulting octets returned as a sequence of bytes. All possible
characters have a UTF-8 representation so this function cannot fail.

=item *

        $string = decode_utf8($bytes [,CHECK]);

The sequence of octets represented by $bytes is decoded from UTF-8 into
a sequence of logical characters. Not all sequences of octets form valid
UTF-8 encodings, so it is possible for this call to fail.
See L</"Handling Malformed Data">.

=back

=head2 Other Encodings of Unicode

UTF-16 is similar to UCS-2, 16 bit or 2-byte chunks.
UCS-2 can only represent 0..0xFFFF, while UTF-16 has a "surogate pair"
scheme which allows it to cover the whole Unicode range.

Encode implements big-endian UCS-2 as the encoding "iso10646-1" as that
happens to be the name used by that representation when used with X11 fonts.

UTF-32 or UCS-4 is 32-bit or 4-byte chunks.  Perl's logical characters
can be considered as being in this form without encoding. An encoding
to transfer strings in this form (e.g. to write them to a file) would need to

     pack('L',map(chr($_),split(//,$string)));   # native
  or
     pack('V',map(chr($_),split(//,$string)));   # little-endian
  or
     pack('N',map(chr($_),split(//,$string)));   # big-endian

depending on the endian required.

No UTF-32 encodings are not yet implemented.

Both UCS-2 and UCS-4 style encodings can have "byte order marks" by representing
the code point 0xFFFE as the very first thing in a file.

=head1 Encoding and IO

It is very common to want to do encoding transformations when
reading or writing files, network connections, pipes etc.
If perl is configured to use the new 'perlio' IO system then
C<Encode> provides a "layer" (See L<perliol>) which can transform
data as it is read or written.

     open(my $ilyad,'>:encoding(iso8859-7)','ilyad.greek');
     print $ilyad @epic;

In addition the new IO system can also be configured to read/write
UTF-8 encoded characters (as noted above this is efficient):

     open(my $fh,'>:utf8','anything');
     print $fh "Any \x{0021} string \N{SMILEY FACE}\n";

Either of the above forms of "layer" specifications can be made the default
for a lexical scope with the C<use open ...> pragma. See L<open>.

Once a handle is open is layers can be altered using C<binmode>.

Without any such configuration, or if perl itself is built using
system's own IO, then write operations assume that file handle accepts
only I<bytes> and will C<die> if a character larger than 255 is
written to the handle. When reading, each octet from the handle
becomes a byte-in-a-character. Note that this default is the same
behaviour as bytes-only languages (including perl before v5.6) would have,
and is sufficient to handle native 8-bit encodings e.g. iso-8859-1,
EBCDIC etc. and any legacy mechanisms for handling other encodings
and binary data.

In other cases it is the programs responsibility
to transform characters into bytes using the API above before
doing writes, and to transform the bytes read from a handle into characters
before doing "character operations" (e.g. C<lc>, C</\W+/>, ...).

=head1 Encoding How to ...

To do:

=over 4

=item * IO with mixed content (faking iso-2020-*)

=item * MIME's Content-Length:

=item * UTF-8 strings in binary data.

=item * perl/Encode wrappers on non-Unicode XS modules.

=back

=head1 Messing with Perl's Internals

The following API uses parts of perl's internals in the current implementation.
As such they are efficient, but may change.

=over 4

=item *

        $num_octets = utf8_upgrade($string);

Converts internal representation of string to the UTF-8 form.
Returns the number of octets necessary to represent the string as UTF-8.

=item * utf8_downgrade($string[, CHECK])

Converts internal representation of string to be un-encoded bytes.

=item * is_utf8(STRING [, CHECK])

[INTERNAL] Test whether the UTF-8 flag is turned on in the STRING.
If CHECK is true, also checks the data in STRING for being
well-formed UTF-8.  Returns true if successful, false otherwise.

=item * valid_utf8(STRING)

[INTERNAL] Test whether STRING is in a consistent state.
Will return true if string is held as bytes, or is well-formed UTF-8
and has the UTF-8 flag on.
Main reason for this routine is to allow perl's testsuite to check
that operations have left strings in a consistent state.

=item *

        _utf8_on(STRING)

[INTERNAL] Turn on the UTF-8 flag in STRING.  The data in STRING is
B<not> checked for being well-formed UTF-8.  Do not use unless you
B<know> that the STRING is well-formed UTF-8.  Returns the previous
state of the UTF-8 flag (so please don't test the return value as
I<not> success or failure), or C<undef> if STRING is not a string.

=item *

        _utf8_off(STRING)

[INTERNAL] Turn off the UTF-8 flag in STRING.  Do not use frivolously.
Returns the previous state of the UTF-8 flag (so please don't test the
return value as I<not> success or failure), or C<undef> if STRING is
not a string.

=back

=head1 IMPLEMENTATION CLASSES

As mentioned above encodings are (in the current implementation at least)
defined by objects. The mapping of encoding name to object is via the
C<%Encode::encodings> hash. (It is a package hash to allow XS code to get
at it.)

The values of the hash can currently be either strings or objects.
The string form may go away in the future. The string form occurs
when C<encodings()> has scanned C<@INC> for loadable encodings but has
not actually loaded the encoding in question. This is because the
current "loading" process is all perl and a bit slow.

Once an encoding is loaded then value of the hash is object which implements
the encoding. The object should provide the following interface:

=over 4

=item -E<gt>name

Should return the string representing the canonical name of the encoding.

=item -E<gt>new_sequence

This is a placeholder for encodings with state. It should return an object
which implements this interface, all current implementations return the
original object.

=item -E<gt>encode($string,$check)

Should return the octet sequence representing I<$string>. If I<$check> is true
it should modify I<$string> in place to remove the converted part (i.e.
the whole string unless there is an error).
If an error occurs it should return the octet sequence for the
fragment of string that has been converted, and modify $string in-place
to remove the converted part leaving it starting with the problem fragment.

If check is is false then C<encode> should make a "best effort" to convert
the string - for example by using a replacement character.

=item -E<gt>decode($octets,$check)

Should return the string that I<$octets> represents. If I<$check> is true
it should modify I<$octets> in place to remove the converted part (i.e.
the whole sequence unless there is an error).
If an error occurs it should return the fragment of string
that has been converted, and modify $octets in-place to remove the converted part
leaving it starting with the problem fragment.

If check is is false then C<decode> should make a "best effort" to convert
the string - for example by using Unicode's "\x{FFFD}" as a replacement character.

=back

It should be noted that the check behaviour is different from the outer
public API. The logic is that the "unchecked" case is useful when
encoding is part of a stream which may be reporting errors (e.g. STDERR).
In such cases it is desirable to get everything through somehow without
causing additional errors which obscure the original one. Also the encoding
is best placed to know what the correct replacement character is, so if that
is the desired behaviour then letting low level code do it is the most efficient.

In contrast if check is true, the scheme above allows the encoding to do as
much as it can and tell layer above how much that was. What is lacking
at present is a mechanism to report what went wrong. The most likely interface
will be an additional method call to the object, or perhaps
(to avoid forcing per-stream objects on otherwise stateless encodings)
and additional parameter.

It is also highly desirable that encoding classes inherit from C<Encode::Encoding>
as a base class. This allows that class to define additional behaviour for
all encoding objects.

=head2 Compiled Encodings

F<Encode.xs> provides a class C<Encode::XS> which provides the interface described
above. It calls a generic octet-sequence to octet-sequence "engine" that is
driven by tables (defined in F<encengine.c>). The same engine is used for both
encode and decode. C<Encode:XS>'s C<encode> forces perl's characters to their UTF-8 form
and then treats them as just another multibyte encoding. C<Encode:XS>'s C<decode> transforms
the sequence and then turns the UTF-8-ness flag as that is the form that the tables
are defined to produce. For details of the engine see the comments in F<encengine.c>.

The tables are produced by the perl script F<compile> (the name needs to change so
we can eventually install it somewhere). F<compile> can currently read two formats:

=over 4

=item *.enc

This is a coined format used by Tcl. It is documented in Encode/EncodeFormat.pod.

=item *.ucm

This is the semi-standard format used by IBM's ICU package.

=back

F<compile> can write the following forms:

=over 4

=item *.ucm

See above - the F<Encode/*.ucm> files provided with the distribution have
been created from the original Tcl .enc files using this approach.

=item *.c

Produces tables as C data structures - this is used to build in encodings
into F<Encode.so>/F<Encode.dll>.

=item *.xs

In theory this allows encodings to be stand-alone loadable perl extensions.
The process has not yet been tested. The plan is to use this approach
for large East Asian encodings.

=back

The set of encodings built-in to F<Encode.so>/F<Encode.dll> is determined by
F<Makefile.PL>. The current set is as follows:

=over 4

=item ascii and iso-8859-*

That is all the common 8-bit "western" encodings.

=item IBM-1047 and two other variants of EBCDIC.

These are the same variants that are supported by EBCDIC perl as "native" encodings.
They are included to prove "reversibility" of some constructs in EBCDIC perl.

=item symbol and dingbats as used by Tk on X11.

(The reason Encode got started was to support perl/Tk.)

=back

That set is rather ad. hoc. and has been driven by the needs of the tests rather
than the needs of typical applications. It is likely to be rationalized.

=head1 SEE ALSO

L<perlunicode>, L<perlebcdic>, L<perlfunc/open>

=cut




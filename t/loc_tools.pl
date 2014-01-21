# Common tools for test files files to find the locales which exist on the
# system.

# Note that it's okay that some languages have their native names
# capitalized here even though that's not "right".  They are lowercased
# anyway later during the scanning process (and besides, some clueless
# vendor might have them capitalized erroneously anyway).


sub _trylocale {    # Adds the locale given by the first parameter to the list
                    # given by the 2nd iff the platform supports the locale,
                    # and it is not already on the list
    my $locale = shift;
    my $list = shift;
    return if grep { $locale eq $_ } @$list;
    return unless setlocale(&POSIX::LC_ALL, $locale);
    my $badutf8;
    {
        local $SIG{__WARN__} = sub {
            $badutf8 = $_[0] =~ /Malformed UTF-8/;
        };
    }

    if ($badutf8) {
        ok(0, "Verify locale name doesn't contain malformed utf8");
        return;
    }
    push @$list, $locale;
}

sub _decode_encodings {
    my @enc;

    foreach (split(/ /, shift)) {
	if (/^(\d+)$/) {
	    push @enc, "ISO8859-$1";
	    push @enc, "iso8859$1";	# HP
	    if ($1 eq '1') {
		 push @enc, "roman8";	# HP
	    }
	    push @enc, $_;
            push @enc, "$_.UTF-8";
            push @enc, "$_.65001"; # Windows UTF-8
            push @enc, "$_.ACP"; # Windows ANSI code page
            push @enc, "$_.OCP"; # Windows OEM code page
	}
    }
    if ($^O eq 'os390') {
	push @enc, qw(IBM-037 IBM-819 IBM-1047);
    }
    push @enc, "UTF-8";
    push @enc, "65001"; # Windows UTF-8

    return @enc;
}

sub find_locales {  # Returns an array of all the locales we found on the
                    # system


    my $have_setlocale = 0;
    eval {
        require POSIX;
        import POSIX ':locale_h';
        $have_setlocale++;
    };

    # Visual C's CRT goes silly on strings of the form "en_US.ISO8859-1"
    # and mingw32 uses said silly CRT
    # This doesn't seem to be an issue any more, at least on Windows XP,
    # so re-enable the tests for Windows XP onwards.
    my $winxp = ($^O eq 'MSWin32' && defined &Win32::GetOSVersion &&
                    join('.', (Win32::GetOSVersion())[1..2]) >= 5.1);
    $have_setlocale = 0 if ((($^O eq 'MSWin32' && !$winxp) || $^O eq 'NetWare') &&
                    $Config{cc} =~ /^(cl|gcc|g\+\+|ici)/i);

    # UWIN seems to loop after taint tests, just skip for now
    $have_setlocale = 0 if ($^O =~ /^uwin/);

    return unless $have_setlocale;

    _trylocale("C", \@Locale);
    _trylocale("POSIX", \@Locale);
    foreach (0..15) {
        _trylocale("ISO8859-$_", \@Locale);
        _trylocale("iso8859$_", \@Locale);
        _trylocale("iso8859-$_", \@Locale);
        _trylocale("iso_8859_$_", \@Locale);
        _trylocale("isolatin$_", \@Locale);
        _trylocale("isolatin-$_", \@Locale);
        _trylocale("iso_latin_$_", \@Locale);
    }

    # Sanitize the environment so that we can run the external 'locale'
    # program without the taint mode getting grumpy.

    # $ENV{PATH} is special in VMS.
    delete $ENV{PATH} if $^O ne 'VMS' or $Config{d_setenv};

    # Other subversive stuff.
    delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};

    if (-x "/usr/bin/locale"
        && open(LOCALES, "/usr/bin/locale -a 2>/dev/null|"))
    {
        while (<LOCALES>) {
            # It seems that /usr/bin/locale steadfastly outputs 8 bit data, which
            # ain't great when we're running this testPERL_UNICODE= so that utf8
            # locales will cause all IO hadles to default to (assume) utf8
            next unless utf8::valid($_);
            chomp;
            _trylocale($_, \@Locale);
        }
        close(LOCALES);
    } elsif ($^O eq 'VMS'
             && defined($ENV{'SYS$I18N_LOCALE'})
             && -d 'SYS$I18N_LOCALE')
    {
    # The SYS$I18N_LOCALE logical name search list was not present on
    # VAX VMS V5.5-12, but was on AXP && VAX VMS V6.2 as well as later versions.
        opendir(LOCALES, "SYS\$I18N_LOCALE:");
        while ($_ = readdir(LOCALES)) {
            chomp;
            _trylocale($_, \@Locale);
        }
        close(LOCALES);
    } elsif (($^O eq 'openbsd' || $^O eq 'bitrig' ) && -e '/usr/share/locale') {

    # OpenBSD doesn't have a locale executable, so reading /usr/share/locale
    # is much easier and faster than the last resort method.

        opendir(LOCALES, '/usr/share/locale');
        while ($_ = readdir(LOCALES)) {
            chomp;
            _trylocale($_, \@Locale);
        }
        close(LOCALES);
    } else { # Final fallback.  Try our list of locales hard-coded here

        # This is going to be slow.
        my @Data;


        # Locales whose name differs if the utf8 bit is on are stored in these two
        # files with appropriate encodings.
        if ($^H & 0x08 || (${^OPEN} || "") =~ /:utf8/) {
            @Data = do "lib/locale/utf8";
        } else {
            @Data = do "lib/locale/latin1";
        }

        # The rest of the locales are in this file.
        push @Data, <DATA>;

        foreach my $line (@Data) {
            my ($locale_name, $language_codes, $country_codes, $encodings) =
                split /:/, $line;
            my @enc = _decode_encodings($encodings);
            foreach my $loc (split(/ /, $locale_name)) {
                _trylocale($loc, \@Locale);
                foreach my $enc (@enc) {
                    _trylocale("$loc.$enc", \@Locale);
                }
                $loc = lc $loc;
                foreach my $enc (@enc) {
                    _trylocale("$loc.$enc", \@Locale);
                }
            }
            foreach my $lang (split(/ /, $language_codes)) {
                _trylocale($lang, \@Locale);
                foreach my $country (split(/ /, $country_codes)) {
                    my $lc = "${lang}_${country}";
                    _trylocale($lc, \@Locale);
                    foreach my $enc (@enc) {
                        _trylocale("$lc.$enc", \@Locale);
                    }
                    my $lC = "${lang}_\U${country}";
                    _trylocale($lC, \@Locale);
                    foreach my $enc (@enc) {
                        _trylocale("$lC.$enc", \@Locale);
                    }
                }
            }
        }
    }

    @Locale = sort @Locale;

    return @Locale;


}

1

# Format of data is: locale_name, language_codes, country_codes, encodings
__DATA__
Afrikaans:af:za:1 15
Arabic:ar:dz eg sa:6 arabic8
Brezhoneg Breton:br:fr:1 15
Bulgarski Bulgarian:bg:bg:5
Chinese:zh:cn tw:cn.EUC eucCN eucTW euc.CN euc.TW Big5 GB2312 tw.EUC
Hrvatski Croatian:hr:hr:2
Cymraeg Welsh:cy:cy:1 14 15
Czech:cs:cz:2
Dansk Danish:da:dk:1 15
Nederlands Dutch:nl:be nl:1 15
English American British:en:au ca gb ie nz us uk zw:1 15 cp850
Esperanto:eo:eo:3
Eesti Estonian:et:ee:4 6 13
Suomi Finnish:fi:fi:1 15
Flamish::fl:1 15
Deutsch German:de:at be ch de lu:1 15
Euskaraz Basque:eu:es fr:1 15
Galego Galician:gl:es:1 15
Ellada Greek:el:gr:7 g8
Frysk:fy:nl:1 15
Greenlandic:kl:gl:4 6
Hebrew:iw:il:8 hebrew8
Hungarian:hu:hu:2
Indonesian:id:id:1 15
Gaeilge Irish:ga:IE:1 14 15
Italiano Italian:it:ch it:1 15
Nihongo Japanese:ja:jp:euc eucJP jp.EUC sjis
Korean:ko:kr:
Latine Latin:la:va:1 15
Latvian:lv:lv:4 6 13
Lithuanian:lt:lt:4 6 13
Macedonian:mk:mk:1 15
Maltese:mt:mt:3
Moldovan:mo:mo:2
Norsk Norwegian:no no\@nynorsk nb nn:no:1 15
Occitan:oc:es:1 15
Polski Polish:pl:pl:2
Rumanian:ro:ro:2
Russki Russian:ru:ru su ua:5 koi8 koi8r KOI8-R koi8u cp1251 cp866
Serbski Serbian:sr:yu:5
Slovak:sk:sk:2
Slovene Slovenian:sl:si:2
Sqhip Albanian:sq:sq:1 15
Svenska Swedish:sv:fi se:1 15
Thai:th:th:11 tis620
Turkish:tr:tr:9 turkish8
Yiddish:yi::1 15

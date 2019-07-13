unit module Text::Slugify;

my $CHAR-ENTITY                  = rx« (\& \w+ ';') »;
my $DECIMAL                      = rx« '&#' (<digit>+) ';' »;
my $HEX                          = rx« '&#x' (<xdigit>+) ';' »;
my $QUOTE                        = rx« "'"+ »;
my $ALLOWED-CHARS                = rx« <-[ \- a..z 0..9 ]>+ »;
my $ALLOWED-CHARS-WITH-UPPERCASE = rx« <-[ \- a..z A..Z 0..9 ]>+ »;
my $DUPLICATE-DASH               = rx« '-' ** 2..* »;
my $NUMBERS                      = rx« (<?after \d>) ',' (<?before \d>) »;
my $DEFAULT-SEPARATOR            = '-';

sub strip( $string is copy, $char ) {
    =begin comment
    Trim string from both leading and trailing characters $char.
    Similar to .trim but for any characters.

    NOTE TO SELF: There must be a cleaner P6-ish way but this'll do for now.
    =end comment

    return $string unless $string.starts-with($char) ||
                          $string.ends-with($char);

    if $string.starts-with($char) {
        my $pos = 0;
        for $string.comb {
            last if $char ne $_;
            $pos += 1;
        }
        $string .= substr($pos, *);
    }

    if $string.ends-with($char) {
        my $pos = 0;
        for $string.flip.comb {
            last if $char ne $_;
            $pos += 1;
        }
        $string .= substr(0, *-$pos);
    }

    return $string;
}

#| Truncate a string.
sub smart-truncate(
    Str:D  $string is rw,           #= String to be modified.
    Int:D  :$max-length    = 0,     #= Output string length.
    Bool:D :$word-boundary = False, #=
    Str:D  :$separator     = ' ',   #= Separator between words.
    Bool:D :$save-order    = False, #= Output text's word order same as input.
    --> Str
) is export(:ALL) {

    # remove string's leading and trailing whitespace.
    $string .= trim;

    # nothing to truncate.
    return $string unless $max-length;
    return $string if $string.chars < $max-length;

    unless $word-boundary {
        return strip $string.substr(0, $max-length), $separator;
    }

    unless $string.contains($separator) {
        return $string.substr(0, $max-length)
    }

    my $truncated = '';

    for $string.split($separator) -> $word {
        if $word {
            my $next-len = $truncated.chars + $word.chars;
            if $next-len < $max-length {
                $truncated ~= $word ~ $separator
            }
            elsif $next-len == $max-length {
                $truncated ~= $word;
                last;
            }
            else {
                last if $save-order
            }
        }
    }

    $truncated = $string.substr(0, $max-length) unless $truncated;

    return strip($truncated, $separator)
}

#| Make a slug from the given text.
sub slugify(
    Str:D  $text is copy,           #= Text to be slugified.
    Int:D  :$max-length    = 0,     #= Output string length.
    :$separator            = '-',   #= Separator between words.
    :$regex-pattern        = Nil,   #=« Regex pattern for allowed characters
                                        in output text.»
    :@stopwords            = [],    #= Words to be discounted from output text.
    :@replacements         = [],    #=« List of replacement rule pairs
                                        e.g. ['|'=>'or', '%'=>'percent']»
    Bool:D :$entities      = True,  #= Remove HTML entities
    Bool:D :$decimal       = True,  
    Bool:D :$hexadecimal   = True,
    Bool:D :$word-boundary = False,
    Bool:D :$lowercase     = True,  #= Set case sensitivity by setting it to False.
    Bool:D :$save-order    = False, #=« If True and max-length > 0 return
                                        whole words in the initial order.»
    --> Str:D
) is export(:DEFAULT) {

    # do user-specific replacements.
    for @replacements -> $replacement {
        for $replacement.kv -> $old, $new {
            $text .= subst: /$old/, $new, :g;
        }
    }

    # replace quotes with dashes.
    $text .= subst: $QUOTE, $DEFAULT-SEPARATOR, :g;

    # character entity reference
    $text .= subst($CHAR-ENTITY, '') if $entities;

    # decimal character reference
    $text .= subst($DECIMAL, '') if $decimal;

    # hexadecimal character reference
    $text .= subst($HEX, '') if $hexadecimal;

    # change mark/accent info for each character according to given character.
    $text .= samemark('a');

    # make the text lowercase (optional).
    $text .= lc if $lowercase;

    # remove quotes.
    $text .= subst: $QUOTE, '', :g;

    # cleanup numbers.
    $text .= subst: $NUMBERS, '', :g;

    # get pattern to replace unwanted characters.
    my $pattern = do if $lowercase { $regex-pattern // $ALLOWED-CHARS }
                     else { $regex-pattern // $ALLOWED-CHARS-WITH-UPPERCASE }

    # apply substitution with pattern.
    $text .= subst: $pattern, $DEFAULT-SEPARATOR, :g;

    # remove redundant dashes and strip away separator.
    $text = strip $text.subst($DUPLICATE-DASH, $DEFAULT-SEPARATOR, :g),
                  $DEFAULT-SEPARATOR;

    # remove stopwords.
    if @stopwords {
        my @words = do if $lowercase {
            my @stopwords-lower = @stopwords».lc;
            $text.split($DEFAULT-SEPARATOR).grep: * ∉ @stopwords-lower;
        }
        else {
            $text.split($DEFAULT-SEPARATOR).grep: * ∉ @stopwords;
        }
        $text = @words.join: $separator;
    }

    # finalize user-specific replacements.
    for @replacements -> $replacement {
        for $replacement.kv -> $old, $new {
            $text .= subst: /$old/, $new, :g;
        }
    }

    # smart truncate string if requested.
    if $max-length > 0 {
        $text = smart-truncate
            $text, :$max-length, :$word-boundary,
            :separator($DEFAULT-SEPARATOR), :$save-order;
    }

    # replace default separator with new separator.
    if $separator ne $DEFAULT-SEPARATOR {
        $text .= subst: $DEFAULT-SEPARATOR, $separator, :g;
    }

    return $text
}

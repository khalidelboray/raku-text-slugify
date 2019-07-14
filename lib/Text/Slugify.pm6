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

    # change Cyrillic and other "non-standard" characters from other scripts
    # by their romanized version. For instance, ю -> yu, þ -> th, etc.
    $text = $text.comb.map({char2ascii($_)}).join;

    # make the text lowercase (optional).
    $text .= lc if $lowercase;

    # remove quotes.
    $text .= subst: $QUOTE, '', :g;

    # get rid of commas in numbers.
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


sub char2ascii( $char ) {

    my %char-map = %(
        'À' => 'A', 'Á' => 'A', 'Â' => 'A', 'Ã' => 'A', 'Ä' => 'A', 'Å' => 'A',
        'Æ' => 'AE', 'Ç' => 'C', 'È' => 'E', 'É' => 'E', 'Ê' => 'E', 'Ë' => 'E',
        'Ì' => 'I', 'Í' => 'I', 'Î' => 'I', 'Ï' => 'I', 'Ð' => 'D', 'Ñ' => 'N',
        'Ò' => 'O', 'Ó' => 'O', 'Ô' => 'O', 'Õ' => 'O', 'Ö' => 'O', 'Ő' => 'O',
        'Ø' => 'O', 'Ù' => 'U', 'Ú' => 'U', 'Û' => 'U', 'Ü' => 'U', 'Ű' => 'U',
        'Ý' => 'Y', 'Þ' => 'TH', 'ß' => 'ss', 'à' => 'a', 'á' => 'a', 'â' => 'a',
        'ã' => 'a', 'ä' => 'a', 'å' => 'a', 'æ' => 'ae', 'ç' => 'c', 'è' => 'e',
        'é' => 'e', 'ê' => 'e', 'ë' => 'e', 'ì' => 'i', 'í' => 'i', 'î' => 'i',
        'ï' => 'i', 'ð' => 'd', 'ñ' => 'n', 'ò' => 'o', 'ó' => 'o', 'ô' => 'o',
        'õ' => 'o', 'ö' => 'o', 'ő' => 'o', 'ø' => 'o', 'ù' => 'u', 'ú' => 'u',
        'û' => 'u', 'ü' => 'u', 'ű' => 'u', 'ý' => 'y', 'þ' => 'th', 'ÿ' => 'y',

        # Latin symbols
        '©' => '(c)',

        # Greek
        'Α' => 'A', 'Β' => 'B', 'Γ' => 'G', 'Δ' => 'D', 'Ε' => 'E', 'Ζ' => 'Z',
        'Η' => 'H', 'Θ' => '8', 'Ι' => 'I', 'Κ' => 'K', 'Λ' => 'L', 'Μ' => 'M',
        'Ν' => 'N', 'Ξ' => '3', 'Ο' => 'O', 'Π' => 'P', 'Ρ' => 'R', 'Σ' => 'S',
        'Τ' => 'T', 'Υ' => 'Y', 'Φ' => 'F', 'Χ' => 'X', 'Ψ' => 'PS', 'Ω' => 'W',
        'Ά' => 'A', 'Έ' => 'E', 'Ί' => 'I', 'Ό' => 'O', 'Ύ' => 'Y', 'Ή' => 'H',
        'Ώ' => 'W', 'Ϊ' => 'I',	'Ϋ' => 'Y', 'α' => 'a', 'β' => 'b', 'γ' => 'g',
        'δ' => 'd', 'ε' => 'e', 'ζ' => 'z', 'η' => 'h', 'θ' => '8', 'ι' => 'i',
        'κ' => 'k', 'λ' => 'l', 'μ' => 'm', 'ν' => 'n', 'ξ' => '3', 'ο' => 'o',
        'π' => 'p', 'ρ' => 'r', 'σ' => 's', 'τ' => 't', 'υ' => 'y', 'φ' => 'f',
        'χ' => 'x', 'ψ' => 'ps', 'ω' => 'w', 'ά' => 'a', 'έ' => 'e', 'ί' => 'i',
        'ό' => 'o', 'ύ' => 'y', 'ή' => 'h', 'ώ' => 'w', 'ς' => 's',
        'ϊ' => 'i', 'ΰ' => 'y', 'ϋ' => 'y', 'ΐ' => 'i',

        # Turkish
        'Ş' => 'S', 'İ' => 'I', 'Ç' => 'C', 'Ü' => 'U', 'Ö' => 'O', 'Ğ' => 'G',
        'ş' => 's', 'ı' => 'i', 'ç' => 'c', 'ü' => 'u', 'ö' => 'o', 'ğ' => 'g',

        # Russian/Cyrillic
        'А' => 'A', 'Б' => 'B', 'В' => 'V', 'Г' => 'G', 'Д' => 'D', 'Е' => 'E',
        'Ё' => 'Yo', 'Ж' => 'Zh', 'З' => 'Z', 'И' => 'I', 'Й' => 'J',
        'К' => 'K', 'Л' => 'L', 'М' => 'M', 'Н' => 'N', 'О' => 'O', 'П' => 'P',
        'Р' => 'R', 'С' => 'S', 'Т' => 'T', 'У' => 'U', 'Ф' => 'F', 'Х' => 'H',
        'Ц' => 'C', 'Ч' => 'Ch', 'Ш' => 'Sh', 'Щ' => 'Sh', 'Ъ' => '', 'Ы' => 'Y',
        'Ь' => '', 'Э' => 'E', 'Ю' => 'Yu', 'Я' => 'Ya', 'а' => 'a', 'б' => 'b',
        'в' => 'v', 'г' => 'g', 'д' => 'd', 'е' => 'e', 'ё' => 'yo', 'ж' => 'zh',
        'з' => 'z', 'и' => 'i', 'й' => 'j', 'к' => 'k', 'л' => 'l', 'м' => 'm',
        'н' => 'n', 'о' => 'o', 'п' => 'p', 'р' => 'r', 'с' => 's', 'т' => 't',
        'у' => 'u', 'ф' => 'f', 'х' => 'h', 'ц' => 'c', 'ч' => 'ch', 'ш' => 'sh',
        'щ' => 'sh', 'ъ' => '', 'ы' => 'y', 'ь' => '', 'э' => 'e', 'ю' => 'yu',
        'я' => 'ya',

        # Ukrainian
        'Є' => 'Ye', 'І' => 'I', 'Ї' => 'Yi', 'Ґ' => 'G',
        'є' => 'ye', 'і' => 'i', 'ї' => 'yi', 'ґ' => 'g',

        # Czech
        'Č' => 'C', 'Ď' => 'D', 'Ě' => 'E', 'Ň' => 'N', 'Ř' => 'R', 'Š' => 'S',
        'Ť' => 'T', 'Ů' => 'U', 'Ž' => 'Z', 'č' => 'c', 'ď' => 'd', 'ě' => 'e',
        'ň' => 'n', 'ř' => 'r', 'š' => 's', 'ť' => 't', 'ů' => 'u', 'ž' => 'z',

        # Polish
        'Ą' => 'A', 'Ć' => 'C', 'Ę' => 'e', 'Ł' => 'L', 'Ń' => 'N', 'Ó' => 'o',
        'Ś' => 'S', 'Ź' => 'Z', 'Ż' => 'Z', 'ą' => 'a', 'ć' => 'c', 'ę' => 'e',
        'ł' => 'l', 'ń' => 'n', 'ó' => 'o', 'ś' => 's', 'ź' => 'z',
        'ż' => 'z',

        # Latvian
        'Ā' => 'A', 'Č' => 'C', 'Ē' => 'E', 'Ģ' => 'G', 'Ī' => 'i', 'Ķ' => 'k',
        'Ļ' => 'L', 'Ņ' => 'N', 'Š' => 'S', 'Ū' => 'u', 'Ž' => 'Z', 'ā' => 'a',
        'č' => 'c', 'ē' => 'e', 'ģ' => 'g', 'ī' => 'i', 'ķ' => 'k', 'ļ' => 'l',
        'ņ' => 'n', 'š' => 's', 'ū' => 'u', 'ž' => 'z'
	);

    return %char-map{$char}:exists ?? %char-map{$char} !! $char;
}

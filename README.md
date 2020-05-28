NAME
====



`Text::Slugify` - create a URL slug from text.

SYNOPSIS
========



```perl6
    use Text::Slugify;

    my $txt;

    $txt = "This is a test ---";
    slugify $txt; 
    #=> «this-is-a-test»

    $txt = 'C\'est déjà l\'été.';
    slugify $txt;
    #=> «c-est-deja-l-ete»

    $txt = 'jaja---lol-méméméoo--a';
    slugify $txt, :max-length(9);
    #=> «jaja-lol»
```

For more examples, have a look at the test file (`t/basic.t6`).

DESCRIPTION
===========



`Text::Slugify` is a module to slugify text. It takes a piece of text, removes punctuation, spaces and other unwanted characters to produce a string suitable for use in a URL.

INSTALLATION
============



Using zef:
----------

    zef update && zef install Text::Slugify

From source:
------------

    git clone https://github.com/khalidelboray/raku-text-slugify.git
    cd raku-text-slugify && zef install .

SUBROUTINES
===========



The module exports the following subroutines:

#### `slugify`

```perl6
    sub slugify(
        Str:D $text is copy,            # Text to be slugified.
        Int:D :$max-length = 0,         # Output string length.
        :$separator = "-",              # Separator between words.
        :$regex-pattern = Nil,          # Regex pattern for allowed characters in output text.
        :@stopwords = [],               # Words to be discounted from output text.
        :@replacements = [],            # List of replacement rule pairs e.g. ['|'=>'or', '%'=>'percent']
        Bool:D :$entities = True, 
        Bool:D :$decimal = True, 
        Bool:D :$hexadecimal = True, 
        Bool:D :$word-boundary = False, 
        Bool:D :$lowercase = True,      # Set case sensitivity by setting it to False.
        Bool:D :$save-order = False,    # If True and max-length > 0 return whole words in the initial order.
    )
```

#### `smart-truncate`

```perl6
    sub smart-truncate(
        Str:D $string is rw,             # String to be modified.
        Int:D :$max-length = 0,          # Output string length.
        Bool:D :$word-boundary = False,  
        Str:D :$separator = " ",         # Separator between words.
        Bool:D :$save-order = False,     # Output text's word order same as input.
    )
```

**NOTE**: To import the subroutine `smart-truncate` or `strip` alongside `slugify` into your code, use `use Text::Slugify :ALL`.

CREDIT-REFERENCE
================



This module is mostly based on [Python Slugify](https://github.com/un33k/python-slugify).

This is my fork of [https://gitlab.com/uzluisf/raku-text-slugify](https://gitlab.com/uzluisf/raku-text-slugify)

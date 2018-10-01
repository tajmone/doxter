# Highlight.js v9.12.0

    PureBASIC 5.00–5.60

This folder contain a pre-built version of **highlight.js**' «PureBASIC enhanced/modded release», with some other languages.


-----

**Table of Contents**

<!-- MarkdownTOC autolink="true" bracket="round" autoanchor="false" lowercase="only_ascii" uri_encoding="true" levels="1,2,3" -->

- [Highlight.js](#highlightjs)
    - [Included Languages](#included-languages)
    - [Included Color Themes](#included-color-themes)
    - [License](#license)
- [PureBASIC & Highlight.js](#purebasic--highlightjs)

<!-- /MarkdownTOC -->

-----


# Highlight.js

- https://highlightjs.org
- https://github.com/isagalaev/highlight.js

Highlight.js is a syntax highlighter written in JavaScript. It works in the browser as well as on the server. It works with pretty much any markup, doesn't depend on any framework and has automatic language detection.

Since version 9.4.0 (2016-05-17), it includes PureBASIC syntax and theme files.

## Included Languages

The custom highlight.js build contains the following languages:

- __PureBasic__ — by Tristano Ajmone
- __AsciiDoc__ — by Dan Allen

## Included Color Themes

- [`styles/github.min.css`](styles/github.min.css)

This stylesheet contains some custom highlight.js themes to colorize each language differently:

- __PureBasic__ — native color scheme of [PureBasic IDE].
- __AsciiDoc__ — [Base16 Eighties], by Chris Kempson, taken from his Base16 project (MIT License).


## License

Highlight.js was created by Ivan Sagalaev [@isagalaev](https://github.com/isagalaev) – Copyright (c) 2006 – and is released under the BSD License. See [`LICENSE`](LICENSE) file for details.

# PureBASIC & Highlight.js

I've created the PureBASIC syntax files for highlight.js:

- https://github.com/tajmone/highlight.js

These are included in HLJS since v9.4.0.

There is also an unofficial “PureBASIC enhanced/modded release”, which emulates 100% the PureBASIC native IDE syntax coloring — maintained on a separate fork because it doesn't comply to the highlight.js guidelines:

- [https://github.com/tajmone/highlight.js/tree/PureBASIC](https://github.com/tajmone/highlight.js/blob/PureBASIC/PureBASIC_README.md)

More info about this fork can be found at:

- https://github.com/tajmone/purebasic-archives/tree/master/syntax-highlighting/highlight.js/pb-prebuilt


<!-----------------------------------------------------------------------------
                               REFERENCE LINKS                                
------------------------------------------------------------------------------>

[Base16 Eighties]: https://github.com/chriskempson/base16-builder/blob/master/schemes/eighties.yml
[PureBasic IDE]: https://www.purebasic.com/

<!-- EOF -->

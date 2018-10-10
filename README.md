# Doxter, A PureBasic Documentation Generator

    doxter v0.2.1-alpha (2018/10/10) | PureBasic 5.62 | MIT License

Welcome to Doxter, a Documentation from source generator written in PureBasic for [PureBasic], [SpiderBasic] and [Alan IF] (more languages coming soon).

- https://github.com/tajmone/doxter

![Doxter Logo][Doxter Logo]

For the documentation, see:

- [`docs/index.html`](./docs/index.html) — local link
- [git.io/doxter](https://git.io/doxter) — online docs via GitHub pages.

-----

**Table of Contents**

<!-- MarkdownTOC autolink="true" bracket="round" autoanchor="false" lowercase="only_ascii" uri_encoding="true" levels="1,2,3" -->

- [About Doxter](#about-doxter)
- [Acknowledgements](#acknowledgements)
- [License](#license)
- [Third Party Components](#third-party-components)
    - [Highlight.js](#highlightjs)

<!-- /MarkdownTOC -->

-----

# About Doxter

Doxter is a cross platform, fully standalone command line binary tool to generate AsciiDoc documentation from PureBasic, SpiderBasic or Alan source files.

Invoke Doxter by passing a source file of a supported language:

    > doxter myfile.pb

... Doxter will autodetect the language from its file extension, and it will create an AsciiDoc document from it, named `myfile.asciidoc` (or `myfile.ascidoc`).

It works its magic by a special notation in comments delimiters to markup tagged regions of text and code that should be extracted and exported to the AsciiDoc document.

```purebasic
;>even_macro
;| The following macro performs a bitwise AND operation to determine if an
;| integer is even or not.
Macro IsEven(num)
  (num & 1 = 0)  
EndMacro
;<
```

... in the output AsciiDoc document will become:

```adoc
// tag::even_macro[]
The following macro performs a bitwise AND operation to determine if an
integer is even or not.

[source,purebasic]
--------------------------------------------------------------------------------
Macro IsEven(num)
  (num & 1 = 0)  
EndMacro
--------------------------------------------------------------------------------

// end::even_macro[]
```

You can then selectively import tagged regions from the autogenerated doc into other documents, using [Asciidoctor's `include` directive][adr inc tag]: `include::myfile.asciidoc[tag=even_macro]`.
When documenting applications with modular design, you can selected regions from each module's doc file, and Doxter will automatically kept your documentation up to date.


You can optionally assign weights to regions, to control their order in the extracted document. Doxter sorts regions according to their tag's weight, before saving them to file.

```purebasic
;>even_macro(200)
;| The following macro performs a bitwise AND operation to determine if an
;| integer is even or not.
Macro IsEven(num)
  (num & 1 = 0)  
EndMacro
;<

;>macro_test(310)
;| Let's test that the macro actually works as expected.
For i = 1 To 5
  If isEven(i)
    Debug Str(i) +" is even."
  Else
    Debug Str(i) +" is odd."
  EndIf
Next
;<

;>even_macro_intro(100)
;| === The IsEven Macro
;| 
;| Using bitwise operations insted of modulo (`%`) is much _much_ faster -- in
;| the order of hundreds of times faster! 
;<
;>even_macro_explain(300)
;| This works because `IsEven = ((i % 2) = 0)` equals `IsEven = ((i & 1) = 0)`.
;<
```

In the final document the regions will be sorted in this order:

```adoc
// tag::even_macro_intro[]
=== The IsEven Macro

Using bitwise operations insted of modulo (`%`) is much _much_ faster -- in
the order of hundreds of times faster! 
// end::even_macro_intro[]

// tag::even_macro[]
The following macro performs a bitwise AND operation to determine if an
integer is even or not.

[source,purebasic]
--------------------------------------------------------------------------------
Macro IsEven(num)
  (num & 1 = 0)  
EndMacro
--------------------------------------------------------------------------------

// end::even_macro[]

// tag::even_macro_explain[]
This works because `IsEven = ((i % 2) = 0)` equals `IsEven = ((i & 1) = 0)`.
// end::even_macro_explain[]

// tag::macro_test[]
Let's test that the macro actually works as expected.

[source,purebasic]
--------------------------------------------------------------------------------
For i = 1 To 5
  If isEven(i)
    Debug Str(i) +" is even."
  Else
    Debug Str(i) +" is odd."
  EndIf
Next
--------------------------------------------------------------------------------

// end::macro_test[]
```

This brief introductory tour ends here.
To discover the full list of Doxter's features, see the autogenerated [user guide][Doxter Web].

# Acknowledgements

Although quite different in design, Doxter was inspired by Lou Acresti’s [Cod], an unassuming doc format (_Documentus modestus_)  —  the simplicity of Cod sparkled the idea that I could implement something similar, but exploiting AsciiDoc tagged regions instead.

My gratitude to [Lou Acresti] (aka [@namuol]) for having created such an inspiring tool like Cod.


# License

- [`LICENSE`](./LICENSE)

Doxter is released under MIT License.

    MIT License

    Copyright (c) 2018 Tristano Ajmone
    https://github.com/tajmone/doxter

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.


# Third Party Components

This repository also contains the third party components listed below, which retain their own license.

## Highlight.js

- [`docs/hjs/`](./docs/hjs/)

The above folder contains a custom release of [Highlight.js], with a modified version of the PureBasic syntax (original and modified versions by Tristano Ajmone) and some other languages.

Highlight.js is Copyright (C) by Ivan Sagalaev [@isagalaev], 2006, and is released under the [BSD License][hljs license].

For more details see [`docs/hjs/README.md`](./docs/hjs/README.md).


<!-----------------------------------------------------------------------------
                               REFERENCE LINKS                                
------------------------------------------------------------------------------>


[Doxter Web]: https://git.io/doxter "Read Doxter's user guide"

<!-- Project Files -->

[Doxter Logo]: ./doxter_logo.svg "Doxter Logo"
[hljs license]: ./docs/hjs/LICENSE "View Highlight.js license"

<!-- Asciidoctor -->

[adr inc tag]: https://asciidoctor.org/docs/user-manual/#by-tagged-regions "See Asciidoctor documentation on how to `include` tagged regions"

<!-- 3rd Parties Links -->

[Highlight.js]: https://highlightjs.org
[@isagalaev]: https://github.com/isagalaev

[Cod]: http://lou.wtf/cod/ "Visit Cod's website"
[Lou Acresti]: http://lou.wtf/ "Visit Lou Acresti's website"
[@namuol]: https://github.com/namuol "Visit Lou Acresti's GitHub profile"

[PureBasic]: https://www.purebasic.com/ "Visit PureBasic's website"
[SpiderBasic]: https://www.spiderbasic.com/ "Visit SpiderBasic's website"
[Alan IF]: https://www.alanif.se/ "Visit Alan's website"

<!-- EOF -->

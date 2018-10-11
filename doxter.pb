;= Doxter: A Docs from Sources Generator.
;| Tristano Ajmone, <tajmone@gmail.com>
;| v0.2.2-alpha, October 11, 2018: Public Alpha
;| :License: MIT License
;| :PureBASIC: 5.62
;~------------------------------------------------------------------------------
;| :toclevels: 3
#DOXTER_VER$ = "0.2.2-alpha"
;{******************************************************************************
; ··············································································
; ······························ PureBasic Doxter ······························
; ··············································································
; ******************************************************************************
; AsciiDoc documentation generator from annoted PB source files.

;>description(1)
;| =============================================================================
;| image::doxter_logo.svg[Doxter Logo,align="center"]
;|
;| Doxter is a binary tool to generate AsciiDoc documentation from  source
;| files, by using a special notations in comments delimiters to markup tagged
;| regions of text and code that will be exported to an AsciiDoc source document
;| where the various regions will be sorted according to their tag's weight.
;| It currently supports PureBasic, SpiderBasic and Alan IF source files.
;| Released under <<License,MIT License>>.
;| 
;| https://github.com/tajmone/doxter
;| =============================================================================
;<
;}******************************************************************************
; *                                                                            *
;-                                    SETUP
; *                                                                            *
;{******************************************************************************
XIncludeFile "doxter_engine.pbi"
;}******************************************************************************
; *                                                                            *
;-                                  MAIN BODY
; *                                                                            *
;{******************************************************************************

OpenConsole()
PrintN(#Empty$) ; Add empty line to leave prompt behind...

; ==================
; Print Version Info
; ==================
PrintN("Doxter v" + #DOXTER_VER$)


; ==========================
; Get Command Line Parameter
; ==========================
SrcFile.s = ProgramParameter()
;{>CLI_Usage(.10)--------------------------------------------------------------
;|=== Command Line Options
;|
;| To invoke Doxter via command prompt/shell:
;|
;|--------------------
;| doxter <sourcefile>
;|--------------------
;|
;| … where `<sourcefile>` is a source of one of the languages supported by Doxter
;| (PureBasic, SpiderBasic or Alan).
;}<-----------------------------------------------------------------------------

If SrcFile = #Empty$
  dox::Abort("You must supply a filename")
EndIf

;  ===============================
;- Check that source file is valid
;  ===============================
;{>Input_File_Validation(3300)--------------------------------------------------
;| === Input File Validation
;|
;| Doxter checks that the passed `<sourcefile>` parameter has a valid extension,
;| and then sets the Doxter Engine language accordingly:
;|
;| [horizontal]
;| `pb`, `pbi`, `pbf` :: -> PureBasic
;| `sb`, `sbi`, `sbf` :: -> SpiderBasic
;| `alan`, `i`        :: -> Alan
;|
;| If the file extension doesn't match any of the supported extensions, Doxter
;| will report an error and abort with Status Error 1.
;}<-----------------------------------------------------------------------------
SrcExt.s = GetExtensionPart(SrcFile)

Select LCase(SrcExt)
  Case "pb", "pbi", "pbf"
    ; dox::SetEngineLang("PureBasic")
    currLang.s = "PureBasic"
  Case "sb", "sbi", "sbf"
    ; dox::SetEngineLang("SpiderBasic")
    currLang.s = "SpiderBasic"
  Case "alan", "i"
    ; dox::SetEngineLang("Alan")
    currLang.s = "Alan"
  Default
    dox::Abort(~"Invalid file extension \"."+ SrcExt +~"\".\nCurrently only PureBasic, SpiderBasic and Alan source files are supported.")
EndSelect

PrintN("Source language detected: "+ currLang)
dox::SetEngineLang(currLang)

;{>Input_File_Validation -------------------------------------------------------
;| Doxter will also check that the file exists, it's not a directory, and it's
;| not 0 Kb in size; and abort with Status Error if any of these are met.
;}<-----------------------------------------------------------------------------
Select FileSize(SrcFile)
  Case 0
    dox::Abort(~"File is 0 Kb: \""+ SrcFile +~"\"")
  Case -1
    dox::Abort(~"File not found: \""+ SrcFile +~"\"")
  Case -2
    dox::Abort(~"Parameter is a directory: \""+ SrcFile +~"\"")
EndSelect ;}


dox::ParseFile(SrcFile)

; TODO: Resume Info: Make info available through some public vars instead of
;       exposing RegionsL() and HeaderL(), so these can be made private to
;       the module.
;  =================
;- Print Resume Info
;  =================
totRegions = ListSize(dox::RegionsL())
PrintN("Total tagged regions found: "+ Str(totRegions))

If ListSize(dox::HeaderL())
  ; ----------------------------
  ; Document Has AsciiDoc Header
  ; ----------------------------
  ;{>Output_File(3330)
  ;|
  ;| Depending on whether the source file contains or not an <<AsciiDoc Header>>,
  ;| the output file will be named either `<sourcefile>.asciidoc` or
  ;| `<sourcefile>.adoc`, respectively.
  ;| At parsing completion, Doxter will inform the user wther it found a Header
  ;| or not, and print the output filename to the console.
  ;|
  ;| This differentiation in the extension used in the output file is due to
  ;| the conventions and needs of the PureBasic CodeArchiv project, where files
  ;| with `.asciidoc` extension are considered stand-alone documents, which are
  ;| subject to script-automated conversion to HTML; whereas files with `.adoc`
  ;| extension are considered snippets file which are imported by other docs.
  ;| Beside the different file extensions, both type of output files are formated
  ;| as standard AsciiDoc documents (with Asciidoctor Ruby in mind).
  ;|
  ;| This is inline with the AsciiDoc standard which demands the presence of a
  ;| document Header in a source file for it to be buildable as a standalone
  ;| doc; and with the common practice of splitting large documents in smaller
  ;| files, which are then imported into the main document and therefore don't
  ;| need a Header of their own.
  ;}<---------------------------------------------------------------------------
  DocHeader = #True
  Print("Document has Header, ")
  ; use ".asciidoc" extension for standalone docs in CodeArchiv
  OutExt.s = "asciidoc"
Else
  Print("Document dosesn't contain a Header, ")
  OutExt.s = "adoc"
EndIf
PrintN(~"it will be saved with \"." + OutExt +~"\" extension.")

SrcExtPos =  Len(SrcFile) - Len(SrcExt)
OutFile.s = ReplaceString(SrcFile, SrcExt, OutExt, #PB_String_CaseSensitive, SrcExtPos)

PrintN("outfile: " + OutFile)

;  ================
;- Save Output File
;  ================
dox::SaveDocFile(OutFile)

;- Wrap-up and Exit
CloseConsole()
End 0


;}******************************************************************************
; *                                                                            *
;-                                DOCUMENTATION
; *                                                                            *
;{******************************************************************************

; ==============================================================================
; 1000                                INTRO
;{==============================================================================

;>intro(1000.1)
;| :api-docs: doxter_engine.asciidoc

;| == About Doxter

;| Doxter was conceived as a practical solution to simplify management of source code
;| documentation. Specifically, it's birth and growth are tied to the
;| https://github.com/tajmone/PBCodeArcProto[development of prototype tools^] for
;| the https://github.com/SicroAtGit/PureBasic-CodeArchiv-Rebirth[PureBasic-CodeArchiv-Rebirth^]
;| project, which has challenged me in keeping the documentation of multiple
;| modules always up to date with their current code.

;| Working on separate documentation and source code files is both tiring and a
;| cause of redundancy -- you'll need to include some documentation in the source
;| file comments, and you also need to include some code excerpts in the documentation.
;| Why duplicate the effort when you can keep it all in one place?

;| Code generators are not a new idea (and surely, not my original idea either);
;| there are plenty of code generator tools and frameworks out there, but most
;| of them are not language agnostic, don't integrate well with PureBasic, or
;| require a complex setup envolving lot's of dependencies.

;| Doxter was originally designed to work with PureBasic, leveraging the power
;| of AsciiDoc and with simplicity in mind. It now supports SpiderBasic and Alan
;| IF sources too and, ultimately, it will be become a language agnostic tool
;| usable with almost any language.

;<

;>who_needs(1100)

;| === Who Needs Doxter?

;| Any PureBasic or SpiderBasic programmer who knows AsciiDoc and wants to include
;| documentation of his/her code directly in the source files can benefit from
;| Doxter by automating the task of producing always up-to-date documentation
;| in various formats (HTML5, man pages, PDF, and any other output format supported
;| by Asciidoctor's backends).
;<

;>doxter_engine(1200)


;| === Doxter's Engine


;| At the core of the command line Doxter tool lies the Doxter Engine, which is
;| available as an independent module that can be used other applications too.

;| For more information see the
;| <<{api-docs}#,_Doxter Engine API Documentation_>>.
;<


;>acknowledgements(1300)

;| === Acknowledgements

;| Although quite different in design, Doxter was inspired by Lou Acresti's
;| http://lou.wtf/cod/[Cod^], an unassuming doc format (_Documentus modestus_)
;| -- the simplicity of Cod sparkled the idea that I could implement something
;| similar, but exploiting AsciiDoc tagged regions instead.

;| My gratitude to http://lou.wtf/[Lou Acresti^] (aka https://github.com/namuol[@namuol^])
;| for having created such an inspiring tool like Cod.
;<

;}==============================================================================
; 2000                               Features
;{==============================================================================
;>Features(2000)
;| == Features

;| Doxter is a command line tool that parses a source file and extracts from it
;| tag-delimited regions of code, these regions are then processed according to
;| some very simple rules in order to produce a well formed AsciiDoc source
;| document which can then be converted to HTML via Asciidoctor (Ruby).

;| === Cross Documents Selective Inclusions
;|

;| Every tagged region in the source file becomes an AsciiDoc tagged region in
;| the output document. The following PureBasic source comments contain a simple
;| Doxter region:

;| [source,purebasic]
;| -----------------------------------------------------------------------------
;| ;>
;| ;| I'm a Doxter _region_. 
;| ;<
;| -----------------------------------------------------------------------------

;| \... which, in the final document, Doxter will render as AsciiDoc:

;| [source,asciidoc]
;| -----------------------------------------------------------------------------
;| // tag::region1[]
;| I'm a Doxter _region_.
;| 
;| // end::region1[]
;| -----------------------------------------------------------------------------


;| Regions can be named in the source file, by providing an identifier after the
;| `;>` marker, allowing you to control regions' tag names in the AsciiDoc output:

;| [source,purebasic]
;| -----------------------------------------------------------------------------
;| ;>intro
;| ;| == Introduction
;| ;| 
;| ;| This a _named_ region.
;| ;<
;| -----------------------------------------------------------------------------

;| [source,asciidoc]
;| -----------------------------------------------------------------------------
;| // tag::intro[]
;| == Introduction
;| 
;| This a _named_ region.
;| 
;| // end::intro[]
;| -----------------------------------------------------------------------------


;| This is a very practical feature for it allows other AsciiDoc documents to
;| selectively include parts of a source file's documentation using tag filtering.

;| For example, when documenting an application that relies on imported Modules,
;| the main document can selectively include regions from the Doxter-generated
;| modules' documentation, thus allowing to maintain both independent documentation
;| for every Module's API, as well as having a main document that extrapolates
;| parts from the modules' docs in a self-updating fashion.

;| === _Ordo ab Chao_: Structured Docs from Scattered Comments
;|
;| Each tagged region in the source file can be assigned a weight, so that in the
;| final document the regions will be reordered in a specific way, forming a well
;| structured document that presents contents in the right order.

;| [source,purebasic]
;| -----------------------------------------------------------------------------
;| ;>sec1(200)
;| ;| == Section One
;| ;| 
;| ;| And this is Sec 1.
;| ;<
;| For i= 1 To 10 
;|   Debug "i = " + Str(i)
;| Next
;| ;>premise(100)
;| ;| == Premise
;| ;| 
;| ;| This is an opening premise.
;| ;<
;| -----------------------------------------------------------------------------

;| [source,asciidoc]
;| -----------------------------------------------------------------------------
;| // tag::premise[]
;| == Premise
;| 
;| This is an opening premise.
;| 
;| // end::premise[]
;| // tag::sec1[]
;| == Section One
;| 
;| And this is Sec 1.
;| 
;| // end::sec1[]
;| -----------------------------------------------------------------------------


;| This feature allows to keep each paragraph near the code lines that it
;| discusses, making the source code more readable and freeing the documentation
;| from the constraints imposed by the order in which the code is organized.
;|

;| Furthermore, regions with same tag names in the source code will be merged
;| into a single region in the final document. Each region's fragment (aka
;| subregion) can be assigned a subweight which will be used to sort the order of
;| the fragments before merging them together. This allows you to control the
;| number of regions in the final document, and keep related topics under a same
;| region.

;| In the following example:

;| [source,purebasic]
;| -----------------------------------------------------------------------------
;| ;>even_macro_intro(.2)
;| ;| The following macro performs a bitwise AND operation to determine if an
;| ;| integer is even or not.
;| Macro IsEven(num)
;|   (num & 1 = 0)  
;| EndMacro
;| ;<
;| 
;| ;>macro_test(200)
;| ;| Let's test that the macro actually works as expected.
;| For i = 1 To 5
;|   If isEven(i)
;|     Debug Str(i) +" is even."
;|   Else
;|     Debug Str(i) +" is odd."
;|   EndIf
;| Next
;| ;<
;| 
;| ;>even_macro_intro(100.1)
;| ;| === The IsEven Macro
;| ;| 
;| ;| Using bitwise operations insted of modulo (`%`) is much _much_ faster -- in
;| ;| the order of hundreds of times faster! 
;| ;<
;| ;>even_macro_intro(.3)
;| ;| This works because `IsEven = ((i % 2) = 0)` equals `IsEven = ((i & 1) = 0)`.
;| ;<
;| -----------------------------------------------------------------------------

;| \... all the regions named `even_macro_intro` are merged into a single region
;| after being sorted according to ther subeweights (`.1`, `.2` and `.3`):

;| [source,asciidoc]
;| -----------------------------------------------------------------------------
;| // tag::even_macro_intro[]
;| === The IsEven Macro
;| 
;| Using bitwise operations insted of modulo (`%`) is much _much_ faster -- in
;| the order of hundreds of times faster! 
;| 
;| The following macro performs a bitwise AND operation to determine if an
;| integer is even or not.
;| 
;| [source,purebasic]
;| --------------------------------------------------------------------------------
;| Macro IsEven(num)
;|   (num & 1 = 0)  
;| EndMacro
;| --------------------------------------------------------------------------------
;| 
;| 
;| This works because `IsEven = ((i % 2) = 0)` equals `IsEven = ((i & 1) = 0)`.
;| 
;| // end::even_macro_intro[]
;| // tag::macro_test[]
;| Let's test that the macro actually works as expected.
;| 
;| [source,purebasic]
;| --------------------------------------------------------------------------------
;| For i = 1 To 5
;|   If isEven(i)
;|     Debug Str(i) +" is even."
;|   Else
;|     Debug Str(i) +" is odd."
;|   EndIf
;| Next
;| --------------------------------------------------------------------------------
;| 
;| 
;| // end::macro_test[]
;| -----------------------------------------------------------------------------

;|
;| Keep your comments next to the code they belong to, allowing the source file
;| to follow its natural course and provide meaningful snippets of in-code
;| documentation, and use weighed tag regions to ensure that these out-of-order
;| fragments will be collated in a meaningful progressive order in the output
;| document.

;| === Mix Text and Source Code in Your Documentation
;|

;| Regions can contain both of AsciiDoc comments markers and source code, allowing
;| to include fragments of the original source code in the final documentation,
;| along with AsciiDoc text.

;|

;| AsciiDoc markers are comment lines with special symbols after the native
;| language's comment delimiters, which will be treated as normal comments by the
;| source language, but which Doxter will strip of the comment delimiter and turn
;| into AsciiDoc lines in the output document.

;|
;| Any source code (i.e. non-AsciiDoc comments) inside a tagged region will be
;| rendered in the final document as an AsciiDoc source code block set to the
;| source's language (e.g. PureBasic).

;| [source,purebasic]
;| -----------------------------------------------------------------------------
;| ;>macro_test(200)
;| ;| Let's test that the macro actually works as expected.
;| For i = 1 To 5
;|   If isEven(i)
;|     Debug Str(i) +" is even."
;|   Else
;|     Debug Str(i) +" is odd."
;|   EndIf
;| Next
;| ;<
;| -----------------------------------------------------------------------------


;| [source,asciidoc]
;| -----------------------------------------------------------------------------
;| // tag::macro_test[]
;| Let's test that the macro actually works as expected.
;| 
;| [source,purebasic]
;| --------------------------------------------------------------------------------
;| For i = 1 To 5
;|   If isEven(i)
;|     Debug Str(i) +" is even."
;|   Else
;|     Debug Str(i) +" is odd."
;|   EndIf
;| Next
;| --------------------------------------------------------------------------------
;| 
;| 
;| // end::macro_test[]
;| -----------------------------------------------------------------------------

;<

;}==============================================================================
; 3000                          COMMAND LINE USAGE
;{==============================================================================

;>CLI_Usage(3000)
;| == Command Line Usage
;|
;| Doxter is a binary console application (a compiled executable).
;| There is no installation, just place the binary file (`Doxter.exe` on Windows)
;| in your working folder, or make it availabe system-wide by adding it to the
;| system `PATH` environment variable.
;<

; * CLI_Usage             |    |  10| === Command Line Options
; * Input_File_Validation |3300|   1| === Input File Validation [extensions]
; * Input_File_Validation |    |auto|     [check file exists, is not dir or 0kb]
; * Output_File           |3330|   1|     [output file depending on AsciiDoc header]

; * Parser_Live_Preview   |3500|    | === Parsing Live Preview During Execution
;>Parser_Live_Preview(3500)
;| include::doxter_engine.asciidoc[tag=Parser_Live_Preview]
;<

;}==============================================================================
; 4000                         DOCUMENTING HOW-TOS
; ==============================================================================

;>Documenting_Source(4000)
;| == Documenting Your Source Files
;|
;| Now comes the juicy part, how to incorporate documentation into you source
;| files. The good news is that the system employed by Doxter is very easy to
;| learn and simple to use.
;|
;<

; * Comments_Marks |4100| === Doxter Markers Primer
;>Comments_Marks(4100)
;| include::doxter_engine.asciidoc[tag=Comments_Marks,leveloffset=+1]
;<

;>Comments_Marks_Considerations(4110)
;| That's about all you'll have to learn: memorize those five base symbols, their
;| variants and modifiers, and learn how to use them correctly and wisely.
;|
;| Doxter is a "`dumb`" tool -- it doesn't try to interpret or validate what
;| comes after these markers, it just uses them to delimit and manipulate lines
;| from your source file according to some simple predefined rules.
;| It's your responsibility to ensure that the contents of the tagged regions
;| are AsciiDoc compliant.
;|
;| But as you shall see, these five simple markers empower you with great freedom
;| to document your source code. Thanks to some simple rules devised on common
;| sense expectations of how text and source code should blend in documentation,
;| Doxter will parse smartly your source files, with little effort on your side.
;<

; ------------------------------------------------------------------------------
; 4200                              THE PARSER
; ------------------------------------------------------------------------------
;>The_Parser(4200)
;| === Doxter's Parser
;|
;| Understanding how Doxter's parser works will help you grasp a clearer picture
;| of how source files are processed, and gain insight into the proper use of
;| its markers.
;| You can read a full dscription of the parser's workflow in the
;| <<doxter_engine#_doxters_parser,__Doxter's Parser__ section>> of Doxter Engine's
;| documentation.
;| For the time being, you should just bare in mind a couple of things.
;| 
;| include::doxter_engine.asciidoc[tag=two_steps_parsing]
;| 
;| Each of these parsers obeys its own rules, and the way they interpret the
;| comment markers (or ignore them) is slightly different.
;| What you should keep in mind is that the two parsers are independent from
;| each other, and so are their rules.
;<


; ------------------------------------------------------------------------------
; 4300                           ASCIIDOC HEADER
; ------------------------------------------------------------------------------
;{>DocHeader(4300)
;|
;| === AsciiDoc Header
;|
;| The very first line in your source code is special for Doxter.
;| The Header Parser will look if it starts with a `;=`. This marker is the
;| telltale sign for Doxter that the first lines contain an AsciiDoc Header.
;| Here's an example from the very source of Doxter:
;|
;| [source,purebasic]
;| -------------------------------
;| include::Doxter.pb[lines=1..12]
;| -------------------------------
;|
;| As you can easily guess by looking at the first 4 lines in the above code,
;| these represent a standard AsciiDoc Header, followed by custom attributes
;| (`:License: MIT License` and `:PureBASIC: 5.62`), a Skip line (ignored by Doxter)
;| used as horizontal ruler divider, and an Asciidoctor settings attribute
;| (`:toclevels: 3`).
;| Everything is as it would be in a normal AsciiDoc Header, except that the Header
;| lines are inside PureBasic comments. 
;| The remaining lines are just normal (non-Doxter) PB code and comments.
;|
;| When Doxter encounters a `;=` on the very first line, it will then parse
;| all consecutive lines starging by `;|` (the ADoc comment marker) as part of
;| the Header, adding it to the stored Header data.
;| Lines starting with `~|` (the Skip comment marker) are simply ignored, and
;| they are not considered as the end of a Header.
;| As soon as line not starting by `;|` or `~|` is encountered, Doxter will
;| stop parsing the Header.
;|
;| Separate handling of the Header is important for two reasons:
;|
;| 1. Documents which don't contain an AsciiDoc Header will not be treated as
;|    standalone documents (and saved with `.adoc` extension).
;| 2. The Header lines must always be injected at the very beginning of the
;|    output file, before any of the tagged regions extracted from the source
;|    file (and regardless of their weights).
;|
;| The latter point is important because it's in compliance with how AsciiDoc
;| looks for a Header in source files.
;|
;| Whether or not Doxter found and Header in the source file, once it has dealt
;| with it it will carry on to the next parsing stage: scanning the source for
;| tagged regions. The Header and Regions parsers are two distinct parsers
;| that coexist in Doxter, and the latter takes on where the former left.
;|
;| [NOTE]
;| ========================
;| The Header parser doesn't consume those lines that didn't match its criteria,
;| and as soon as it encounters a non Header line it rolls back the parser
;| to the last file position, so that the regions parser can parse them instead.
;| ========================
;}<

; ------------------------------------------------------------------------------
; 4400                            REGIONS HOWTO
; ------------------------------------------------------------------------------
;{>Working_With_Regions(4400)
;|
;| === Working With Regions
;|
;| The full syntax of a Tag Region Begin mark is:
;|
;| --------------------------
;| ;>tagname(<region weight>.<region subweight>)
;| --------------------------
;|
;}<---------------------------------------------------------------------------

;{>WIP(4999)
;| == To Be Continued...
;|
;| [WARNING]
;| ============
;~ _To be continuted_ ...
;| The documentation is not complete yet, as it lacks the part on practical examples.
;|
;| The provided documentation should be enough to get started using Doxter; for
;| examples, study its source code in the mean time, and _use it_, _use it_, and
;| _use it again_, for it's easier to use than it might seem by reading its
;| documentation.
;| Also, by using it you can benefit from the
;| <<Parsing Live Preview During Execution,live parsing preview log>>, which is
;| an invaluable tool for learning.
;| ============
;}<

;{>LICENSE(9000)
;| == License
;| 
;| =============================================================================
;| MIT License
;| 
;| Copyright (c) 2018 Tristano Ajmone +
;| https://github.com/tajmone/doxter
;| 
;| Permission is hereby granted, free of charge, to any person obtaining a copy
;| of this software and associated documentation files (the "Software"), to deal
;| in the Software without restriction, including without limitation the rights
;| to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;| copies of the Software, and to permit persons to whom the Software is
;| furnished to do so, subject to the following conditions:
;| 
;| The above copyright notice and this permission notice shall be included in all
;| copies or substantial portions of the Software.
;| 
;| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;| IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;| FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;| AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;| LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;| OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;| SOFTWARE.
;| =============================================================================
;}<


;}******************************************************************************
; *                                                                            *
;-                                    TODOs
; *                                                                            *
;{******************************************************************************
;>TODOs(10000)
;| == Roadmap
;|
;| Doxter it's still a young application, and there is always room for improvements.
;| Here is a list of upcoming features, waiting to be implemented.

;| * *Support More Languages*.
;~ 
;|    The ultimate goal is to make Doxter a language agnostic tool, usable with
;|    any language, by extending the set of natively supported languages and by
;|    allowing to specify via command line options a custom comment delimiter and
;|    set the default language name to be used in AsciiDoc source code blocks.

;| * *Configuration Files*.
;~ 
;|    When a `doxter.json` file is found in the current folder, Doxter will use
;|    it to extract options and settings to use when doxterizing sources. 
;|    Once this feature is implemented, it will open the door to more advanced
;|    features:

;| ** *Automated Documentation Tasks*.
;~ 
;|     If Doxter is invoked without specifying an input file, the settings file will
;|     be scanned to find "doxter tasks" -- i.e. a list of files which should be
;|     doxterized and (optionally) converted via Asciidoctor, allowing custom
;|     options and settings for both Doxter and Asciidoctor.
;|     This will allow to fully automate maintainance of Doxter documentation in
;|     projects.

;<
;}******************************************************************************
; *                                                                            *
;-                                  CHANGELOG
; *                                                                            *
; ******************************************************************************
;{>CHANGELOG(20000)
;| == Changelog
;|
;| * *v0.2.2-alpha* (2018/10/11) -- BUG FIX:
;| ** Corrupted filenames. A bug was corrupting output filenames of Alan source
;|    files with `.i` extension. Now fixed.
;| * *v0.2.1-alpha* (2018/10/10) -- Add Alan IF support.
;| ** Now Doxter will detect from the input file's extension whether it's a
;|    PureBasic, SpiderBasic or Alan IF source file, and set the comment delimiter
;|    and base language (to use in ADoc source blocks) accordingly.
;| ** The supported extensions, and associated languages now are:
;| *** `pb`, `pbi`, `pbf` -> PureBasic
;| *** `sb`, `sbi`, `sbf` -> SpiderBasic
;| *** `alan`, `i`        -> Alan
;| * *v0.2.0-alpha* (2018/10/03) -- Move Doxter Engine to separate module:
;| ** Now the core engine of Doxter is in a separate module, so that it will be
;|    usable by other applications too (still needs some fixes to be usable in
;|    non-console applications).
;| * *v0.1.4-alpha* (2018/10/01) -- Documentation:
;| ** AsciiDoc examples now syntax highlighted.
;| * *v0.1.3-alpha* (2018/09/29) -- Doxter engine improved:
;| ** PureBasic special comments markers (`;{`, `;}` and `;-`) can now be used
;|    in all Doxter markers, except ADoc Header (`;=`).
;| ** Regions merging feature introduced:
;| *** Tagged regions with same tag identifier are merged into a single region
;|      in the output document:
;| **** All region fragments will be sorted by subweight before merging.
;| *** Region subweight:
;| **** New subweight parameter (optional) introduced in Region Begin marker,
;|      (e.g. `;>tag(100.99`)` or `;>(.99)`, where subweight is `99`).
;| **** If the marker doesn't provide a subweight, the last subweight value used
;|      with that tag will be automatically employed after incrementing it by 1.
;| *** When a weightless Region Begin marker is encountered, if a region with
;|     the same tag already exists, that region's weight will be used for the
;|     new region fragment, otherwise it will be given weight 1.
;| *** If multiple weight definitions are given for a same region tag, the last
;|     one encountered will override the previous ones.
;| ** Parsing Live Preview now shows subweight in new third column.
;| * *v0.1.2-alpha* (2018/09/25) -- Aesthetic changes.
;| * *v0.1.1-alpha* (2018/09/25) -- Created Doxter repository on GitHub.
;| * *v0.1.0-alpha* (2018/09/21) -- First public released Alpha:
;| https://github.com/tajmone/PBCodeArcProto/blob/83c32cd/_assets/Doxter.pb
;}<

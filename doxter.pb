;= Doxter: A Docs from Sources Generator.
;| Tristano Ajmone, <tajmone@gmail.com>
;| v0.2.5-alpha, 2018-11-29: PureBASIC 5.62
;| :License: MIT License
;~------------------------------------------------------------------------------
;| :version-label: Doxter
;| :toclevels: 3
#DOXTER_VER$ = "0.2.5-alpha"
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
;{>CLI_Usage(3000.1)--------------------------------------------------------------
;| == Command Line Options
;|
;| To invoke Doxter via command prompt/shell:
;|
;| -------------------
;| doxter <sourcefile>
;| -------------------
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
;| == Input File Validation
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
  ;| Depending on whether the source file contains or not an {AsciiDoc_Header},
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

;}==============================================================================
; 3000                          COMMAND LINE USAGE
;{==============================================================================

; * CLI_Usage             |    |  10| === Command Line Options
; * Input_File_Validation |3300|   1| === Input File Validation [extensions]
; * Input_File_Validation |    |auto|     [check file exists, is not dir or 0kb]
; * Output_File           |3330|   1|     [output file depending on AsciiDoc header]
; * Parser_Live_Preview   |3500|    | === Parsing Live Preview During Execution

;>Parser_Live_Preview(3500)
;| include::doxter_engine.asciidoc[tag=Parser_Live_Preview]
;<

;}==============================================================================
; 0000                          CUSTOM ATTRIBUTES                               
; ==============================================================================
;>custom_attributes(0)            Some AsciiDoc attributes for cross references:
;~------------------------------------------------------------------------------
;| :AsciiDoc_Header: <<index.adoc#_asciidoc_header,AsciiDoc Header>>
;~------------------------------------------------------------------------------
;<

; ==============================================================================
;                                   CHANGELOG
; ==============================================================================
;>CHANGELOG(9999)
;| == CHANGELOG
;| include::../CHANGELOG.adoc[tag=DoxterCHANGELOG]
;<

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

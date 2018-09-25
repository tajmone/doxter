;= Doxter: Docs-Generator from PB Sources.
;| Tristano Ajmone, <tajmone@gmail.com>
;| v0.1.1-alpha, September 25, 2018: Public Alpha
;| :License: MIT License
;| :PureBASIC: 5.62
;~------------------------------------------------------------------------------
;| :toclevels: 3
#DOXTER_VER$ = "0.1.7"
;{******************************************************************************
; ··············································································
; ······························ PureBasic Doxter ······························
; ··············································································
; ******************************************************************************
; AsciiDoc documentation generator from annoted PB source files.

;>description(1)
;| =============================================================================
;| image::Doxter_logo.svg[Doxter Logo,align="center"]
;|
;| Doxter is a tool to generate AsciiDoc documentation from PureBasic source
;| files, by using a special notations in comments delimiters to markup tagged
;| regions of text and code that will be exported to an AsciiDoc source document
;| where the various regions will be sorted according to their tag's weight.
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
; ==============================================================================
;                                    Settings
;{==============================================================================
#SourceDelimiterLen = 80 ; ADoc Source Block delimiters lenght (chars).

#FallbackTag = "region" ; Fallback Tag Id to use when none is provided.

#LineNumDigits = 4 ; Used in Debug output: digits-width of line numbers.
#WeightsDigits = 4 ; Used in Debug output: digits-width of regions' weights.

;}==============================================================================
;                            Procedures Declarations
;{==============================================================================
Declare    ParseFile(SrcFileName.s)
Declare    IsAdocComment(codeline.s)
Declare    IsSkipComment(codeline.s)
Declare.s  StripCommentLine(codeline.s)
Declare    ADocSourceStart(weight = 0)
Declare    ADocSourceEnd(weight = 0)
Declare    Abort(ErrMsg.s)
Declare.s  LinePreview(text.s, LineNum = 0, weight = 0)
Declare.s  HeaderLinePreview(text.s, LineNum = 0)
;}==============================================================================
;                                   Internals
;{==============================================================================
;{>Comments_Marks(4100)
;| === Doxter Markers Primer
;|
;| The way Doxter decides which parts of your sorce code to treat as documentation
;| is by means of PureBasic's comment delimiter (`;`) immediately followed by
;| a character which, combined with the delimiter, comprise one of Doxter's
;| markers:
;|
;| .Doxter's Base Markers
;| [cols="7m,23d,70d",separator=¦]
;| |============================================================================
;| ¦ ;= ¦ ADoc Header  ¦ Marks beginning of doc Header. (first line only)
;| ¦ ;> ¦ Region Begin ¦ Marks beginning of a tagged region.
;| ¦ ;| ¦ ADoc Comment ¦ Treat line as AsciiDoc text.
;| ¦ ;~ ¦ Skip Comment ¦ The whole line will be ignored and skipped.
;| ¦ ;< ¦ Region End   ¦ Marks end of a tagged region.
;| |============================================================================
;|
;| The *Tagged Region* marker can also include PureBasic's foldable comments
;| delimiters:
;|
;| .Region Markers Variants
;| [cols="7m,98d"]
;| |============================
;| | ;{> | Foldable Region Begin
;| | ;}< | Foldable Region End
;| |============================
;|
;| The *Tagged Region End* marker has an alternative syntax to tell Doxter no to
;| add an empty line after closing the region:
;|
;| .Region Markers Modifiers
;| [cols="2*7m,20d,66d"]
;| |============================================================================
;| | ;<< | ;}<< | Unspaced Region End | Don't add empty line after closing tag.
;| |============================================================================
;|
;| This is useful when splitting a paragraph across multiple regions, in order to
;| keep its text lines next to the code they belong to. Without the `<` modifier,
;| Doxter's default behavior would be to add an empty line after the closing
;| region tag, which would split the text in multiple paragraphs in the final
;| document.
;}<
#mrk_RegionStart = ";{?>"
#mrk_RegionEnd   = ";}?<"
#mrk_ADocLine    = ";\|"
#mrk_SkipLine    = ";~"

Structure RegionData
  Weight.i
  Tag.s
  List StringsL.s()
EndStructure

;}==============================================================================
;-                                    RegExs
;{==============================================================================
Enumeration RegExsIDs
  #RE_TagRegionBegin
  #RE_TagRegionEnd
  #RE_ADocComment
  #RE_SkipComment
EndEnumeration
#totRegExs  = #PB_Compiler_EnumerationValue -1

Restore REGEX_PATTERNS
For i=0 To #totRegExs
  Read.s RE_Pattern$
  If Not CreateRegularExpression(i, RE_Pattern$)
    Debug "ERROR: Couldn't create RegEx #" + Str(i)
    End 1
  EndIf
Next

DataSection
  REGEX_PATTERNS:
  Data.s "^\s*?" + #mrk_RegionStart +     ; #RE_TagRegionBegin -- Named groups:
         "(?<tag>\w*)"+                   ;   <tag>                   (optional)
         "(\((?<weight>\d*)\))?"          ;   <weight>                (optional)
  Data.s "^\s*?" + #mrk_RegionEnd +       ; #RE_TagRegionEnd -- Named groups:
         "(?<modifier>[<]?)"              ;   <modifier>              (optional)
  Data.s "^\s*"+ #mrk_ADocLine +" ?(.*)$" ; #RE_ADocComment
  Data.s "^\s*"+ #mrk_SkipLine            ; #RE_SkipComment
EndDataSection
;}
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
;{>CLI_Usage(3200)--------------------------------------------------------------
;|=== Command Line Options
;|
;| To invoke Doxter via command prompt/shell:
;|
;|--------------------
;| doxter <sourcefile>
;|--------------------
;|
;| … where `<sourcefile>` is a PureBasic or SpiderBasic source file.
;}<-----------------------------------------------------------------------------

If SrcFile = #Empty$
  Abort("You must supply a filename")
EndIf

;  ===============================
;- Check that source file is valid
;  ===============================
;{>Validate_File_Extension(3300)------------------------------------------------
;| === Input File Validation
;|
;| Doxter checks that the passed `<sourcefile>` parameter has a valid extension:
;|
;| * `.pb`  -- PureBasic source file.
;| * `.pbi` -- PureBasic include file.
;| * `.pbf` -- PureBasic form file.
;| * `.sb`  -- SpiderBasic source file.
;|
;| If the file extension doesn't match, Doxter will report an error and abort
;| with Status Error 1.
;}<-----------------------------------------------------------------------------
SrcExt.s = GetExtensionPart(SrcFile)

Select LCase(SrcExt)
  Case "pb", "pbi", "pbf", "sb"
    ValidExt = #True
EndSelect

If Not ValidExt
  Abort(~"Invalid file extension \"."+ SrcExt +~"\". Only PB and SB files accepted.")
EndIf
;{>File_Checks(3320)------------------------------------------------------------
;| Doxter will also check that the file exists, it's not a directory, and it's
;| not 0 Kb in size; and abort with Status Error if any of these are met.
;}<-----------------------------------------------------------------------------
Select FileSize(SrcFile)
  Case 0
    Abort(~"File is 0 Kb: \""+ SrcFile +~"\"")
  Case -1
    Abort(~"File not found: \""+ SrcFile +~"\"")
  Case -2
    Abort(~"Parameter is a directory: \""+ SrcFile +~"\"")
EndSelect ;}

NewList RegionsL.RegionData()
NewList HeaderL.s()

ParseFile(SrcFile)

;  =================
;- Print Resume Info
;  =================
totRegions = ListSize(RegionsL())
PrintN("Total tagged regions found: "+ Str(totRegions))

OutFile.s = SrcFile

If ListSize( HeaderL() )
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
OutFile = ReplaceString(OutFile, SrcExt, OutExt)
PrintN("outfile: " + OutFile)

;  ================
;- Save Output File
;  ================
If Not CreateFile(0, OutFile, #PB_UTF8)
  Abort("Couldn't open output file for writing: "+ OutFile)
EndIf

If DocHeader
  ; --------------------
  ; Write Header to File
  ; --------------------
  ForEach HeaderL()
    If Not WriteStringN(0, HeaderL() )
      Abort("Couldn't write to file: "+ OutFile)
    EndIf
  Next
  ; Add blank line after Header
  If Not WriteStringN(0, #Empty$ )
    Abort("Couldn't write to file: "+ OutFile)
  EndIf
EndIf

; ----------------------------
; Write Tagged Regions to File
; ----------------------------
ForEach RegionsL()
  With RegionsL()
    ForEach \StringsL()
      If Not WriteStringN(0, \StringsL() )
        Abort("Couldn't write to file: "+ OutFile)
      EndIf
    Next
  EndWith
Next

; Add empty line at EOL
If Not WriteStringN(0, #Empty$ )
  Abort("Couldn't write to file: "+ OutFile)
EndIf

CloseFile(0)
CloseConsole()
End 0


;}******************************************************************************
; *                                                                            *
;-                                  PROCEDURES
; *                                                                            *
;{******************************************************************************
Procedure ParseFile(SrcFileName.s)
  ;{>two_steps_parsing(4210)
  ;~----------------------------------------------------------------------------
  ;| Doxter uses a two-steps parsing approach when processing documents:
  ;|
  ;| 1. *Header Parser* -- Scans the first lines of the source file looking for
  ;|    an AsciiDoc Header. Whether or not it found an Header, once finished
  ;|    its job the Header Parser relinquishes control over to the Regions Parser.
  ;| 2. *Regions Parser* -- Scans the reaminder of the source file looking for
  ;|    tagged regions to extract.
  ;|
  ;| These are two different parsers altogether, and Doxter always runs the fed
  ;| source file against both of them, in the exact order specified above.
  ;}<---------------------------------------------------------------------------
  
  Shared RegionsL()
  Shared HeaderL()
  
  If Not ReadFile(0, SrcFileName)
    Abort(~"Couldn't open source file \"" + SrcFileName + ~"\" for reading.")
    End 1
  EndIf
  
  BOM = ReadStringFormat(0) ; Skip BOM!
  
  ; TODO: Could implement read opearions using file format from BOM! (currently only UTF-8 supported)
  PrintN("Parsing source file: " + SrcFileName)
  PrintN( LSet(#Empty$, 80, "=") )
  
  ; ============
  ; Parser Setup
  ; ============
  ;{>Regions_Parser_Modalities(4242)
  ;~----------------------------------------------------------------------------
  ;| The *Regions Parser* alternates between two mutually exclusive modalities:
  ;| _Seeking_, and _InsideRegion_.
  ;|
  ;| When in _Seeking_ modality, the parser will scan every source line until it
  ;| finds a line whose first non-whitespace characters are a Region Begin marker
  ;| (`;>` or `;{>`), and it will ignore anything else. Once it finds the Region
  ;| Begin marker the parser switches to the _InsideRegion_ modality.
  ;|
  ;| When in _InsideRegion_ modality, the parser behavior changes, as every line
  ;| which has not a Skip Comment marker (`;~`) will be processed and become part
  ;| of the output document, until it find a Region End marker (`;<` and variants),
  ;| in which case it reverts to _Seeking_ modality, and so on, until the end of
  ;| file is reached.
  ;|
  ;| Furthermore, in _InsideRegion_ modality the parser can be enter and exit the
  ;| _InsideCode_ state. This is used to track inclusion of source code lines in
  ;| the region, as opposed to ADoc comment lines, for in the final document
  ;| source code must be enclosed in an AsciiDoc source block, using source
  ;| delimiters and setting the syntax to PureBasic. This will ensure that code
  ;| is shown as a verbatim block and enable syntax highlighting (if supported).
  ;}<---------------------------------------------------------------------------
  Enumeration ParseStates
    #Seeking
    #InsideRegion
  EndEnumeration
  
  cntLine = 1
  ParserState = #Seeking
  currTag.s = #Empty$
  currWeight = 0 ; Will be used as fallback value (+1) if first tag ha no weight
  AddingCode = #False
  FallbackCnt = 1 ; Counter to append to #FallbackTag in unamed tags.
  
  ; ==============================================================================
  ;-                              THE HEADER PARSER
  ; ==============================================================================
  ;{>Header_Parser_Rules(4230)
  ;|
  ;| ==== Header Parser Rules
  ;|
  ;| The *Header Parser* has one single task, detect if the source contains an
  ;| AsciiDoc Header and, if there is one, extract it and store it in memory.
  ;|
  ;| * Check if the very first line of the source file starts with `;=` (no
  ;|   leading space allowed):
  ;| ** *No*? Reset file pointer position to beginning of file and relinquish
  ;|    control to the Regions Parser. (Quit Parsing)
  ;| ** *Yes*? Then an AsciiDoc Header was found; strip away the `;` and store the
  ;|    line in the Header's data storage, then:
  ;| *** (_loop entrypoint_) Store current file position pointer and parse the
  ;|     next line:
  ;| **** If an ADoc Comment line (`;|`) is found, strip it of the marker and add
  ;|      it to Header's data storage, then carry on with parsing loop.
  ;| **** If a Skip Comment line (`;~`) is found, ignore it and carry on with
  ;|      parsing loop.
  ;| **** If the parsed line is none of the above, restore previous file position
  ;|      from stored pointer and relinquish control to the Regions Parser.
  ;|      (Exit Loop, Quit Parsing)
  ;}<---------------------------------------------------------------------------
  
  ; If the first line starts with ";=" then it's an AsciiDoc Header
  FilePos = Loc(0) ; Store current position in case we need to rollback
  firstline.s = ReadString(0)
  If Left(firstline, 2) = ";="
    ; ============
    ; Header found
    ; ============
    ; LineNum$ = RSet(Str(cntLine), #LineNumDigits, "0") + "|"
    AddElement(HeaderL())
    HeaderL() = Right(firstline, Len(firstline)-1)
    HeaderLinePreview(HeaderL(), cntLine)
    cntLine +1
    ; Now every following ADoc Comment Line we'll be treatd as part of the Header,
    ; as they might contains the Author and Revision lines, or global settings attributes.
    Repeat
      FilePos = Loc(0) ; Store current position in case we need to rollback
      CurrLine.s = ReadString(0)
      If IsSkipComment(CurrLine)
        ; Skip Comment Lines are allowed, just ignore them and carry on parsing.
        cntLine +1
      ElseIf IsAdocComment(CurrLine)
        AddElement(HeaderL())
        HeaderL() = StripCommentLine(CurrLine)
        HeaderLinePreview(HeaderL(), cntLine)
        cntLine +1
      Else
        ; Rollback file position and exit loop
        FileSeek(0, FilePos, #PB_Absolute)
        Break
      EndIf
    ForEver
  Else
    ; ===============
    ; No Header found
    ; ===============
    ; Rollback file position and exit loop
    FileSeek(0, FilePos, #PB_Absolute)
  EndIf
  ; ==============================================================================
  ;-                              THE REGIONS PARSER
  ; ==============================================================================
  ;{>Regions_Parser_Rules1(4240)
  ;|
  ;| ==== Regions Parser Rules
  ;|
  ;| The task of the *Regions Parser* is to extract and process all lines that
  ;| are enclosed between Region Start and Region End tags, and store them in
  ;| memory.
  ;<
  ;>Regions_Parser_Rules2(4244)
  ;|
  ;| * (*Seeking Modality*) this is the modality the parser starts off in:
  ;| ** (_loop entrypoint_) Parse line and check if its first non-white space
  ;|    characters are a Region Begin Tag (`;>`):
  ;| *** *No*? Ignore line and carry on with parsing parsing loop in Seeking mode.
  ;| *** *Yes*?
  ;| **** Process line and extract tag name and weight (if present)
  ;| **** Create new data storage for this region and asign it its weight
  ;| **** Add AsciiDoc line to stored region data with tagged region (e.g.
  ;|      `// tag::tagId[]` where `tagId` will be either the extracted tag or an
  ;|      autogenerated default fallback tag)
  ;| **** Enter _InsideRegion_ modality (Switch Loop).
  ;| * (*InsideRegion Modality*):
  ;| ** (_loop entrypoint_) Parse line and check if its first non-white space
  ;|    characters are one of Doxter markers or not:
  ;| *** *No*? Then the user wants to include source code lines in the region:
  ;| **** Set parser's state to _InsideCode_.
  ;| **** Add to current region's stored data a blank line followed by AsciiDoc
  ;|      markup to open a source block (`[source,purebasic]`) followed by a line
  ;|      with source block delimiter (`---`, 80 chars long).
  ;| **** Add parsed line to current region's data, as is.
  ;| **** Carry on parsing loop in InsideRegion modality.
  ;| *** *Yes*? Depending on the found marker:
  ;| **** It's an ADoc Comment marker (`;|`):
  ;| ***** If parser is in _InsideCode_ state, add to current region's stored data
  ;|       an AsciiDoc line containing a source delimiter to end source code
  ;|       block, followed by a blank line. Carry on parsing loop.
  ;| ***** Strip marker away (together with following space character, if present)
  ;|       and add line to current region's data storage in memory.
  ;| ***** Carry on parsing loop in InsideRegion modality.
  ;| **** It's a Skip Comment marker (`;~`):
  ;| ***** Ignore line and carry on parsing loop in InsideRegion modality.
  ;| **** It's a Region End marker (`;<`):
  ;| ***** If parser is in _InsideCode_ state, add to current region's stored data
  ;|       an AsciiDoc line containing a source delimiter to end source code
  ;|       block, followed by a blank line. Carry on parsing loop.
  ;| ***** Add AsciiDoc line to stored region data to end tagged region (e.g.
  ;|      `// end::tagId[]` where `tagId` will be tag assigned to the current
  ;|       current region).
  ;| ***** Check if the Region End marker contais the `<` modifier (`;<<`);
  ;|       if not, add a blank line to current region, otherwise not.
  ;| ***** Revert to _Seeking_ modality (Switch Loop).
  ;}<---------------------------------------------------------------------------
  
  ; Scan every line of the source file until EOF
  While Eof(0) = 0
    CurrLine.s = ReadString(0)
    
    Select ParserState
      Case #Seeking
        ; ~~~~~~~~~~~~~~~~~~~~~~~~~
        ; Parser Looking for Tag...
        ; ~~~~~~~~~~~~~~~~~~~~~~~~~
        If MatchRegularExpression(#RE_TagRegionBegin, CurrLine)
          ;  =========================
          ;- Region Start Marker Found
          ;  =========================
          ParserState = #InsideRegion
          If ExamineRegularExpression(#RE_TagRegionBegin, CurrLine)
            NextRegularExpressionMatch(#RE_TagRegionBegin)
            ; --------------
            ; Extract Tag ID
            ; --------------
            currTag = RegularExpressionNamedGroup(#RE_TagRegionBegin, "tag")
            If currTag = #Empty$
              ; No Tag ID found, create one:
              ; ----------------------------
              currTag = #FallbackTag + Str(FallbackCnt)
              FallbackCnt +1
            EndIf
            ; ------------------
            ; Extract Tag Weight
            ; ------------------
            Weight$ = RegularExpressionNamedGroup(#RE_TagRegionBegin, "weight")
            If Weight$ = #Empty$
              ; No Tag Weight found, asign current +1
              ; -------------------------------------
              currWeight +1
            Else
              currWeight = Val(Weight$)
            EndIf
          EndIf
          ; ----------------------------
          ; Add New Region to List
          ; ----------------------------
          AddElement( RegionsL() )
          With RegionsL()
            \Weight = currWeight
            \Tag = currTag
            ; ----------------------------
            ; Add AsciiDoc Tag to contents
            ; ----------------------------
            AddElement( \StringsL() )
            \StringsL() = "// tag::"+ currTag + "[]"
            LinePreview(\StringsL(), cntLine, currWeight)
          EndWith
        Else
          ; ===================
          ; Ignore Current Line
          ; ===================
        EndIf
      Case #InsideRegion
        ; ~~~~~~~~~~~~~~~~~~~~~~~~~
        ; Carry-On Tag Parsing...
        ; ~~~~~~~~~~~~~~~~~~~~~~~~~
        If MatchRegularExpression(#RE_TagRegionEnd, CurrLine)
          ;  =======================
          ;- Region End Marker Found
          ;  =======================
          ParserState = #Seeking
          If ExamineRegularExpression(#RE_TagRegionEnd, CurrLine)
            NextRegularExpressionMatch(#RE_TagRegionEnd)
            modifier.s = RegularExpressionNamedGroup(#RE_TagRegionEnd, "modifier")
            ; If there was an open source block close it:
            If AddingCode
              ADocSourceEnd(currWeight)
              AddingCode = #False
            EndIf
            ; Add AsciiDoc Tag End to contents
            ; --------------------------------
            With RegionsL()
              AddElement( \StringsL() )
              \StringsL() = "// end::"+ currTag + "[]"
              LinePreview(\StringsL(), cntLine, currWeight)
              If Not modifier = "<"
                ; Add blank line to ensure ADoc contents integrity.
                AddElement( \StringsL() )
                \StringsL() = #Empty$
                LinePreview(\StringsL(), cntLine, currWeight)
              EndIf
            EndIf
          EndWith
          currTag = #Empty$
        Else
          ; ===================================
          ; Add Curr Line to Curr Tagged Region
          ; ===================================
          If LTrim(CurrLine) = #Empty$
            ;  -----------------------
            ;- Curr Line Is Whitespace
            ;  -----------------------
            With RegionsL()
              AddElement( \StringsL() )
              \StringsL() = CurrLine
              LinePreview(\StringsL(), cntLine, currWeight)
            EndWith
          Else
            If IsAdocComment(CurrLine)
              ;  ------------------------------
              ;- Curr Line Is ADoc Comment Line
              ;  ------------------------------
              If AddingCode ; Check if we were adding source code to contents
                ADocSourceEnd(currWeight) ; Add closing source block delimiter
                AddingCode = #False
              EndIf
              With RegionsL()
                AddElement( \StringsL() )
                \StringsL() = StripCommentLine(CurrLine)
                LinePreview(\StringsL(), cntLine, currWeight)
              EndWith
            ElseIf IsSkipComment(CurrLine)
              ;  ------------------------------
              ;- Curr Line Is Skip Comment Line
              ;  ------------------------------
              ; It's a skip-me comment line (';~'), ignore it
            Else
              ;  -----------------
              ;- Curr Line Is Code
              ;  -----------------
              If Not AddingCode
                ADocSourceStart(currWeight) ; Add opening source block delimiter
                AddingCode = #True
              EndIf
              With RegionsL()
                AddElement( \StringsL() )
                \StringsL() = CurrLine
                LinePreview(\StringsL(), cntLine, currWeight)
              EndWith
            EndIf
          EndIf
        EndIf
    EndSelect
    
    cntLine +1
  Wend
  CloseFile(0)
  ;  ============
  ;- Sort Regions
  ;  ============
  SortStructuredList(RegionsL(), #PB_Sort_Ascending, OffsetOf(RegionData\Weight), TypeOf(RegionData\Weight))
  PrintN( LSet(#Empty$, 80, "=") )
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure IsAdocComment(codeline.s)
  
  If MatchRegularExpression(#RE_ADocComment, codeline)
    ProcedureReturn #True
  EndIf
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure IsSkipComment(codeline.s)
  
  If MatchRegularExpression(#RE_SkipComment, codeline)
    ProcedureReturn #True
  EndIf
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure.s StripCommentLine(codeline.s)
  
  If ExamineRegularExpression(#RE_ADocComment, codeline)
    NextRegularExpressionMatch(#RE_ADocComment)
    ProcedureReturn RegularExpressionGroup(#RE_ADocComment, 1)
  EndIf
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure ADocSourceStart(weight = 0)
  
  Shared RegionsL()
  
  With RegionsL()
    
    AddElement( \StringsL() )
    \StringsL() = #Empty$
    LinePreview( \StringsL(), 0, weight)
    
    AddElement( \StringsL() )
    \StringsL() = "[source,purebasic]"
    LinePreview( \StringsL(), 0, weight)
    
    AddElement( \StringsL() )
    \StringsL() = LSet(#Empty$, #SourceDelimiterLen, "-")
    LinePreview( \StringsL(), 0, weight)
    
  EndWith
  
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure ADocSourceEnd(weight = 0)
  
  Shared RegionsL()
  With RegionsL()
    
    AddElement( \StringsL() )
    \StringsL() = LSet(#Empty$, #SourceDelimiterLen, "-")
    LinePreview( \StringsL(), 0, weight)
    
    AddElement( \StringsL() )
    \StringsL() = #Empty$
    LinePreview( \StringsL(), 0, weight)
    
  EndWith
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure Abort(ErrMsg.s)
  
  ConsoleError("ERROR: "+ ErrMsg)
  CloseConsole()
  End 1
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure.s LinePreview(text.s, LineNum = 0, weight = 0)
  ;{-------------------------------------------------------------------
  ; Print a preview of the ADoc line, with well formated linenumber and
  ; tagged region's weight.
  ; -------------------------------------------------------------------
  ;{>Parser_Live_Preview(3500)
  ;|
  ;| === Parsing Live Preview During Execution
  ;|
  ;| During execution, Doxter will output to the console a preview of the parsed
  ;| lines that belong to tagged regions, showing their ADoc processed version,
  ;| together with extra lines added by the parser (eg. source code delimiters).
  ;| This feature is very useful to visually trace the source of problems when
  ;| the ouput results are not as intendend, as the log shows in a human friendly
  ;| format the various steps of Doxter's parsers.
  ;|
  ;| Here's an example of how the console output looks like:
  ;|
  ;| ----------------------------------------------------------
  ;| |0005|   28|// tag::my_example[]
  ;| |0006|   28|For example, the following code from `test.pb`:
  ;| |    |   28|
  ;| |    |   28|[source,purebasic]
  ;| |    |   28|--------------------------------------------------------------------------------
  ;| |0007|   28|For i=1 To 5
  ;| |0008|   28|  Debug i
  ;| |0009|   28|Next
  ;| ----------------------------------------------------------
  ;|
  ;| The first column indicated the line number in the original source that is
  ;| being shown; the absence of line number indicated that what you are seeing
  ;| on the right hand side is a line generated by Doxter, and added to the output
  ;| document for formatting purposes (in the above example, the opening of a
  ;| PureBasic source code block in AsciiDoc markup after line 6).
  ;|
  ;| The second column indicates the weight of the current tagged region being
  ;| processed (except for Header lines, which show the text `head` instead). In
  ;| the above example the region being shown has a weight of 28.
  ;| The weight colum is very useful when looking at the logged output for it
  ;| allows to easily spot where regions start and end, as each region should
  ;| have a different weight (although not mandatory).
  ;|
  ;| Finally, the third and last columns show the transformed parsed line, i.e.
  ;| how the line will be stored in the final AsciiDoc document.
  ;| At line `0005` of the above example we can see the AsciiDoc region tag
  ;| ce code block in AsciiDoc  by Doxter after parsing `;>my_example(28)` in
  ;| the original source file, at the same line number.
  ;}<---------------------------------------------------------------------------
  If LineNum = 0
    LineNum$ = Space(#LineNumDigits)
  Else
    LineNum$ = RSet(Str(LineNum), #LineNumDigits, "0")
  EndIf
  
  If weight = 0
    weight$ = Space(#WeightsDigits)
  Else
    weight$ = RSet(Str(weight), #WeightsDigits, " ")
  EndIf
  
  PrintN("|" + LineNum$ + "|" + weight$ +"|" + text)
EndProcedure
; ------------------------------------------------------------------------------
Procedure.s HeaderLinePreview(text.s, LineNum = 0)
  ; -----------------------------------------------------------------------
  ; Print a preview of the ADoc Header lines, with well formated linenumber
  ; and "header" instead of region's weight (trimmed to weight length).
  ; -----------------------------------------------------------------------
  If LineNum = 0
    LineNum$ = Space(#LineNumDigits)
  Else
    LineNum$ = RSet(Str(LineNum), #LineNumDigits, "0")
  EndIf
  
  weight$ = Left("header", #WeightsDigits)
  
  PrintN("|" + LineNum$ + "|" + weight$ +"|" + text)
  
EndProcedure

;}******************************************************************************
; *                                                                            *
;-                                DOCUMENTATION
; *                                                                            *
;{******************************************************************************

; ==============================================================================
;                                     INTRO
;{==============================================================================

;>intro(1000)

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

;| Doxter was designed to work with PureBasic, leveraging the power of AsciiDoc
;| and with simplicity in mind.
;<

;>who_needs(1100)

;| === Who Needs Doxter?

;| Any PureBasic or SpiderBasic programmer who knows AsciiDoc and wants to include
;| documentation of his/her code directly in the source files can benefit from
;| Doxter by automating the task of producing always up-to-date documentation
;| in various formats (HTML5, man pages, PDF, and any other format supported by
;| AsciDoc conversion backends).
;<

;>acknowledgements(1200)

;| === Acknowledgements

;| Although quite different in design, Doxter was inspired by Lou Acresti's
;| http://lou.wtf/cod/[Cod^], an unassuming doc format (_Documentus modestus_)
;| -- the simplicity of Cod sparkled the idea that I could implement something
;| similar, but exploiting AsciiDoc tagged regions instead.

;| My gratitude to http://lou.wtf/[Lou Acresti^] (aka https://github.com/namuol[@namuol^])
;| for having created such an inspiring tool like Cod.
;<

;}==============================================================================
;                                    Features
;{==============================================================================
;>Features(2000)
;| == Features

;| Doxter is a command line tool that parses a PureBasic (or SpiderBasic) source
;| file and extracts from it tag-delimited regions of code, these regions are
;| then processed according to some very simple rules in order to produce a well
;| formed AsciiDoc source document which can then be converted to HTML via
;| Asciidoctor (Ruby).

;| === Cross Documents Selective Inclusions
;|
;| Every tagged region in the source file becomes an AsciiDoc tagged region in
;| the output document. This is a very practical feature for it allows other
;| AsciiDoc documents to selectively include parts of a source file's documentation
;| using tag filtering.
;| For example, when documenting an application that relies on imported Modules,
;| the main document can selectively include regions from the Doxter-generated
;| modules' documentation, thus allowing to maintain both independent documentation
;| for every Module's API, as well as having a main document that extrapolates
;| parts from the modules' docs in a self-updating fashion.

;| === _Ordo ab Chao_: Structured Docs from Scattered Comments
;|
;| Each tagged region in the PB source can be assigned a weight, so that in the
;| final document the regions will be reordered in a specific way, forming a well
;| structured document that presents contents in the right order.
;| This feature allows to keep each paragraph near the code lines that it
;| discusses, making the source code more readable and freeing the documentation
;| from the constraints imposed by the order in which the code is organized.
;|
;| Keep your comments next to the code they belong to, allowing the source file
;| to follow its natural course and provide meaningful snippets of in-code
;| documentation, and use weighed tag regions to ensure that these out-of-order
;| fragments will be collated in a meaningful progressive order in the output
;| document.

;| === Mix Text and Source Code in Your Documentation
;|
;| Regions can be made up of AsciiDoc comments and source code, allowing to include
;| fragments of the original source code in the final documentation, along with
;| AsciiDoc text.
;|
;| AsciiDoc comments are comment lines with special comments delimiters which
;| will be treated as normal comments by PureBasic, but Doxter will strip them of
;| the comment delimiter so that they will become AsciiDoc lines in the output
;| document.
;|
;| Any source code (i.e. non-AsciiDoc comments) inside a tagged region will be
;| rendered in the final document inside an AsciiDoc source block, with PureBasic
;| set as its language.
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

; 3200 === Command Line Options
; 3300 === Input File Validation [extensions]
; 3320     [check file exists, is not dir or 0kb]
; 3330     [output file depending on AsciiDoc header]
; 3500 === Parsing Live Preview During Execution

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

; 4100 === Doxter Markers Primer

;>Comments_Marks_Considerations(4110)
;| That's about all you'll have to learn: memorize those five base symbols, their
;| variannts and modifiers, and learn how to use them correctly and wisely.
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
;<

; 4210 : [two steps parsing]

;>The_Parser_continue(4220)
;| Each of these parsers obeys its own rules, and the way they interpret the
;| comment markers (or ignore them) is slightly different.
;| Here follow the simple rules by which each parser abides.
;<

; 4230 == Header Parser Rules
; 4240 == Regions Parser Rules
; 4242    [Regions Parser Modalities]
; 4244    [Regions Parser Rules2]

;>The_Parser_Final_Notes(4250)
;| The above rules are going to be a useful reference when you've began learning
;| Doxter, and by studying them you can get the full picture of its inner workings.
;| But the following guidelines and examples are a better starting point -- and
;| don't forget to look at source code of Doxter, for it's self-documenting by
;| its own system, and you can compare the source to the Asciidoc output and
;| study it as an example.
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
;| ;>tagname(<region weight>)
;| --------------------------
;|
;| … where `tagname` is a unique identifier for the tagged region, and
;| `<region weight>` is an integer number. Both of them are optional, and if
;| you don't supply them Doxter will, using the default Tag ID `region` followed
;| by an incremental counter, and will assign as weight the value of the last
;| encountered weight plus one.
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
;~| .............................................................................
;| ==================
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
;| ==================
;~| .............................................................................
;}<


;}******************************************************************************
; *                                                                            *
;-                                    TODOs
; *                                                                            *
;{******************************************************************************
;>TODOs(10000)
;| == Roadmap and TODOs
;|
;| Doxter it's still a young application, and there is always room for improvements.
;| Here is a list of pending tasks and new features waiting to be implemented.
;|
;| * [ ] At startup look for a settings file and, if found, check if it contains
;|       a Doxter version and if it matches the current version of the running
;|       tool. This is to ensure that in shared projects everyone is using the
;|       latest release of Doxter (someone might forget to recompile after pulling
;|       changes from the repo).
;| ** [ ] Allow use of SemVer constraint operators to permit tolerance in MINOR
;|        and PATCH version differences.
;| * [ ] Allow regions merging:
;| ** [ ] Before sorting regions, sort and merge regions with same Tag ID.
;| ** [ ] Add `;>>` and `;}>>` to assing the last used Tag ID (instead of fallback
;|         Tag ID) to the region -- only works if no tag is provided!
;|         This simplifies creating contiguos regions with same Tag ID for merging.
;| ** [ ] ADoc region tags must be injected before regions sorting, not at parse
;|        time, otherwise they prevent merging operations.
;| ** [ ] Advanced merge features for splitting PB source across regions:
;| *** [ ] `;<!` and `;}<!` to prevent both closing an open source block (if any)
;|        and adding empty line after closing tag. This is needed for regions
;|        merging, where a PB source block might carry on in the next region.
;| *** [ ] Likewise, `;>!` and `;{>!` to prevent opening a source block when the
;|        next region starts with PB code. This is needed when splitting a region
;|        of PB source.
;| *** [ ] It might be useful to add some state-tracking vars in the `RegionData`
;|         Structure to track the parser state at end-of-region time (eg, if there
;<
;}******************************************************************************
; *                                                                            *
;-                                  CHANGELOG
; *                                                                            *
; ******************************************************************************
;{>CAHNGELOG(20000)
;| == Changelog
;|
;| * v0.1.1-alpha (2018/25/21) -- created Doxter repository on GitHub.
;| * v0.1.0-alpha (2018/09/21) -- first public released Alpha:
;| https://github.com/tajmone/PBCodeArcProto/blob/83c32cd/_assets/Doxter.pb
;}<

;= Doxter: Docs-Generator from PB Sources.
;| Tristano Ajmone, <tajmone@gmail.com>
;| v0.1.4-alpha, October 1, 2018: Public Alpha
;| :License: MIT License
;| :PureBASIC: 5.62
;~------------------------------------------------------------------------------
;| :toclevels: 3
#DOXTER_VER$ = "0.1.4-alpha"
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
Declare.s  LinePreview(text.s, LineNum = 0, weight = 0, subweight = 0)
Declare.s  HeaderLinePreview(text.s, LineNum = 0)
;}==============================================================================
;                                   Internals
;{==============================================================================
;{>Comments_Marks(4100)
;| 
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
;| [NOTE]
;| =============================================================================
;| You can freely use PureBasic's special comments marks (`;{`/;`}`/`;-`) within
;| Doxter's markers (e.g. `;{>`, `;}~`, `;-|`, etc.) execpt in the ADoc Header
;| marker, which must be `;=`.
;| This allows you to create regions which are foldable in PureBasic IDE.
;| =============================================================================
;|
;| The *Tagged Region End* marker has an alternative syntax to prevent Doxter
;| from adding an empty line after closing the region:
;|
;| .Region Markers Modifiers
;| [cols="7m,20d,66d"]
;| |============================================================================
;| | ;<< | Unspaced Region End | Don't add empty line after closing tag.
;| |============================================================================
;|
;| This is useful when splitting a paragraph across multiple regions, in order to
;| keep its text lines next to the code they belong to. Without the `<` modifier,
;| Doxter's default behavior would be to add an empty line after the closing
;| region tag, which would split the text in multiple paragraphs in the final
;| document.
;}<

#PB_CommDelim = ";[{}\-]?"

#mrk_RegionStart = #PB_CommDelim + ">"
#mrk_RegionEnd   = #PB_CommDelim + "<"
#mrk_ADocLine    = #PB_CommDelim + "\|"
#mrk_SkipLine    = #PB_CommDelim + "~"

Structure RegionData
  Weight.i
  Subweight.i
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
         "(\("+                           ;
         "(?<weight>\d*)?"+               ;   <weight>                (optional)
         "(\.(?<subweight>\d+))?"+        ;   <subweight>             (optional)
         "\))?"
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
;{>CLI_Usage(.10)--------------------------------------------------------------
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
;{>Input_File_Validation(3300)--------------------------------------------------
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
;{>Input_File_Validation -------------------------------------------------------
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

If ListSize(HeaderL())
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
    If Not WriteStringN(0, HeaderL())
      Abort("Couldn't write to file: "+ OutFile)
    EndIf
  Next
  ; Add blank line after Header
  If Not WriteStringN(0, #Empty$)
    Abort("Couldn't write to file: "+ OutFile)
  EndIf
EndIf

; ----------------------------
; Write Tagged Regions to File
; ----------------------------
ForEach RegionsL()
  With RegionsL()
    ForEach \StringsL()
      If Not WriteStringN(0, \StringsL())
        Abort("Couldn't write to file: "+ OutFile)
      EndIf
    Next
  EndWith
Next

; Add empty line at EOL
If Not WriteStringN(0, #Empty$)
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
  PrintN(LSet(#Empty$, 80, "="))
  
  ;  ============
  ;- Parser Setup
  ;  ============
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
  
  
  ; Regions-Tracking Map
  ;{====================
  ; The parser uses this map to track the last weights used for every region.
  ; Wether the weights were defined in the Region Marker or were auto-generated,
  ; this map will always keep track of the last eights used during parsing.
  ; Region names are case sensitive in Asciidoctor (and PureBasic Map keys too).
  Structure RegionTracking
    weight.i        ; Last weight used for region tag.
    subweight.i     ; Last subweight used for region tag.
    count.i         ; Tracks number of same-named regions found
  EndStructure
  
  NewMap RegionsTrackM.RegionTracking()
  ;}
  
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
  ;| ** *Yes*? Then an AsciiDoc Header was found; strip away the `;` and store
  ;|    the line in the Header's data storage, then:
  ;| *** (_loop entrypoint_) Store current file position pointer and parse the
  ;|     next line:
  ;| **** If an ADoc Comment line (`;|`) is found, strip it of the marker and
  ;|      add it to Header's data storage, then carry on with parsing loop.
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
  ;| **** Process line and extract _tag_, _weight_ and _subweight_ (if present):
  ;| ***** if no _tag_ was provided, use default fallback Id instead: `region`
  ;|       followed by a counter that increases at each use (e.g. `region1`,
  ;|       `region2`, etc.).
  ;| ***** if no _weight_ was provided: 
  ;| ****** if a region with same _tag_ already exists in memory, retrive its
  ;|        weight and use it, otherwise assign the last used weigth incremented
  ;|        by one (assume that the users wishes the new region to be continguos
  ;|        with the preceding one).
  ;| ***** if no _subweight_ was provided: 
  ;| ****** if a region with same _tag_ already exists in memory, retrive its
  ;|        last used subweight, increase by 1 and use it, otherwise use value 1.
  ;| **** Create new entry in memory for this region fragment and store its weight
  ;|      and subweight values.
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
  ;| ***** Check if the Region End marker contais the `<` modifier (`;<<`);
  ;|       if not, add a blank line to current region, otherwise not.
  ;| ***** Revert to _Seeking_ modality (Switch Loop).
  ;| 
  ;| [NOTE]
  ;| ===========================================================================
  ;| During the parsing stage no AsciiDoc tagged region begin/end lines are added
  ;| to the regions stored in memory, because regions with same tag still need
  ;| to be sorted and merged together (the parser stores each region fragment
  ;| separately, regardless of its tag).
  ;| It will be the postprocessor's job to handle all that, and once fragmented
  ;| regions are merged together the AsciiDoc `// tag:[]` and `// end:[]` lines
  ;| will be added at their start and end, respectively.
  ;| 
  ;| The AsciiDoc `// tag:[]` and `// end:[]` lines shown in the Live Preview
  ;| are just for debugging purposes, so to speak, but they are not actually
  ;| stored in memory at that point.
  ;| ===========================================================================
  ;| 
  ;}<---------------------------------------------------------------------------
  
  ; Scan every line of the source file until EOF
  While Eof(0) = 0
    CurrLine.s = ReadString(0)
    ; TODO: optimize: Use a RegEx to check if any marker matches, instead of multiple checks.
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
            ; ///// Establish Region's Tag /////
            currTag = RegularExpressionNamedGroup(#RE_TagRegionBegin, "tag")
            If currTag = #Empty$
              ; No Tag ID found, create one:
              ; ----------------------------
              currTag = #FallbackTag + Str(FallbackCnt)
              FallbackCnt +1
            EndIf
            RegionIsNotNew = FindMapElement(RegionsTrackM(), currTag) ; NOTE: Map keys are case-sensitive!
                                                                      ; ///// Establish Region's Weight /////
            parsedWeight.s = RegularExpressionNamedGroup(#RE_TagRegionBegin, "weight")
            If parsedWeight = #Empty$
              ; No Tag Weight found, auto-generate it
              ; -------------------------------------
              If RegionIsNotNew ; retrive its last used weight.
                currWeight = RegionsTrackM()\weight
              Else ; It's a new region, assign it the last used weight + 1.
                   ; (assume author wants it to be after last used region)
                currWeight +1
              EndIf
            Else
              currWeight = Val(parsedWeight)
            EndIf
            ; ///// Establish Region's Subweight /////
            parsedSubweight.s = RegularExpressionNamedGroup(#RE_TagRegionBegin, "subweight")
            If parsedSubweight = #Empty$
              ; No Tag Subweight found, auto-generate it
              ; -------------------------------------
              If RegionIsNotNew ; retrive its last used Subweight And add 1 To it.
                currSubweight = RegionsTrackM(currTag)\Subweight +1
              Else ; It's a new region, assign it default Subweight = 1.
                currSubweight = 1
              EndIf
            Else
              currSubweight = Val(parsedSubweight)
            EndIf
          EndIf
          ; ----------------------------
          ; Add New Region to List
          ; ----------------------------
          AddElement(RegionsL())
          With RegionsL()
            \Tag = currTag
            \Weight = currWeight
            \Subweight = currSubweight
          EndWith
          ; ----------------------------
          ; Update Regions's Tracker Map
          ; ----------------------------
          RegionsTrackM(currTag)\weight = currWeight
          RegionsTrackM(currTag)\subweight = currSubweight
          ; Increase counter of this region
          RegionsTrackM(currTag)\count +1
          ; ------------------------------
          ; AsciiDoc Tag Open Line Preview
          ; ------------------------------
          ; Just show the tag in Line Previewer, don't add it to region's data.
          LinePreview("// tag::"+ currTag + "[]", cntLine, currWeight, currSubweight)
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
            ; AsciiDoc Tag End Line Preview
            ; ------------------------------
            LinePreview("// end::"+ currTag + "[]", cntLine, currWeight, currSubweight)
            If Not modifier = "<"
              ; Add blank line to ensure ADoc contents integrity.
              With RegionsL()
                AddElement(\StringsL())
                \StringsL() = #Empty$
                LinePreview(\StringsL(), 0, currWeight, currSubweight)
              EndWith
            EndIf
          EndIf
          ;           EndWith ; DELME
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
              AddElement(\StringsL())
              \StringsL() = CurrLine
              LinePreview(\StringsL(), cntLine, currWeight, currSubweight)
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
                AddElement(\StringsL())
                \StringsL() = StripCommentLine(CurrLine)
                LinePreview(\StringsL(), cntLine, currWeight, currSubweight)
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
                AddElement(\StringsL())
                \StringsL() = CurrLine
                LinePreview(\StringsL(), cntLine, currWeight, currSubweight)
              EndWith
            EndIf
          EndIf
        EndIf
    EndSelect
    
    cntLine +1
  Wend
  CloseFile(0)
  PrintN(LSet(#Empty$, 80, "="))
  
  ; ==============================================================================
  ;-                          THE REGIONS POSTPROCESSOR                           
  ; ==============================================================================
  ; Now it's time to postprocess extracted regions fragments: merge same-named
  ; regions and add AsciiDoc region tags.
  
  ;  =====================
  ;- Gather Stats and Info
  ;  =====================
  totRegionsFrags = ListSize(RegionsL())
  PrintN("REGIONS FRAGMENTS: " + Str(totRegionsFrags)) ; DELME
  totUniqueRegions = MapSize(RegionsTrackM())
  PrintN("UNIQUE REGIONS: " + Str(totUniqueRegions)) ; DELME
  
  ; NOTE: This is only for informational purposes, can safely delete.
  If totRegionsFrags > totUniqueRegions
    PrintN("Regions that need merging, and their total number of parts:")
    cnt = 1
    With RegionsTrackM()
      ForEach RegionsTrackM()
        If \count > 1
          cnt$ = RSet(Str(cnt)+". ", 7)
          PrintN(cnt$ + MapKey(RegionsTrackM()) + " ("+ Str(\count) +")")
          cnt +1
        EndIf
      Next
    EndWith
  EndIf
  ;  ==================
  ;- SubRegions Sorting
  ;  ==================
  
  ; If there are more region fragments than unique region names we need to merge
  ; some of them. We must also set all subregions' `\weight` to the last weight
  ; value found for that region during parsing (i.e. the value stored in
  ; `RegionsTrackM()\weight`) because in the source there could be multiple
  ; weight declarations for a same name region but for the final sorting to work
  ; correctly all subregions must have equal weight.
  
  If totRegionsFrags > totUniqueRegions
    PrintN("MERGING REGIONS...") ; DELME
    
    ; ---------------------------------------
    ; 1. Sort regions by Tag, Asciibetically
    ; ---------------------------------------
    SortStructuredList(RegionsL(),
                       #PB_Sort_Ascending,
                       OffsetOf(RegionData\Tag), 
                       TypeOf(RegionData\Tag))
    ; ----------------------------------------------
    ; 2. Get multipart-regions End and Start indices
    ; ----------------------------------------------
    ; Before actually sorting, we'll extract the start and end list-indices of
    ; each named region that has subregions, and we'll sort them after iterating
    ; through all the regions, to avoid messing up the iteration.
    
    ; We'll need a structured list to track these list indices:
    Structure regionIndex
      regionStart.i  ; index of first unique region element in RegionsL()
      regionEnd.i    ; index of last unique region element in RegionsL()
    EndStructure
    
    NewList RegionsIndexesL.regionIndex()
    
    ; Now that regions are asciibetically ordered, let's iterate through them:
    ResetList(RegionsL())
    With RegionsL()
      While NextElement(RegionsL())
        subRegions = RegionsTrackM(\Tag)\count
        If subRegions > 1 ; This region has sub-regions
          
          ; Fix region's weight to last value encountered:
          \Weight = RegionsTrackM()\weight
          
          ; Store first elements' index
          AddElement(RegionsIndexesL())
          RegionsIndexesL()\regionStart = ListIndex(RegionsL())
          
          ; Now cycle through up to last element
          For skip=1 To subRegions -1
            NextElement(RegionsL())
            ; Fix region's weight to last value encountered:
            \Weight = RegionsTrackM()\weight
          Next
          ; Store last elements' index
          RegionsIndexesL()\regionEnd = ListIndex(RegionsL())
        EndIf
      Wend
    EndWith
    With RegionsIndexesL()
      ; ----------------------------------------------
      ; 3. Subsort same-named regions by subWeight
      ; ----------------------------------------------
      ForEach RegionsIndexesL()
        
        SortStructuredList(RegionsL(), #PB_Sort_Ascending,
                           OffsetOf(RegionData\Subweight),
                           TypeOf(RegionData\Subweight),
                           \regionStart, \regionEnd)
      Next
    EndWith  
  Else
    PrintN("NO REGIONS MERGING REQUIRED") ; DELME
  EndIf
  ;  ===============
  ;- Add Region Tags
  ;  ===============
  PrintN(LSet("", 20, "-"))
  
  With RegionsL()
    ResetList(RegionsL())
    While NextElement(RegionsL())
      ; -----------------------------
      ; Add AsciiDoc Region Begin Tag
      ; -----------------------------
      FirstElement(\StringsL())
      InsertElement(\StringsL())
      \StringsL() = "// tag::"+ \Tag + "[]"
      ; ----------------------
      ; Skip to Last SubRegion
      ; ----------------------
      ; subRegions = RegionsTrackM(\Tag)\count - 1
      ; For skip = 1 To subRegions
      For skip = 1 To RegionsTrackM(\Tag)\count - 1
        NextElement(RegionsL())
      Next
      ; ---------------------------
      ; Add AsciiDoc Region End Tag
      ; ---------------------------
      LastElement(\StringsL())
      AddElement(\StringsL())
      \StringsL() = "// end::"+ \Tag + "[]"
    Wend
  EndWith 
  
  ;  ============
  ;- Sort Regions
  ;  ============
  SortStructuredList(RegionsL(), #PB_Sort_Ascending, OffsetOf(RegionData\Weight), TypeOf(RegionData\Weight))
  
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
    
    AddElement(\StringsL())
    \StringsL() = #Empty$
    LinePreview(\StringsL(), 0, weight)
    
    AddElement(\StringsL())
    \StringsL() = "[source,purebasic]"
    LinePreview(\StringsL(), 0, weight)
    
    AddElement(\StringsL())
    \StringsL() = LSet(#Empty$, #SourceDelimiterLen, "-")
    LinePreview(\StringsL(), 0, weight)
    
  EndWith
  
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure ADocSourceEnd(weight = 0)
  
  Shared RegionsL()
  With RegionsL()
    
    AddElement(\StringsL())
    \StringsL() = LSet(#Empty$, #SourceDelimiterLen, "-")
    LinePreview(\StringsL(), 0, weight)
    
    AddElement(\StringsL())
    \StringsL() = #Empty$
    LinePreview(\StringsL(), 0, weight)
    
  EndWith
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure Abort(ErrMsg.s)
  
  ConsoleError("ERROR: "+ ErrMsg)
  CloseConsole()
  End 1
  
EndProcedure
; ------------------------------------------------------------------------------
Procedure.s LinePreview(text.s, LineNum = 0, weight = 0, subweight = 0)
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
  ;| together with extra lines added by the parser (eg. source code delimiters,
  ;| blank lines, etc).

  ;| Although the shown lines are just an aproximation of the final document (the
  ;| regions will be postprocessed, merged and reoderdered before writing them to
  ;| file), this feature is very useful to visually trace the source of problems
  ;| when the ouput results are not as intendend, as the log provides a human
  ;| friendly insight into Doxter's parser.

  ;| Here's an example of how the console output looks like:

  ;| [role="shell"]
  ;| ----------------------------------------------------------
  ;||0099|4100|   1|region tag, which would split the text in multiple paragraphs in the final <1>
  ;||0100|4100|   1|document.
  ;||0101|4100|   1|// end::Comments_Marks[] <2>
  ;||    |4100|   1| <3>
  ;||0169|4101|  10|// tag::CLI_Usage[] <4>
  ;||0170|4101|  10|=== Command Line Options
  ;| ----------------------------------------------------------
  ;|
  ;| <1> Continuation lines of a region with weight `4100` and subweight `1`.
  ;| <2> AsciiDoc tagged region `end::` generated by Doxter when it encountered
  ;|     a `;<` marker.
  ;| <3> Blank line added by Doxter; note that there is no corresponing line
  ;|     number, for it is not found in the source file.
  ;| <4> Region Being marker found ad line 169, with wieght `4101` and sebweight
  ;|     `10` (probably the continuation of a fragmented region).

  ;| There are four columns in the preview, representing the line number in the
  ;| source file, the region's weight, its subweight, and a preview of the line
  ;| converted to AsciiDoc.

  ;|
  ;| The absence of line number in the first column indicates that what you are
  ;| seeing on the right hand side is a line generated by Doxter, and added to
  ;| the output document for formatting purposes (e.g. a blank line, source code
  ;| block delimiters, etc.).
 
  ;| The weight colum is very useful when looking at the logged output for it
  ;| allows to easily spot where regions start and end, as each region should
  ;| have a different weight (although not mandatory).
  ;| Header lines will always show the text `head` in the second and third
  ;| columns, instead of numbers, because the Header has no weight or subweight.

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
  
  If subweight = 0
    subweight$ = Space(#WeightsDigits)
  Else
    subweight$ = RSet(Str(subweight), #WeightsDigits, " ")
  EndIf
  
  PrintN("|" + LineNum$ + "|" + weight$ +"|" + subweight$ +"|" + text)
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
  
  PrintN("|" + LineNum$ + "|" + weight$ +"|" + weight$ +"|" + text)
  
EndProcedure

;}******************************************************************************
; *                                                                            *
;-                                DOCUMENTATION
; *                                                                            *
;{******************************************************************************

; ==============================================================================
;                                     INTRO
;{==============================================================================

;>intro(1000.1)

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
;| Each tagged region in the PB source can be assigned a weight, so that in the
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

; * two_steps_parsing |4210|    | : [two steps parsing]

;>The_Parser_continue(4220)
;| Each of these parsers obeys its own rules, and the way they interpret the
;| comment markers (or ignore them) is slightly different.
;| Here follow the simple rules by which each parser abides.
;<

; * Header_Parser_Rules       |4230| == Header Parser Rules
; * Regions_Parser_Rules1     |4240| == Regions Parser Rules
; * Regions_Parser_Modalities |4242|    [Regions Parser Modalities]
; * Regions_Parser_Rules2     |4244|    [Regions Parser Rules2]

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
;|
;| * *Sub-Regions Merging*.
;|    Same-named regions will be stitched together into a single region, making
;|    their inclusion in other documents easier.
;|    Sub-weights will be used for sorting before merging the region. 
;<
;}******************************************************************************
; *                                                                            *
;-                                  CHANGELOG
; *                                                                            *
; ******************************************************************************
;{>CHANGELOG(20000)
;| == Changelog
;|
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

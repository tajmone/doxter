;= Doxter Engine
;| Tristano Ajmone, <tajmone@gmail.com>
;| v0.0.4-alpha, Novermber 25, 2018: Public Alpha
;| :License: MIT License
;| :PureBASIC: 5.62
;~------------------------------------------------------------------------------
;| :toclevels: 3
;{******************************************************************************
; ··············································································
; ···························· Doxter Egine Module ·····························
; ··············································································
; ******************************************************************************
;>description(1.2)
;| =============================================================================
;| image::doxter_logo.svg[Doxter Logo,align="center"]
;|
;| The Doxter Egine contains the core functionalities behind the Doxter CLI
;| application, and can be included as a module in other applications and used
;| to doxterize source files programmatically through its API.
;| Released under <<License,MIT License>>.
;| 
;| https://github.com/tajmone/doxter
;| =============================================================================
;<

;}******************************************************************************
; *                                                                            *
;-                          MODULE'S PUBLIC INTERFACE
; *                                                                            *
;{******************************************************************************
DeclareModule dox
  ; ============================================================================
  ;- PUBLIC PROCEDURES DECLARATION
  ; ============================================================================
  Declare    SetEngineLang(lang.s = "purebasic")
  Declare    ParseFile(SrcFileName.s)
  Declare    SaveDocFile(OutFileName.s)
  Declare    Abort(ErrMsg.s)
  
  ; ============================================================================
  ;- PUBLIC DATA
  ; ============================================================================
  ; TODO: Make Regions data private, expose only stats.
  Structure RegionData
    Weight.i
    Subweight.i
    Tag.s
    List StringsL.s()
  EndStructure
  
  NewList RegionsL.RegionData()
  NewList HeaderL.s()
  
EndDeclareModule
;}******************************************************************************
; *                                                                            *
;-                          MODULE'S PRIVATE INTERFACE
; *                                                                            *
;{******************************************************************************
Module dox
  ; ============================================================================
  ;- PRIVATE PROCEDURES DECLARATION
  ; ============================================================================
  Declare    ADocSourceStart(weight = 0)
  Declare    ADocSourceEnd(weight = 0)
  Declare.s  LinePreview(text.s, LineNum = 0, weight = 0, subweight = 0)
  Declare.s  HeaderLinePreview(text.s, LineNum = 0)
  ; ==============================================================================
  ;- Misc Internal Settings
  ; ==============================================================================
  #SourceDelimiterLen = 80   ; ADoc Source Block delimiters lenght (chars).
  #FallbackTag = "region"    ; Fallback Tag Id to use when none is provided.
  #LineNumDigits = 4         ; Used in Debug output: digits-width of line numbers.
  #WeightsDigits = 4         ; Used in Debug output: digits-width of regions' weights.
  
  ; ==============================================================================
  ;-                       ENGINE SETTINGS & INITIALIZATION                       
  ; ==============================================================================
  sourcelang.s = "purebasic" ; Language for generated ADoc source code block
  fileEncoding = #PB_UTF8    ; Input source file encoding
  headerMarker.s = ";="      ; ADoc Header Marker
  
  ; ==============================================================================
  ; Doxter Markers
  ;{==============================================================================
  ;{>Comments_Marks(3000)
  ;| 
  ;| == Doxter Markers Primer
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
  ;| SpiderBasic uses the same comments delimiter as PureBasic. As for Alan,
  ;| just use its native comment delimiter (`--`) instead of `;` -- i.e. `-->`,
  ;| `--|`, `--~`, etc. The same applies to any other languages that will be 
  ;| supported in the future.
  ;| 
  ;| [NOTE]
  ;| =============================================================================
  ;| In PureBasic and SpiderBasic you can freely use the special comments marks
  ;| (`;{`/`;}`/`;-`) within Doxter's markers (e.g. `;{>`, `;}~`, `;-|`, etc.)
  ;| execpt in the ADoc Header marker, which can only be `;=`.
  ;| This allows you to create regions which are foldable in PureBasic's and
  ;| SpiderBasic's native IDEs.
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
  
  #PB_CommDelim = ";[{}\-]?" ; either:   ;   ;{   ;}   ;-
  
  ; Markers:
  #mrk_RegionStart = ">"
  #mrk_RegionEnd   = "<"
  #mrk_ADocLine    = "|"
  #mrk_SkipLine    = "~"
  
  ; Valid Region Parser Markers:
  #mrk_any = "["+#mrk_RegionStart + #mrk_RegionEnd + "\"+ #mrk_ADocLine + #mrk_SkipLine +"]"
  
  ; Valid ADoc Header linr Markers (only '|' or '~'):
  #mrk_head = "["+ "\"+ #mrk_ADocLine + #mrk_SkipLine +"]"
  ; NOTE: This RegEx is used after the "=" has been found on 1st line, on the
  ;       lines that follow the header marker, to establish if they are are
  ;       valid Header lines or if the Header has ended!
  
  ; Modifiers:
  #mod_RegionStart = ">"
  #mod_RegionEnd   = "<"
  
  #mod_any = "["+#mod_RegionStart + #mod_RegionEnd +"]"
  
  ;}==============================================================================
  ;- Doxter Markers RegExs
  ;{==============================================================================
  ; We use named enumerator to carry on RegExs IDs constants values and prevent
  ; same IDs errors if other enumerated RegExs are created elsewhere (RegExs IDs
  ; are truely global and not subject to Modules name spacing). 
  Enumeration RegExsIDs
    ; Empty enum needed to get RegExsIDs's #PB_Compiler_EnumerationValue
  EndEnumeration
  #RE_Id_EngineFirst = #PB_Compiler_EnumerationValue
  
  Enumeration RegExsIDs
    #RE_HeaderParseLine
    #RE_RegionParseLine
    #RE_RegionBeginOpts
  EndEnumeration
  #RE_Id_EngineLast = #PB_Compiler_EnumerationValue -1
  #RE_Id_EngineTot  = #PB_Compiler_EnumerationValue - #RE_Id_EngineFirst
  
  ; Some RegExs in the DataSection need the comment delimiter RegEx suffixed to
  ; them (since its dynamically calculated, it can't be stored here):
  #Requires_CommDel = #True
  #No_CommDel  = #False
  
  DataSection
    REGEX_PATTERNS:                         ; ----------------------------------
    Data.i #Requires_CommDel                ; #RE_HeaderParseLine - Named groups:
    Data.s "(?<marker>"+ #mrk_head +")\s?"+ ;   <marker>
           "(?<linetail>.*)$"               ;   <linetail>            (optional)
                                            ; ----------------------------------
    Data.i #Requires_CommDel                ; #RE_RegionParseLine - Named groups:
    Data.s "(?<marker>"+ #mrk_any +")" +    ;   <marker>
           "(?<modifier>"+ #mod_any +"?)" + ;   <modifier>            (optional)
           "(?<options>[\S]*)\s?" +         ;   <options>             (optional)
           "(?<linetail>.*)$"               ;   <linetail>            (optional)
                                            ; ----------------------------------
    Data.i #No_CommDel                      ; #RE_RegionBeginOpts - Named groups:
    Data.s "(?<tag>\w*)" +                  ;   <tag>                 (optional)
           "(\("+                           ;
           "(?<weight>\d*)?" +              ;   <weight>              (optional)
           "(\.(?<subweight>\d+))?" +       ;   <subweight>           (optional)
           "\))?"                           ;
  EndDataSection
  
  SetEngineLang()
  ;}==============================================================================
  ;- SetEngineLang()
  ;{==============================================================================
  ; This procedure initializes the engine according to passed lang and comment
  ; delimiter parameters:
  ; - [x] Creates all the required Markers RegExs.
  ; - [x] Set the default language to use in ADoc source blocks.
  ; Currently designed to be invoked just once (not ready to handle multiple parsings
  ; with different settings).
  ; NOTE: SetEngineLang() can recreate the RegExs, the old ones will be replaced by
  ;       the new ones; it's not necessary to free the old ones first!
  ; ------------------------------------------------------------------------------
  Procedure SetEngineLang(lang.s = "purebasic")
    Shared sourcelang, fileEncoding, headerMarker
    
    ; Default Presets:
    commDel.s = #PB_CommDelim
    fileEncoding = #PB_UTF8
    
    Select LCase(lang)
      Case "spiderbasic"
        sourcelang = "spiderbasic"
        headerMarker = ";="
      Case "alan"
        sourcelang = "alan"
        commDel = "--"
        fileEncoding = #PB_Ascii ; ISO-8859-1
        headerMarker = "--="
      Default
        ; PureBasic settings fallback
        sourcelang = "purebasic"
        headerMarker = ";="
    EndSelect
    
    ;- Build RegExs Dynamically
    Restore REGEX_PATTERNS
    For i=#RE_Id_EngineFirst To #RE_Id_EngineLast
      ; The returned boolean tells us if we need to add a suffix to the patterns
      ; (which can't be stored in static data or a const due to comment delimiter
      ; depending on the source file language).
      Read.i Req_CommDel
      If Req_CommDel
        RE_Suffix.s = "^\s*" + commDel
      Else
        RE_Suffix = #Empty$
      EndIf
      Read.s RE_Pattern$
      If Not CreateRegularExpression(i, RE_Suffix + RE_Pattern$)
        ; TODO: Handle CreateRegEx fails: add Abort(err_msg)
        Debug "ERROR: Couldn't create RegEx #" + Str(i)
        End 1
      EndIf
    Next
  EndProcedure
  ;}
  
  
  ; ****************************************************************************
  ; *                                                                          *
  ;-                             PUBLIC PROCEDURES
  ; *                                                                          *
  ; ****************************************************************************
  Procedure ParseFile(SrcFileName.s)
    ;     PrintN(">>> dox::ParseFile("+SrcFileName+")") ; DELME Proc Enter Debug
    ;{>two_steps_parsing(4010)
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
    Shared sourcelang, fileEncoding, headerMarker
    Shared RegionsL()
    Shared HeaderL()
    
    ; TODO: Src File Ecoding: Could implement encoding via options for non PB files.
    #InFileFlags = #PB_File_SharedWrite | #PB_File_SharedRead   
    fileH = ReadFile(#PB_Any, SrcFileName, #InFileFlags | fileEncoding)
    FileBuffersSize(fileH, 4096 * 5)
    
    If Not fileH
      Abort(~"Couldn't open source file \"" + SrcFileName + ~"\" for reading.")
      End 1
    EndIf
    
    ; TODO: Src File Ecoding: If BOM found, could use that in all read operations!
    BOM = ReadStringFormat(fileH) ; Skip BOM!
    
    
    ; TODO: Could implement read opearions using file format from BOM! (currently only UTF-8 supported)
    PrintN("Parsing source file: " + SrcFileName)
    PrintN(LSet(#Empty$, 80, "="))
    
    ;  ============
    ;- Parser Setup
    ;  ============
    ;{>Regions_Parser_Rules(.20)
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
    ;{>Header_Parser_Rules(4100)
    ;|
    ;| === Header Parser Rules
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
    FilePos = Loc(fileH) ; Store current position in case we need to rollback
    firstline.s = ReadString(fileH)
    If Left(firstline, Len(headerMarker)) = headerMarker
      ; ============
      ; Header found
      ; ============
      ; LineNum$ = RSet(Str(cntLine), #LineNumDigits, "0") + "|"
      AddElement(HeaderL())
      HeaderL() = Right(firstline, Len(firstline)-Len(headerMarker)+1)
      HeaderLinePreview(HeaderL(), cntLine)
      cntLine +1
      ; Now every following ADoc Comment Line we'll be treatd as part of the Header,
      ; as they might contains the Author and Revision lines, or global settings attributes.
      Repeat
        FilePos = Loc(fileH) ; Store current position in case we need to rollback
        CurrLine.s = ReadString(fileH)
        If MatchRegularExpression(#RE_HeaderParseLine, CurrLine)
          If ExamineRegularExpression(#RE_HeaderParseLine, CurrLine)
            NextRegularExpressionMatch(#RE_HeaderParseLine)
            ; ///// Extract Doxter Marker /////
            lineMark.s = RegularExpressionNamedGroup(#RE_HeaderParseLine, "marker")
            ; ///// Extract Trailing Text /////
            lineTail.s = RegularExpressionNamedGroup(#RE_HeaderParseLine, "linetail")
            ; TODO: Add RegEx Else clause to catch potential errors and abort with msg  
          EndIf
          ; TODO: Convert in Select and raise error if didn't match any of these two!
          If lineMark = #mrk_SkipLine
            ; Skip Comment Lines are allowed, just ignore them and carry on parsing.
            cntLine +1
          ElseIf lineMark = #mrk_ADocLine
            AddElement(HeaderL())
            HeaderL() = lineTail
            HeaderLinePreview(HeaderL(), cntLine)
            cntLine +1
          EndIf
        Else
          ; Rollback file position and exit loop
          FileSeek(fileH, FilePos, #PB_Absolute)
          Break
        EndIf
      ForEver
    Else
      ; ===============
      ; No Header found
      ; ===============
      ; Rollback file position and exit loop
      FileSeek(fileH, FilePos, #PB_Absolute)
    EndIf
    ; ==============================================================================
    ;-                              THE REGIONS PARSER
    ; ==============================================================================
    ;{>Regions_Parser_Rules(4200.1)
    ;|
    ;| === Regions Parser Rules
    ;|
    ;| The task of the *Regions Parser* is to extract and process all lines that
    ;| are enclosed between Region Start and Region End tags, and store them in
    ;| memory.
    ;<
    ;>Regions_Parser_Rules(.30)
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
    While Eof(fileH) = 0
      CurrLine.s = ReadString(fileH)
      ; ================
      ; NEW REGEX SYSTEM
      ;{ ================
      ; The new #RE_RegionParseLine regex is used to establish beforehand if the
      ; current line is a Doxter line or not, and if it is it extracts the
      ; Marker, its Modifier, its Options and the remaining line tail into
      ; separate vars, so that a single RegEx is run once per line source,
      ; allowing the code to get faster and slimmer.
      ; ------------------------------------------------------------------------
      If MatchRegularExpression(#RE_RegionParseLine, CurrLine)
        If ExamineRegularExpression(#RE_RegionParseLine, CurrLine)
          NextRegularExpressionMatch(#RE_RegionParseLine)
          ; ///// Extract Doxter Marker /////
          lineMark.s = RegularExpressionNamedGroup(#RE_RegionParseLine, "marker")
          ; ///// Extract Marker Modifier /////
          lineModf.s = RegularExpressionNamedGroup(#RE_RegionParseLine, "modifier")
          ; ///// Extract Marker Options /////
          lineOpts.s = RegularExpressionNamedGroup(#RE_RegionParseLine, "options")
          ; ///// Extract Trailing Text /////
          lineTail.s = RegularExpressionNamedGroup(#RE_RegionParseLine, "linetail")
          
          ; DBG DELME: PREVIEW FOUND MARKERS
          ; LinePreview(CurrLine, cntLine, 666, 666)
          ; LinePreview("DBG Marker:     '"+ lineMark +"'", cntLine, 666, 666)
          ; LinePreview("DBG MarkerMod:  '"+ lineModf +"'", cntLine, 666, 666)
          ; LinePreview("DBG MarkerOpts: '"+ lineOpts +"'", cntLine, 666, 666)
          ; LinePreview("DBG Linetail:   '"+ lineTail +"'", cntLine, 666, 666)
          ; TODO: Add RegEx Else clause to catch potential errors and abort with msg  
        EndIf
      Else
        ; DBG DELME: PREVIEW NON DOXTER LINES
        ; LinePreview("DBG NOT DOX: "+CurrLine, cntLine, currWeight, currSubweight)
        lineMark.s  = #Empty$
        lineModf.s  = #Empty$
        lineOpts.s  = #Empty$
        lineTail.s  = #Empty$
      EndIf
      ;}------------------------------------------------------------------------
      ; TODO: Further optimize by branching the code intwo a block handling no
      ;       Doxter line encountered, and the other handling found Markers!
      ; TODO: Add warning tracker to stack non-fatal errors, and add warnings for
      ;       malformed or non-expected Marker Options!
      ; ------------------------------------------------------------------------
      Select ParserState
        Case #Seeking
          ; ~~~~~~~~~~~~~~~~~~~~~~~~~
          ; Parser Looking for Tag...
          ; ~~~~~~~~~~~~~~~~~~~~~~~~~
          If lineMark = #mrk_RegionStart
            ;  =========================
            ;- Region Start Marker Found
            ;  =========================
            ParserState = #InsideRegion
            If ExamineRegularExpression(#RE_RegionBeginOpts, lineOpts)
              NextRegularExpressionMatch(#RE_RegionBeginOpts)
              ; ///// Establish Region's Tag /////
              currTag = RegularExpressionNamedGroup(#RE_RegionBeginOpts, "tag")
              If currTag = #Empty$
                ; No Tag ID found, create one:
                ; ----------------------------
                currTag = #FallbackTag + Str(FallbackCnt)
                FallbackCnt +1
              EndIf
              ; NOTE: Map keys are case-sensitive:
              RegionIsNotNew = FindMapElement(RegionsTrackM(), currTag)
              ; ///// Establish Region's Weight /////
              parsedWeight.s = RegularExpressionNamedGroup(#RE_RegionBeginOpts, "weight")
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
              parsedSubweight.s = RegularExpressionNamedGroup(#RE_RegionBeginOpts, "subweight")
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
              ; TODO: Add RegEx Else clause to catch potential errors and abort with msg  
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
          If lineMark = #mrk_RegionEnd
            ;  =======================
            ;- Region End Marker Found
            ;  =======================
            ParserState = #Seeking
            ; If there was an open source block close it:
            If AddingCode
              ADocSourceEnd(currWeight)
              AddingCode = #False
            EndIf
            ; AsciiDoc Tag End Line Preview
            ; ------------------------------
            LinePreview("// end::"+ currTag + "[]", cntLine, currWeight, currSubweight)
            If Not lineModf = "<"
              ; Add blank line to ensure ADoc contents integrity.
              With RegionsL()
                AddElement(\StringsL())
                \StringsL() = #Empty$
                LinePreview(\StringsL(), 0, currWeight, currSubweight)
              EndWith
            EndIf
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
              If lineMark = #mrk_ADocLine
                ;  ------------------------------------
                ;- Curr Line Is ADoc Comment Line ("|")
                ;  ------------------------------------
                If AddingCode ; Check if we were adding source code to contents
                  ADocSourceEnd(currWeight) ; Add closing source block delimiter
                  AddingCode = #False
                EndIf
                With RegionsL()
                  AddElement(\StringsL())
                  \StringsL() = lineTail
                  LinePreview(\StringsL(), cntLine, currWeight, currSubweight)
                EndWith
              ElseIf lineMark =  #mrk_SkipLine
                ;  ------------------------------------
                ;- Curr Line Is Skip Comment Line ("~")
                ;  ------------------------------------
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
    
    CloseFile(fileH)
    
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
    PrintN("REGIONS FRAGMENTS: " + Str(totRegionsFrags)) ; DBG Stats: Regions Frags
    totUniqueRegions = MapSize(RegionsTrackM())
    PrintN("UNIQUE REGIONS: " + Str(totUniqueRegions)) ; DBG Stats: Regions Unique
    
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
      PrintN("MERGING REGIONS...") ; DBG Stats: Regions Merging Begin
      
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
      PrintN("NO REGIONS MERGING REQUIRED") ; DBG Stats: Regions Merging None
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
    
    
    ;     PrintN("<<< dox::ParseFile("+SrcFileName+")") ; DELME Proc Exit Debug
  EndProcedure
  ; ------------------------------------------------------------------------------
  Procedure SaveDocFile(OutFile.s)
    ;     PrintN(">>> dox::SaveDocFile("+OutFile+")") ; DELME Proc Enter Debug
    
    Shared HeaderL(), RegionsL()
    fileH = CreateFile(#PB_Any, OutFile, #PB_UTF8)
    If Not fileH
      Abort("Couldn't open output file for writing: "+ OutFile)
    EndIf
    
    If ListSize(HeaderL()) ; then Header not empty, dump it to file...
                           ; --------------------
                           ; Write Header to File
                           ; --------------------
      ForEach HeaderL()
        If Not WriteStringN(fileH, HeaderL())
          Abort("Couldn't write to file: "+ OutFile)
        EndIf
      Next
      ; Add blank line after Header
      If Not WriteStringN(fileH, #Empty$)
        Abort("Couldn't write to file: "+ OutFile)
      EndIf
    EndIf
    
    ; ----------------------------
    ; Write Tagged Regions to File
    ; ----------------------------
    ForEach RegionsL()
      With RegionsL()
        ForEach \StringsL()
          If Not WriteStringN(fileH, \StringsL())
            Abort("Couldn't write to file: "+ OutFile)
          EndIf
        Next
      EndWith
    Next
    
    ; Add empty line at EOL
    If Not WriteStringN(fileH, #Empty$)
      Abort("Couldn't write to file: "+ OutFile)
    EndIf
    
    CloseFile(fileH)
    
    ;     PrintN("<<< dox::SaveDocFile("+OutFile+")") ; DELME Proc Exit Debug
  EndProcedure
  ; ------------------------------------------------------------------------------
  Procedure Abort(ErrMsg.s)
    
    ConsoleError("ERROR: "+ ErrMsg)
    CloseConsole()
    End 1
    
  EndProcedure
  ; ------------------------------------------------------------------------------
  
  ; ****************************************************************************
  ; *                                                                          *
  ;-                             PRIVATE PROCEDURES
  ; *                                                                          *
  ; ****************************************************************************
  Procedure ADocSourceStart(weight = 0)
    Shared sourcelang
    Shared RegionsL()
    
    With RegionsL()
      
      AddElement(\StringsL())
      \StringsL() = #Empty$
      LinePreview(\StringsL(), 0, weight)
      
      AddElement(\StringsL())
      \StringsL() = "[source,"+ sourcelang +"]"
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
  Procedure.s LinePreview(text.s, LineNum = 0, weight = 0, subweight = 0)
    ;{-------------------------------------------------------------------
    ; Print a preview of the ADoc line, with well formated linenumber and
    ; tagged region's weight.
    ; -------------------------------------------------------------------  
    ;>Parser_Live_Preview(50000)
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
    
    ;| [role="shell",subs="+quotes,+macros"]
    ;| ----------------------------------------------------------
    ;| |0099|4100|   1|region tag, which would split the text in multiple paragraphs in the final <1>
    ;| |0100|4100|   1|document.
    ;| |0101|4100|   1|// +++end::Comments_Marks[]+++ <2>
    ;| |    |4100|   1| <3>
    ;| |0169|4101|  10|// +++tag::CLI_Usage[]+++ <4>
    ;| |0170|4101|  10|=== Command Line Options
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
  
EndModule


;}******************************************************************************
; *                                                                            *
;-                                DOCUMENTATION
; *                                                                            *
;{******************************************************************************

; All regions in the 50000 range will be commented out in the final doc:
;>(49999)
;| ////
;<
;>(59999)
;| ////
;<

;>description(.1)
;| :maindoc: doxter.asciidoc

;| <<{maindoc}#,Back to Doxter CLI documentation>>.
;<


; ==============================================================================
; 1000                                INTRO
; ==============================================================================

;>intro(1000.1)

;| == About Doxter Engine

;| Doxter Engine is the module used by Doxter to parse source files, extract the
;| documentation from them and write it to an AsciiDoc file -- this process is
;| also known as «doxterizing».

;| This module can also be included in other applications beside the Doxter CLI
;| tool, so you can use it to create your own doxterizing apps.

;| Currently, the module is still in Alpha and there is a long way to go before
;| it will be optimized to work with other apps -- custom options still need to
;| be exposed publicly to allow fine gain control over its behavior, and right
;| now all output text is sent to the console, so it will only work in console
;| applications.

;| This document deals with Doxter Engine's API and internals.
;<

; ==============================================================================
; 2000                              ENGINE API                                  
; ==============================================================================

;>api(2000.1)

;| == Engine API

;| [WARNING]
;| =============================================================================
;| The Doxter Engine API is not yet documented.
;| Until Doxter enters the Beta stage, you'll have to refer to source code to
;| learn about the API.
;| =============================================================================
;<

; ==============================================================================
; 3000                         DOXTER COMMENT MARKS                             
; ==============================================================================

; * |3000|   | Comments_Marks | == Doxter Markers Primer


; ==============================================================================
; 4000                              THE PARSER
; ==============================================================================

;>The_Parser(4000)
;| == Doxter's Parser
;|
;| Understanding how Doxter's parser works will help you grasp a clearer picture
;| of how source files are processed, and gain insight into the proper use of
;| its markers.
;<

; * |4010|   | two_steps_parsing    |  [notes on 2 steps parsing]

;>The_Parser_continue(4020)
;| Each of these parsers obeys its own rules, and the way they interpret the
;| comment markers (or ignore them) is slightly different.
;| Here follow the simple rules by which each parser abides.
;<

; * |4100|   | Header_Parser_Rules  | ==== Header Parser Rules
; * |4200|   | Regions_Parser_Rules | ==== Regions Parser Rules
; * |4200|  1| Regions_Parser_Rules |
; * |4200| 20| Regions_Parser_Rules |
; * |4200| 30| Regions_Parser_Rules |

;>The_Parser_Final_Notes(4500)
;| The above rules are going to be a useful reference when you've began learning
;| Doxter, and by studying them you can get the full picture of its inner workings.
;| But studying Doxter's main documentation and examples is a better starting
;| point if you're new to Doxter -- also, don't forget to look at source code of
;| Doxter, for it's self-documenting by its own system, and you can compare the
;| source to the AsciiDoc output and study it, if you like to learn by examples.

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
;}******************************************************************************
; *                                                                            *
;-                                  CHANGELOG
; *                                                                            *
; ******************************************************************************
;{>CHANGELOG(20000)
;| == Changelog
;|
;| * *v0.0.4-alpha* (2018/11/25) -- Engine optimizations:
;| ** The engine code has been slightly optimized to improve performance and
;|    code maintainability:
;| *** Reduced the number of RegExs used by the engine by optimizing reusability.
;| *** Source lines parsing has been optimized in both the Header Parser and the
;|     Regions Parser.
;| *** Deleted internal procedures:
;| **** `IsAdocComment()`
;| **** `IsSkipComment()`
;| **** `StripCommentLine()`
;| * *v0.0.3-alpha* (2018/10/11) -- BUG FIX: Read Alan sources as ISO-8859-1:
;| ** Add `fileEnconding` var to allow setting file read operations for Alan
;|    sources to Ascii (`#PB_Ascii`) to avoid breaking special characters that
;|    were being read as if encoded in UTF-8. 
;| * *v0.0.2-alpha* (2018/10/10) -- Add support for Alan language, and improve
;|   SpiderBasic support:
;| ** The Engine now exposes a `dox::SetEngineLang(lang.s)` procedure to allow
;|    setting the comment delimiter and the language of source blocks according
;|    to the selected language (`"PureBasic"`, `"SpiderBasic"` or `"Alan"`). 
;| * *v0.0.1-alpha* (2018/10/03) -- First module engine release.
;}<



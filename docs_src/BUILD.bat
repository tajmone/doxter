:: "BUILD.bat" v0.1.0 (2018-11-29)
:: -----------------------------------------------------------------------------
:: Update Doxter documentation to "docs" folder (served on GitHub pages too).
:: -----------------------------------------------------------------------------
@ECHO OFF & CLS
ECHO.
ECHO ==============================================================================
ECHO Updating Doxter documentation and website ...
ECHO ==============================================================================

:: ================================
:: Doxterize all source files first
:: ================================
ECHO 1) Doxterising PB Sources

CALL :doxterize ../doxter.pb
MOVE /Y ..\doxter.asciidoc .\doxter.asciidoc

CALL :doxterize ../doxter_engine.pbi
MOVE /Y ..\doxter_engine.asciidoc .\doxter_engine.asciidoc

:: ============================
:: Convert Doxter documentation
:: ============================
ECHO 2) Converting to HTML

CALL :conv2adoc index.asciidoc
CALL :conv2adoc doxter.asciidoc
CALL :conv2adoc doxter_engine.asciidoc

EXIT /B

:: =============================================================================
:: func:                       Process With Doxter
:: =============================================================================
:doxterize
ECHO Doxterizing: %~nx1
CALL ..\doxter %1 > nul
EXIT /B

:: =============================================================================
:: func:                        Convert to AsciiDoc
:: =============================================================================
:conv2adoc
ECHO Converting: %~nx1
CALL asciidoctor^
  --destination-dir ../docs/^
  --verbose^
  -S unsafe^
  -a experimental^
  -a icons=font^
  -a lang=en^
  -a reproducible^
  -a sectanchors^
  -a toc=left^
  -a source-highlighter=highlightjs^
  -a highlightjsdir=hjs^
  %~nx1
EXIT /B

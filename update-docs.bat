:: "update-docs.bat" v0.1.0 (2018-10-03)
:: -----------------------------------------------------------------------------
:: Update Doxter documentation to "docs" folder (served on GitHub pages too).
:: -----------------------------------------------------------------------------
@ECHO OFF
ECHO.
ECHO ==============================================================================
ECHO Updating Doxter documentation and website ...
ECHO ==============================================================================

:: ================================
:: Doxterize all source files first
:: ================================
ECHO 1) Doxterising PB Sources

CALL doxter doxter.pb > nul
CALL doxter doxter_engine.pbi > nul

ECHO 2) Converting to HTML

:: ============================
:: Convert Doxter documentation
:: ============================
:: Because "docs" folder is being served as a website on GitHub Pages, output
:: file will be reanmed "index.html".
CALL asciidoctor^
  --verbose^
  -S unsafe^
  -a data-uri^
  -a icons=font^
  -a toc=left^
  -a experimental^
  -a source-highlighter=highlightjs^
  -a highlightjsdir=hjs^
  -o docs/index.html^
     doxter.asciidoc
:: ===================================
:: Convert Doxter Eninge documentation
:: ===================================
:: Because "doxter" was renamed "index", we'll fix cross doc links by overriding
:: via CLI options the custom attribute "maindoc", which holds the filename for
:: cross linking.
CALL asciidoctor^
  --verbose^
  -S unsafe^
  -a data-uri^
  -a icons=font^
  -a toc=left^
  -a experimental^
  -a source-highlighter=highlightjs^
  -a highlightjsdir=hjs^
  -a maindoc=index.asciidoc^
  -o docs/doxter_engine.html^
     doxter_engine.asciidoc
EXIT /B

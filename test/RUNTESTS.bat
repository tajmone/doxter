:: -----------------------------------------------------------------------------
:: "RUNTESTS.bat" v1.0.0 (2018/11/21) by Tristano Ajmone
:: -----------------------------------------------------------------------------
@ECHO OFF
ECHO.
ECHO ******************************************************************************
ECHO *                                                                            *
ECHO *                             DOXTER TEST SUITE                              *
ECHO *                                                                            *
ECHO ******************************************************************************

ECHO.
ECHO ==============================================================================
ECHO Doxterize Source Files ...
ECHO ==============================================================================
FOR %%i IN (*.pb, *.pbi, *.pbf, *.sb, *.sbi, *.sbf, *.alan, *.i) DO (
	CALL :doxterize  %%i
)

ECHO.
ECHO ==============================================================================
ECHO Convert to HTML ...                  
ECHO ==============================================================================
FOR %%i IN (*.asciidoc, *.adoc) DO (
    CALL :conv2adoc %%i
)

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
  -S unsafe^
  -a data-uri^
  -a experimental^
  -a icons=font^
  -a reproducible^
  -a sectanchors^
  -a toc=left^
  -a source-highlighter=highlightjs^
  -a highlightjsdir=..\docs\hjs^
  --verbose^
  %1
EXIT /B

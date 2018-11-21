#!/bin/bash
# "update-docs.sh" v0.1.1 (2018-11-21)
# -----------------------------------------------------------------------------
# Update Doxter documentation to "docs" folder (served on GitHub pages too).
# -----------------------------------------------------------------------------

# ================================
# Doxterize all source files first
# ================================
echo "1) Doxterising PB Sources"

./doxter doxter.pb 1>/dev/null
./doxter doxter_engine.pbi 1>/dev/null

echo "2) Converting to HTML"

# ============================
# Convert Doxter documentation
# ============================
# Because "docs" folder is being served as a website on GitHub Pages, output
# file will be reanmed "index.html".
asciidoctor\
  --verbose\
  -S unsafe\
  -a data-uri\
  -a experimental\
  -a icons=font\
  -a reproducible\
  -a sectanchors\
  -a toc=left\
  -a source-highlighter=highlightjs\
  -a highlightjsdir=hjs\
  -o docs/index.html\
     doxter.asciidoc

# ===================================
# Convert Doxter Eninge documentation
# ===================================
# Because "doxter" was renamed "index", we'll fix cross doc links by overriding
# via CLI options the custom attribute "maindoc", which holds the filename for
# cross linking.
asciidoctor\
  --verbose\
  -S unsafe\
  -a data-uri\
  -a experimental\
  -a icons=font\
  -a reproducible\
  -a sectanchors\
  -a toc=left\
  -a source-highlighter=highlightjs\
  -a highlightjsdir=hjs\
  -a maindoc=index.asciidoc\
  -o docs/doxter_engine.html\
     doxter_engine.asciidoc


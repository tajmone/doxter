#!/bin/bash
./doxter doxter.pb
asciidoctor\
  --verbose\
  -S unsafe\
  -a data-uri\
  -a icons=font\
  -a toc=left\
  -a experimental\
  -a source-highlighter=highlightjs\
  -a highlightjsdir=hjs\
  -o docs/index.html\
  doxter.asciidoc
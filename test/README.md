# Doxter Test Suite

This folder contains sources files and scripts to test Doxter features. Run with:

- [`RUNTESTS.bat`][RUNTESTS]


-----

**Table of Contents**

<!-- MarkdownTOC autolink="true" bracket="round" autoanchor="false" lowercase="only_ascii" uri_encoding="true" levels="1,2,3" -->

- [About The Tests](#about-the-tests)
- [Tests Validation](#tests-validation)

<!-- /MarkdownTOC -->

-----

# About The Tests

The test system is very simple: the [`RUNTESTS.bat`][RUNTESTS] bacth script "doxterizes" into AsciiDoc every supported source file in this this folder, and then converts it to HTML.

Some test files target a specific feature or a set of related features, while others test multiple features at once. Filenames provide meaningful clues to the nature of the tests; more detailed information on the tests can be found in the source comments.

These tests are used during developement, to check that changes to Doxter code aren't breaking up its expected behaviour. Specifically, any changes in the tests output will be detected by Git, indicating that Doxter is now producing different output from the same source files, which could be an indicator of features break-down. The diff log of Git status can then be examined to verify the nature of the changes.

Therefore, failed tests are never commited in `master` branch, as they indicate that Doxter is behaving erraticly and needs fixing.

# Tests Validation

Tests validation is carried out manually, by visual inspection.

The final document should display a series of (manually) numbered sections and paragraphs in the correct order. A test has failed if any of the following occur:

- Some elements are displayed out of order.
- A paragraph doesn't being with a `§`.
- Spurious elements are present.

Apart from the header (if present), the documents contents are just some "Lorem ipsum" placeholders, and short source code snippets. The only relevant parts for the tests are the section and paragraph numbers. Code blocks will have their ordinal number presented via a comment line.

Here is how a final HTML document could like like:


> ### 1. Lorem Ipsum Dolor Sit Amet
> 
> § 1.1 — Lorem ipsum dolor sit amet, in usu iuvaret interesset signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in solum porro saperet nec, eu per quas inimicus.
> 
> ```purebasic
> ; ====================
> ; § 1.2 - Code Example
> ; ====================
> For i=1 To 10
>   Debug "i = " + Str(i)
> Next
> ```
> 
> ### 2. Lorem Ipsum Dolor Sit Amet
> 
> § 2.1 — Lorem ipsum dolor sit amet, in usu iuvaret interesset signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in solum porro saperet nec, eu per quas inimicus.
> 
> § 2.2 — Lorem ipsum dolor sit amet, in usu iuvaret interesset signiferumque, 
> ad quaestio conceptam scribentur vim. Cu diam reque sit, in solum porro saperet nec, eu per quas inimicus.




<!-----------------------------------------------------------------------------
                               REFERENCE LINKS                                
------------------------------------------------------------------------------>

[RUNTESTS]: ./RUNTESTS.bat "View source file"

<!-- EOF -->
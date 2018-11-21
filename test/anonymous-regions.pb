;= Anonymous Regions Test
;| Tristano Ajmone, <tajmone@gmail.com>
;| v1, November 21, 2018: Basic Test

; ------------------------------------------------------------------------------
; This is a very simple test for Anonymous Regions: it only contains bare
; *Region Begin* markers, without tag identifiers or weights (i.e. just `;>`).
; ------------------------------------------------------------------------------

;>
;| == 1. Lorem Ipsum Dolor Sit Amet
;|   
;| § 1.1 -- Lorem ipsum dolor sit amet, in usu iuvaret interesset
;| signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in
;| solum porro saperet nec, eu per quas inimicus.

; ====================
; § 1.2 - Code Example
; ====================
For i=1 To 10
  Debug "i = " + Str(i)
Next
;<

; !!! IF YOU CAN SEE ME THERE'S A BUG !!!

;>
;| == 2. Lorem Ipsum Dolor Sit Amet
;<

;>
;| § 2.1 -- Lorem ipsum dolor sit amet, in usu iuvaret interesset
;| signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in
;| solum porro saperet nec, eu per quas inimicus.
;| 
;| § 2.2 -- Lorem ipsum dolor sit amet, in usu iuvaret interesset
;| signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in
;| solum porro saperet nec, eu per quas inimicus.
;<

; !!! IF YOU CAN SEE ME THERE'S A BUG !!!

;>
;| == 3. Lorem Ipsum Dolor Sit Amet

;| § 3.1 -- Lorem ipsum dolor sit amet, in usu iuvaret interesset
;| signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in
;| solum porro saperet nec, eu per quas inimicus.
;<

; !!! IF YOU CAN SEE ME THERE'S A BUG !!!

;>
;| § 3.2 -- Lorem ipsum dolor sit amet, in usu iuvaret interesset
;| signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in
;| solum porro saperet nec, eu per quas inimicus.
;<


; EOF ;

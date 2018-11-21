;= Sorted Regions Test
;| Tristano Ajmone, <tajmone@gmail.com>
;| v1, November 21, 2018: Basic Test
; ------------------------------------------------------------------------------
; This is a simple test for Sorted Regions: it contains *Region Begin* markers
; with tag identifiers and weights, in scrambled order.
; ------------------------------------------------------------------------------

;>SecThreeB(5)
;| § 3.2 -- Lorem ipsum dolor sit amet, in usu iuvaret interesset
;| signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in
;| solum porro saperet nec, eu per quas inimicus.
;<

; !!! IF YOU CAN SEE ME THERE'S A BUG !!!

;>SecTwoB(3)
;| § 2.1 -- Lorem ipsum dolor sit amet, in usu iuvaret interesset
;| signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in
;| solum porro saperet nec, eu per quas inimicus.
;| 
;| § 2.2 -- Lorem ipsum dolor sit amet, in usu iuvaret interesset
;| signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in
;| solum porro saperet nec, eu per quas inimicus.
;<


;>SecTwoA(2)
;| == 2. Lorem Ipsum Dolor Sit Amet
;<

; !!! IF YOU CAN SEE ME THERE'S A BUG !!!


;>SecOne(1)
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

;>SecThreeA(4)
;| == 3. Lorem Ipsum Dolor Sit Amet

;| § 3.1 -- Lorem ipsum dolor sit amet, in usu iuvaret interesset
;| signiferumque, ad quaestio conceptam scribentur vim. Cu diam reque sit, in
;| solum porro saperet nec, eu per quas inimicus.
;<

; !!! IF YOU CAN SEE ME THERE'S A BUG !!!

; EOF ;

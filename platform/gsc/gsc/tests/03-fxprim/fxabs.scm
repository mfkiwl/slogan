(declare (extended-bindings) (not constant-fold) (not safe))

(define a -1)
(define b 0)
(define c 1)
(define d 357913941)
(define e 536870911)
(define f -536870911)

(define (test x)
  (println (##fxabs x)))

(test a)
(test b)
(test c)
(test d)
(test e)
(test f)

(declare (extended-bindings) (not constant-fold) (not safe))

(define f (##not 123))
(define t (##not f))
(define s "")
(define x 1.5)
(define y (##f64vector 1.5 2.5))
(define z (##list 1 2 3))

(define (test x)
  (println (##f64vector? x))
  (println (if (##f64vector? x) 11 22)))

(test 0)
(test 1)
(test f)
(test t)
(test s)
(test x)
(test y)
(test z)
(test (##cdr z))

(println (##f64vector-ref y 0))
(println (##f64vector-ref y 1))
(##f64vector-set! y 1 9.5)
(println (##f64vector-ref y 1))

(declare (extended-bindings) (not constant-fold) (not safe))

(define a 1.5)
(define b 1.5)
(define c 2.5)

(define (test2 x y)
  (println (##fl=))
  (println (if (##fl=) 11 22))
  (println (##fl= x))
  (println (if (##fl= x) 11 22))
  (println (##fl= x y))
  (println (if (##fl= x y) 11 22))
  (println (##fl= x y 17.0))
  (println (if (##fl= x y 17.0) 11 22))
  (println (##fl= x y 5.0))
  (println (if (##fl= x y 5.0) 11 22)))

(define (test x)
  (test2 x a)
  (test2 x b)
  (test2 x c))

(test a)
(test b)
(test c)

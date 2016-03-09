(declare (extended-bindings) (not constant-fold) (not safe))

(define v1 (##s32vector -2147483648 2147483647))
(define v2 (##make-s32vector 10 99))
(define v3 '#s32(1 2 3 4))

(define (bignum= x y)
  (and (##fx= (##bignum.adigit-length x)
              (##bignum.adigit-length y))
       (let loop ((i (##fx- (##bignum.adigit-length x) 1)))
         (if (and (##fx> i 0)
                  (##bignum.adigit-= x y i))
             (loop (##fx- i 1))
             (##bignum.adigit-= x y i)))))
        
(define (test v i eq)
  (let ((val (##s32vector-ref v i))) 
    (if (##fixnum? val)
        (println (if (##fx= val eq) "same" "different"))
        (println (if (bignum= val eq)  "same" "different")))))

(test v1 0 -2147483648)
(test v1 1 2147483647)
(test v2 9 99)
(test v3 3 4)

(declare (extended-bindings) (not constant-fold) (not safe))

(define (test a b)
  (let ((x (##flasin a)))
    (println (and (##fl>= x (##fl* 0.999999999999999 b))
                  (##fl<= x (##fl* 1.000000000000001 b))))))

(test 0.0 0.0)
(test 0.5 0.5235987755982988)
(test 1.0 1.5707963267948966)

(test 0.1 -9.999)

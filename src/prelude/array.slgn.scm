;; Copyright (c) 2013-2014 by Vijay Mathew Pandyalakal, All Rights Reserved.

(define (make-array dim fill constructor)
  (cond ((integer? dim)
         (if (procedure? fill)
             (let loop ((a (constructor dim))
                        (i 0))
               (cond ((< i dim)
                      (vector-set! a i (fill))
                      (loop a (+ i 1)))
                     (else a)))
             (constructor dim fill)))
        ((list? dim)
         (if (null? (cdr dim))
             (make-array (car dim) fill constructor)
             (make-array (car dim) (lambda () (make-array (cdr dim) fill constructor)) constructor)))
        (else (error "invalid array dimension. " dim))))

(define array vector)
(define (make_array dim #!optional fill) (make-array dim fill make-vector))

(define is_array vector?)

(define (vectors-ref vectors i)
  (map (lambda (v) (array_at v i)) vectors))

(define (array_at arr dim)
  (if (list? dim)
      (if (null? dim) arr
          (array_at (vector-ref arr (car dim)) (cdr dim)))
      (vector-ref arr dim)))

(define (array_set arr dim obj)
  (if (list? dim)
      (cond ((null? dim) 
             (error "array dimension cannot be empty."))
            ((= 1 (length dim))
             (vector-set! arr (car dim) obj)
             *void*)
            (else (array_set (vector-ref arr (car dim)) (cdr dim) obj)))
      (begin (vector-set! arr dim obj)
             *void*)))      

(define array_length vector-length)
(define arrays_at vectors-ref)
(define array_to_list vector->list)
(define array_copy vector-copy)
(define subarray subvector)
(define array_append vector-append)
(define array_fill vector-fill!)
(define subarray_fill subvector-fill!)
(define subarray_move subvector-move!)
(define array_shrink vector-shrink!)

(define (array_sort arr #!optional (test <) (type 'quick))
  (let ((s (sort (vector->list arr) test type))
        (len (vector-length arr)))
    (let loop ((s s) (i 0))
      (if (null? s) arr
          (begin (vector-set! arr i (car s))
                 (loop (cdr s) (+ i 1)))))))

(define (vector-map f vec . vectors)
  (if (not (null? vectors))
      (assert-equal-lengths vec vectors vector-length))
  (let ((len (vector-length vec)))
    (if (null? vectors)
        (generic-map1! f (make-vector len) vec len vector-ref vector-set!)
        (generic-map2+! f (make-vector len) (cons vec vectors) len vectors-ref vector-set!))))

(define (vector-for-each f vec . vectors)
  (if (not (null? vectors))
      (assert-equal-lengths vec vectors vector-length))
  (let ((len (vector-length vec)))
    (if (null? vectors)
        (generic-map1! f #f vec len vector-ref vector-set!)
        (generic-map2+! f #f (cons vec vectors) len vectors-ref vector-set!))))

(define array_map vector-map)
(define array_for_each vector-for-each)

(define (array_index_of arr obj #!key (test *default-eq*))
  (let ((len (vector-length arr)))
    (let loop ((i 0))
      (cond ((>= i len) -1)
            ((test (vector-ref arr i) obj) i)
            (else (loop (+ i 1)))))))

;; byte arrays.

(define u8array u8vector)
(define (make_u8array dim #!optional (fill 0)) (make-u8vector dim fill))
(define is_u8array u8vector?)
(define u8array_length u8vector-length)
(define u8array_at u8vector-ref)
(define u8array_set u8vector-set!)
(define u8array_to_list u8vector->list)
(define list_to_u8array list->u8vector)
(define u8array_fill u8vector-fill!)
(define subu8array_fill subu8vector-fill!)
(define u8array_append u8vector-append)
(define u8array_copy u8vector-copy)
(define subu8array subu8vector)
(define subu8array_move subu8vector-move!)
(define u8array_shrink u8vector-shrink!)

(define s8array s8vector)
(define (make_s8array dim #!optional (fill 0)) (make-s8vector dim fill))
(define is_s8array s8vector?)
(define s8array_length s8vector-length)
(define s8array_at s8vector-ref)
(define s8array_set s8vector-set!)
(define s8array_to_list s8vector->list)
(define list_to_s8array list->s8vector)
(define s8array_fill s8vector-fill!)
(define subs8array_fill subs8vector-fill!)
(define s8array_append s8vector-append)
(define s8array_copy s8vector-copy)
(define subs8array subs8vector)
(define subs8array_move subs8vector-move!)
(define s8array_shrink s8vector-shrink!)

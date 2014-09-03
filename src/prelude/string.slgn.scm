;; Copyright (c) 2013-2014 by Vijay Mathew Pandyalakal, All Rights Reserved.

(define make_string make-string)

(define string_is_eq string=?)
(define string_is_lteq string<=?)
(define string_is_gteq string>=?)
(define string_is_lt string<?)
(define string_is_gt string>?)
(define string_is_ci_eq string-ci=?)
(define string_is_ci_lteq string-ci<=?)
(define string_is_ci_gteq string-ci>=?)
(define string_is_ci_lt string-ci<?)
(define string_is_ci_gt string-ci>?)

(define (strings-ref ss i)
  (map (lambda (s) (string-ref s i)) ss))

(define (string-map f s . ss)
  (if (not (null? ss))
      (assert-equal-lengths s ss string-length))
  (let ((len (string-length s)))
    (if (null? ss)
        (generic-map1! f (make-string len) s len string-ref string-set!)
        (generic-map2+! f (make-string len) (cons s ss) len strings-ref string-set!))))

(define (string-for-each f s . ss)
  (if (not (null? ss))
      (assert-equal-lengths s ss string-length))
  (let ((len (string-length s)))
    (if (null? ss)
        (generic-map1! f #f s len string-ref string-set!)
        (generic-map2+! f #f (cons s ss) len strings-ref string-set!))))
  
(define (string_upcase s)
  (string-map char-upcase s))
  
(define (string_downcase s)
  (string-map char-downcase s))

(define (string_replace_all s fch rch)
  (let* ((len (string-length s))
         (result (make-string len)))
    (let loop ((i 0))
      (cond ((>= i len) result)
            ((char=? (string-ref s i) fch)
             (string-set! result i rch)
             (loop (+ i 1)))
            (else (string-set! result i (string-ref s i))
                  (loop (+ i 1)))))))
          
(define (string-starts-with? s suffix #!optional (eq string=?))
  (let ((slen (string-length suffix))
        (len (string-length s)))
    (if (or (zero? slen) (zero? len) 
            (> slen len)) #f
            (eq (substring s 0 slen) suffix))))

(define (string-ends-with? s prefix #!optional (eq string=?))
  (let ((plen (string-length prefix))
        (slen (string-length s)))
    (if (and (not (zero? plen)) (not (zero? slen)) 
             (<= plen slen))
        (let ((subs (substring s (- slen plen) slen)))
          (eq subs prefix))
        #f)))

(define (string-indexof s ch)
  (let ((len (string-length s)))
    (let loop ((i 0))
      (cond ((>= i len) -1)
            ((char=? ch (string-ref s i)) i)
            (else (loop (+ i 1)))))))

(define (string-rtrim s)
  (let ((len (string-length s)))
    (let loop ((i (- len 1)) (start #f) (result '()))
      (cond ((>= i 0)
             (if start (loop (- i 1) start (cons (string-ref s i) result))
                 (let ((c (string-ref s i)))
                   (if (char-whitespace? c)
                       (loop (- i 1) #f result)
                       (loop (- i 1) #t (cons c result))))))
            (else (list->string result))))))

(define (string-ltrim s)
  (let ((len (string-length s)))
    (let loop ((i 0) (start #f) (result '()))
      (cond ((< i len)
             (if start (loop (+ i 1) start (cons (string-ref s i) result))
                 (let ((c (string-ref s i)))
                   (if (char-whitespace? c)
                       (loop (+ i 1) #f result)
                       (loop (+ i 1) #t (cons c result))))))
            (else (list->string (reverse result)))))))

(define (string-trim s) (string-rtrim (string-ltrim s)))
      
(define is_string string?)
(define (string_starts_with s suffix) (string-starts-with? s suffix))
(define (string_ends_with s prefix) (string-ends-with? s prefix))
(define (string_ci_starts_with s suffix) (string-starts-with? s suffix string-ci=?))
(define (string_ci_ends_with s prefix) (string-ends-with? s prefix string-ci=?))
(define string_to_list string->list)
(define string_to_symbol string->symbol)
(define string_append string-append)
(define string_copy string-copy)
(define string_fill string-fill!)
(define string_length string-length)
(define string_at string-ref)
(define strings_at strings-ref)
(define string_set string-set!)
(define symbol_to_string symbol->string)
(define string_hash string=?-hash)
(define string_index_of string-indexof)
(define string_rtrim string-rtrim)
(define string_ltrim string-ltrim)
(define string_trim string-trim)
(define string_map string-map)
(define string_for_each string-for-each)

(define (string_split str #!optional (delim char-whitespace?)
                      (include-empty-strings #f))
  (if (not (or (char? delim)
               (list? delim)
               (procedure? delim))) str
      (let ((len (string-length str)))
        (let loop ((result '()) (currstr '()) (i 0))
          (cond ((>= i len)
                 (if (null? currstr)
                     (reverse result)
                     (reverse (cons (list->string (reverse currstr)) result))))
                ((or (and (list? delim) (member (string-ref str i) delim))
                     (and (char? delim) (char=? (string-ref str i) delim))
                     (and (procedure? delim) (delim (string-ref str i))))
                 (loop (if (and (null? currstr) (not include-empty-strings)) 
                           result 
                           (cons (list->string (reverse currstr)) result)) '() 
                           (+ i 1)))
                (else (loop result (cons (string-ref str i) currstr) (+ i 1))))))))

(define (string_to_number s #!optional (radix 10))
  (let ((tokenizer (make-tokenizer (open-input-string s) s)))
    (let ((port (tokenizer 'port-pos)))
      (let ((c (port-pos-peek-char port)))
        (cond ((char-numeric? c)
               (if (char=? c #\0)
                   (begin (port-pos-read-char! port)
                          (read-number-with-radix-prefix port radix))
                   (read-number port #f radix)))
              ((char=? c #\.)
               (port-pos-read-char! port)
               (if (char-numeric? (port-pos-peek-char port))
                   (read-number port #\. radix)
                   (error "Invalid number format." s)))
              (else (error "Failed to parse numeric string." s)))))))
              
(define (strings_join infix slist)
  (let loop ((slist slist) (result #f))
    (if (null? slist) result
        (loop (cdr slist) (if result (string-append result infix (car slist))
                              (car slist))))))

(define (string_titlecase s)
  (let* ((len (string-length s))
         (result (make-string len)))
    (let loop ((word-start #t) (i 0))
      (if (>= i len) result
          (let ((c (string-ref s i)))
            (cond 
             (word-start 
              (if (not (char-whitespace? c))
                  (begin (string-set! result i (char-upcase c))
                         (loop #f (+ i 1)))
                  (begin (string-set! result i (char-downcase c))
                         (loop word-start (+ i 1)))))
             (else (string-set! result i (char-downcase c))
                   (loop (char-whitespace? c) (+ i 1)))))))))
          

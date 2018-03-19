;; Copyright (c) 2013-2018 by Vijay Mathew Pandyalakal, All Rights Reserved.

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
  (scm-map (lambda (s) (string-ref s i)) ss))

(define (string-map f s . ss)
  (if (scm-not (null? ss))
      (assert-equal-lengths s ss string-length))
  (let ((len (string-length s)))
    (if (null? ss)
        (generic-map1! f (make-string len) s len string-ref string-set!)
        (generic-map2+! f (make-string len) (scm-cons s ss) len strings-ref string-set!))))

(define (string-for-each f s . ss)
  (if (scm-not (null? ss))
      (assert-equal-lengths s ss string-length))
  (let ((len (string-length s)))
    (if (null? ss)
        (generic-map1! f #f s len string-ref string-set!)
        (generic-map2+! f #f (scm-cons s ss) len strings-ref string-set!))))
  
(define (string_upcase s)
  (string-map char-upcase s))
  
(define (string_downcase s)
  (string-map char-downcase s))

(define (string_replace_all s fch rch)
  (let* ((len (string-length s))
         (result (make-string len)))
    (let loop ((i 0))
      (cond ((scm->= i len) result)
            ((char=? (string-ref s i) fch)
             (string-set! result i rch)
             (loop (scm-+ i 1)))
            (else (string-set! result i (string-ref s i))
                  (loop (scm-+ i 1)))))))
          
(define (string-starts-with? s prefix #!optional (eq string=?))
  (let ((slen (string-length prefix))
        (len (string-length s)))
    (if (or (zero? slen) (zero? len) 
            (scm-> slen len)) #f
            (eq (scm-substring s 0 slen) prefix))))

(define (string-ends-with? s suffix #!optional (eq string=?))
  (let ((plen (string-length suffix))
        (slen (string-length s)))
    (if (and (scm-not (zero? plen)) (scm-not (zero? slen)) 
             (scm-<= plen slen))
        (let ((subs (scm-substring s (scm-- slen plen) slen)))
          (eq subs suffix))
        #f)))

(define (string-indexof s ch)
  (let ((len (string-length s)))
    (let loop ((i 0))
      (cond ((scm->= i len) -1)
            ((char=? ch (string-ref s i)) i)
            (else (loop (scm-+ i 1)))))))

(define (string-rtrim s)
  (let ((len (string-length s)))
    (let loop ((i (scm-- len 1)) (start #f) (result '()))
      (cond ((scm->= i 0)
             (if start (loop (scm-- i 1) start (scm-cons (string-ref s i) result))
                 (let ((c (string-ref s i)))
                   (if (char-whitespace? c)
                       (loop (scm-- i 1) #f result)
                       (loop (scm-- i 1) #t (scm-cons c result))))))
            (else (list->string result))))))

(define (string-ltrim s)
  (let ((len (string-length s)))
    (let loop ((i 0) (start #f) (result '()))
      (cond ((scm-< i len)
             (if start (loop (scm-+ i 1) start (scm-cons (string-ref s i) result))
                 (let ((c (string-ref s i)))
                   (if (char-whitespace? c)
                       (loop (scm-+ i 1) #f result)
                       (loop (scm-+ i 1) #t (scm-cons c result))))))
            (else (list->string (scm-reverse result)))))))

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
(define string_rtrim string-rtrim)
(define string_ltrim string-ltrim)
(define string_trim string-trim)
(define string_map string-map)
(define string_for_each string-for-each)

(define (delim-proxy c f) (f c))

(define (string-split str #!optional (delim #\space) (include-empty-strings #f))
  (let ((delim? (cond ((char? delim) char=?)
                      ((list? delim) scm-member)
                      ((procedure? delim) delim-proxy)
                      (else #f))))
    (if (scm-not delim?)
        str
        (let ((len (string-length str)))
          (let loop ((result '()) (currstr '()) (i 0))
            (if (scm->= i len)
                (if (null? currstr)
                    (scm-reverse result)
                    (scm-reverse (scm-cons (list->string (scm-reverse currstr)) result)))
                (let ((c (string-ref str i)))
                  (if (delim? c delim)
                      (loop (if (and (null? currstr) (scm-not include-empty-strings))
                                result
                                (scm-cons (list->string (scm-reverse currstr)) result)) '()
                                (scm-+ i 1))
                      (loop result (scm-cons c currstr) (scm-+ i 1))))))))))

(define string_split string-split)

(define (sign-prefix? c) (or (char=? c #\-) (char=? c #\+)))

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
               (read-number port #\. radix))
              ((sign-prefix? c)
               (let ((neg? (char=? c #\-)))
                 (port-pos-read-char! port)
                 (let ((n (if (char=? (port-pos-peek-char port) #\.)
                              (begin
                                (port-pos-read-char! port)
                                (read-number port #\. radix))
                              (read-number port #f radix))))
                   (if neg? (scm-- n) n))))
              (else (scm-error "Failed to parse numeric string" s)))))))
              
(define (strings_join infix slist)
  (let loop ((slist slist) (result #f))
    (if (null? slist) result
        (loop (scm-cdr slist) (if result (string-append result infix (scm-car slist))
                              (scm-car slist))))))

(define (string_titlecase s)
  (let* ((len (string-length s))
         (result (make-string len)))
    (let loop ((word-start #t) (i 0))
      (if (scm->= i len) result
          (let ((c (string-ref s i)))
            (cond 
             (word-start 
              (if (scm-not (char-whitespace? c))
                  (begin (string-set! result i (char-upcase c))
                         (loop #f (scm-+ i 1)))
                  (begin (string-set! result i (char-downcase c))
                         (loop word-start (scm-+ i 1)))))
             (else (string-set! result i (char-downcase c))
                   (loop (char-whitespace? c) (scm-+ i 1)))))))))
          
(define (string_to_u8array s)
  (let ((len (string-length s))
        (out (open-output-u8vector)))
    (let loop ((i 0))
      (if (scm->= i len)
          (get-output-u8vector out)
          (begin (write-u8 (char->integer (string-ref s i)) out)
                 (loop (scm-+ i 1)))))))

(define (string_index_of s subs #!optional (offset 0))
  (let ((len (string-length s))
        (sublen (string-length subs)))
    (if (or (zero? len) (zero? sublen) (scm-< len sublen))
        -1
        (let loop0 ((i offset))
          (if (scm->= i len)
              -1
              (let ((orig-i i)
                    (found?
                     (let loop1 ((j 0))
                       (cond ((scm->= j sublen)
                              #t)
                             ((scm->= i len)
                              #f)
                             ((char=? (string-ref s i) (string-ref subs j))
                              (begin (set! i (scm-+ i 1))
                                     (loop1 (scm-+ j 1))))
                             (else #f)))))
                (if found?
                    orig-i
                    (loop0 (scm-+ i 1)))))))))

;; Copyright (c) 2013-2014 by Vijay Mathew Pandyalakal, All Rights Reserved.

(define (slogan tokenizer)
  (expression/statement tokenizer))

(define (import tokenizer script-name)
  (if (compile (if (symbol? script-name) 
                   (symbol->string script-name) 
                   script-name) 
               assemble: (tokenizer 'compile-mode?))
      (if (tokenizer 'compile-mode?)
          `(load ,script-name)
          `(load ,(string-append script-name *scm-extn*)))
      (error "failed to compile " script-name)))

(define (expression/statement tokenizer)
  (if (eof-object? (tokenizer 'peek))
      (tokenizer 'next)
      (let ((v (statement tokenizer)))
        (if (not v)
            (set! v (expression tokenizer)))
        (assert-semicolon tokenizer v)
        v)))

(define (statement tokenizer)
  (if (eq? (tokenizer 'peek) '*semicolon*)
      *void*
      (import-stmt tokenizer)))

(define (parser-error expr msg #!rest args)
  (error (with-output-to-string 
           msg
           (lambda ()
             (let loop ((args args))
               (if (not (null? args))
                   (begin (display (car args))
                          (loop (cdr args)))))
             (if expr
                 (begin (display ". Current parser state: ")
                        (display expr)))))))

(define (assert-semicolon tokenizer expr)
  (let ((token (tokenizer 'peek)))
    (if (or (eq? token '*semicolon*)
            (eq? token '*close-brace*)
            (eof-object? token))
        (if (eq? token '*semicolon*)
            (tokenizer 'next))
        (parser-error 
         expr "statement or expression not properly terminated after " 
         token))))

(define (import-stmt tokenizer)
  (cond ((eq? (tokenizer 'peek) 'import)
         (tokenizer 'next)
         (import tokenizer (tokenizer 'next)))
        (else
         (record-def-stmt tokenizer))))

(define (assignment-stmt tokenizer)
  (if (name? (tokenizer 'peek))
      (let ((sym (tokenizer 'next)))
        (if (eq? sym 'var)
            (define-stmt tokenizer)
            (cond ((reserved-name? sym)
                   (tokenizer 'put sym)
                   #f)
                  ((eq? (tokenizer 'peek) '*assignment*)
                   (set-stmt sym tokenizer))
                  (else (tokenizer 'put sym) 
                        #f))))
      #f))

(define (macro-def-stmt tokenizer)
  (if (eq? (tokenizer 'peek) 'macro)
      (begin (tokenizer 'next)
             (mk-macro-def (tokenizer 'next) tokenizer))
      (assignment-stmt tokenizer)))

(define-structure +macro params body)
(define *macros* (make-table))

(define (undef_macro name)
  (table-set! *macros* name #f))

(define (mk-macro-def macro-name tokenizer)
  (if (not (name? macro-name))
      (parser-error #f "invalid macro name: " macro-name))
  (table-set! 
   *macros* 
   macro-name 
   (make-+macro (macro-params tokenizer) (macro-body-expr tokenizer)))
  *void*)

(define (macro-body-expr tokenizer)
  (if (eq? (tokenizer 'peek) '*open-brace*)
      (block-expr tokenizer)
      (expression tokenizer)))

(define (macro-params tokenizer)
  (if (not (eq? '*open-paren* (tokenizer 'peek)))
      (parser-error #f "expected opening parenthesis before macro parameters. " (tokenizer 'next)))
  (tokenizer 'next)
  (let loop ((p (tokenizer 'peek))
             (params '()))
    (cond ((name? p)
           (tokenizer 'next)
           (assert-comma-separator tokenizer '*close-paren*)
           (loop (tokenizer 'peek) (append params (list p))))
          (else 
           (if (eq? '*close-paren* (tokenizer 'peek))
               (begin (tokenizer 'next)
                      params)
               (parser-error #f "expected closing parenthesis after macro parameters. " (tokenizer 'next)))))))

(define (define-stmt tokenizer)
  (if (variable? (tokenizer 'peek))
      (if (reserved-name? (tokenizer 'peek))
          (parser-error #f "reserved name cannot be used as identifier - " (tokenizer 'next))
          (var-def-set (tokenizer 'next) tokenizer #t))
      (parser-error #f "expected variable name instead of " (tokenizer 'peek))))

(define (set-stmt sym tokenizer)
  (var-def-set sym tokenizer #f))

(define (var-def-set sym tokenizer def)
  (if (table-ref *macros* sym #f)
      (parser-error #f "cannot redefine macro " sym ". first call undef_macro on it."))
  (if (eq? (tokenizer 'peek) '*assignment*)
      (begin (tokenizer 'next)
             (list (if def 'define 'set!) sym (expression tokenizer)))
      (parser-error #f "expected assignment instead of " (tokenizer 'peek))))

(define (expression tokenizer)
  (let ((expr (binary-expr tokenizer)))
    (let loop ((expr expr)) 
      (if (eq? (tokenizer 'peek) '*open-paren*)
          (loop (func-call-expr expr tokenizer))
          expr))))

(define (if-expr tokenizer)
  (cond ((eq? (tokenizer 'peek) 'if)
         (tokenizer 'next)
         (let ((expr (cons 'if (list (expression tokenizer)
                                     (expression tokenizer)))))
           (if (eq? (tokenizer 'peek) 'else)
               (begin (tokenizer 'next)
                      (if (eq? (tokenizer 'peek) 'if)
                          (append expr (list (if-expr tokenizer)))
                          (append expr (list (expression tokenizer)))))
               expr)))
        (else (case-expr tokenizer))))

(define (case-expr tokenizer)
  (cond ((eq? (tokenizer 'peek) 'case)
         (tokenizer 'next)
         (let ((value (expression tokenizer)))
           (if (not (eq? (tokenizer 'peek) '*open-brace*))
               (parser-error value "expected case body. " (tokenizer 'next))
               (tokenizer 'next))
           (let loop ((token (tokenizer 'peek))
                      (body '()))
             (if (eq? token '*close-brace*)
                 (begin (tokenizer 'next)
                        (append `(case ,value) (reverse body)))
                 (let ((expr (normalize-sym (expression tokenizer))))
                   (if (not (eq? (tokenizer 'peek) '*colon*))
                       (parser-error expr "expected colon after case expression. " (tokenizer 'next))
                       (tokenizer 'next))
                   (let ((result (expression tokenizer)))
                     (loop (tokenizer 'peek)
                           (cons (list (if (or (list? expr)
                                               (eq? expr 'else))
                                           expr
                                           (cons expr '())) 
                                       result) body))))))))
        (else (try-catch-expr tokenizer))))

(define (try-catch-expr tokenizer)
  (cond ((eq? (tokenizer 'peek) 'try)
         (tokenizer 'next)
         (let ((try-expr (expression tokenizer)))
           (case (tokenizer 'peek)
             ((catch)
              (make-try-catch-expr try-expr 
                                   (catch-args tokenizer)
                                   (expression tokenizer)
                                   (finally-expr tokenizer)))
             ((finally)
              (make-try-catch-expr try-expr
                                   '(*e*) '(raise *e*)
                                   (finally-expr tokenizer)))
             (else
              (parser-error try-expr "expected catch or finally instead of " (tokenizer 'next))))))
        (else #f)))

(define (catch-args tokenizer)
  (tokenizer 'next)
  (if (not (eq? (tokenizer 'peek) '*open-paren*))
      (parser-error #f "expected opening parenthesis instead of " (tokenizer 'next)))
  (tokenizer 'next)
  (let ((result (tokenizer 'next)))
    (if (not (variable? result))
        (parser-error #f "expected exception identifier. " result))
    (if (not (eq? (tokenizer 'peek) '*close-paren*))
        (parser-error #f "exception closing parenthesis instead of " (tokenizer 'next)))
    (tokenizer 'next)
    (list result)))

(define (finally-expr tokenizer)
  (cond ((eq? (tokenizer 'peek) 'finally)
         (tokenizer 'next)
         (expression tokenizer))
        (else *void*)))
      
(define (make-try-catch-expr try-expr catch-args catch-expr finally-expr)
  (if (void? finally-expr)
      (list 'with-exception-catcher 
            (list 'lambda catch-args catch-expr)
            (list 'lambda (list) try-expr))
      (list 'let (list (list '*finally* (list 'lambda (list) finally-expr)))
            (list 'with-exception-catcher 
                  (list 'lambda catch-args (list 'begin '(*finally*) catch-expr))
                  (list 'lambda (list) (list 'begin try-expr '(*finally*)))))))
                   
(define (normalize-sym s)
  (if (and (list? s)
           (eq? (car s) 'quote))
      (cadr s)
      s))

(define (expression-with-semicolon tokenizer)
  (let ((expr (expression tokenizer)))
    (if (eq? (tokenizer 'peek) '*semicolon*)
        (tokenizer 'next))
    expr))

(define (block-expr tokenizer #!optional (use-let #f))
  (if (not (eq? (tokenizer 'peek) '*open-brace*))
      (parser-error #f "expected block start instead of " (tokenizer 'next))
      (begin (tokenizer 'next)
             (let loop ((expr (if use-let 
				  (cons 'let (cons '() '()))
				  (cons 'begin '())))
                        (count 0))
               (let ((token (tokenizer 'peek)))
                 (if (eq? token '*close-brace*)
                     (begin (tokenizer 'next)
                            (if (zero? count)
                                (append expr (list *void*))
                                expr))
                     (loop (append expr (list (expression/statement tokenizer)))
                           (+ 1 count))))))))

(define (binary-expr tokenizer)
  (let loop ((expr (cmpr-expr tokenizer)))
    (if (and-or-opr? (tokenizer 'peek))
        (case (tokenizer 'next)
          ((*and*) (loop (swap-operands (append (and-expr tokenizer) (list expr)))))
          ((*or*) (loop (swap-operands (append (or-expr tokenizer) (list expr))))))
        expr)))
  
(define (cmpr-expr tokenizer)
  (let loop ((expr (addsub-expr tokenizer)))
    (if (cmpr-opr? (tokenizer 'peek))
        (case (tokenizer 'next)
          ((*equals*) (loop (swap-operands (append (eq-expr tokenizer) (list expr)))))
          ((*less-than*) (loop (swap-operands (append (lt-expr tokenizer) (list expr)))))
          ((*greater-than*) (loop (swap-operands (append (gt-expr tokenizer) (list expr)))))
          ((*less-than-equals*) (loop (swap-operands (append (lteq-expr tokenizer) (list expr)))))
          ((*greater-than-equals*) (loop (swap-operands (append (gteq-expr tokenizer) (list expr))))))
        expr)))

(define (addsub-expr tokenizer)
  (let loop ((expr (term-expr tokenizer)))
    (if (add-sub-opr? (tokenizer 'peek))
        (case (tokenizer 'next)
          ((*plus*) (loop (swap-operands (append (add-expr tokenizer) (list expr)))))
          ((*minus*) (loop (swap-operands (append (sub-expr tokenizer) (list expr))))))
        expr)))

(define (factor-expr tokenizer)
  (let ((token (tokenizer 'peek)))
    (if (eq? token '*open-paren*)
        (begin (tokenizer 'next)
               (let ((expr (expression tokenizer)))
                 (if (not (eq? (tokenizer 'peek) '*close-paren*))
                     (begin (parser-error expr "expected closing-parenthesis instead of " (tokenizer 'next))
                            #f)
                     (begin (tokenizer 'next)
                            (member-access/funcall-expr expr tokenizer)))))
        (let ((expr (if-expr tokenizer)))
          (if expr
              expr
              (let-expr tokenizer))))))

(define (literal-expr tokenizer)
  (let ((expr (func-def-expr tokenizer)))
    (if expr
        (member-access/funcall-expr expr tokenizer)
        (let ((token (tokenizer 'peek)))
          (cond ((or (number? token)
                     (string? token)
		     (char? token))
                 (slgn-repr->scm-repr (tokenizer 'next)))
                ((add-sub-opr? token)
                 (tokenizer 'next)
                 (let ((sub (eq? token '*minus*))
                       (expr (literal-expr tokenizer)))
                   (if sub 
                       (list '- expr)
                       expr)))
                ((variable? token)
                 (if (slgn-symbol? token)
                     `(quote ,(scm-symbol->slgn-symbol (tokenizer 'next)))
                     (let ((var (tokenizer 'next)))
                       (if (eq? (tokenizer 'peek) '*period*)
                           (begin (tokenizer 'next)
                                  (closure-member-access var tokenizer))
                           (slgn-repr->scm-repr var)))))
                ((eq? token '*open-bracket*)
                 (list-literal tokenizer))
                ((eq? token '*open-brace*)
                 (block-expr tokenizer #t))
                ((eq? token '*hash*)
                 (array-literal tokenizer))
                (else
                 (parser-error expr "invalid literal expression: " (tokenizer 'next))))))))

(define (member-access/funcall-expr expr tokenizer)
  (cond ((eq? (tokenizer 'peek) '*period*)
         (begin (tokenizer 'next)
                (closure-member-access expr tokenizer)))
        ((eq? (tokenizer 'peek) '*open-paren*)
         (func-call-expr expr tokenizer))
        (else 
         expr)))

(define (list-literal tokenizer)
  (tokenizer 'next)
  (let loop ((result (list 'list))
             (first #t))
    (let ((token (tokenizer 'peek)))
      (if (eq? token '*close-bracket*)
          (begin (tokenizer 'next)
                 (reverse result))
          (let ((expr (expression tokenizer)))
            (let ((pl (if first
                          (let ((t (tokenizer 'peek)))
                            (not (or (eq? t '*comma*)
                                     (eq? t '*close-bracket*))))
                          #f)))
              (if pl
                  (pair-literal expr tokenizer)
                  (begin (assert-comma-separator tokenizer '*close-bracket*)
                         (loop (cons expr result) #f)))))))))

(define (pair-literal expr tokenizer)
  (let ((result (list 'cons expr (expression tokenizer))))
    (if (not (eq? (tokenizer 'peek) '*close-bracket*))
        (parser-error expr "pair not terminated. " (tokenizer 'next))
        (begin (tokenizer 'next)
               result))))

(define (array-literal tokenizer)
  (tokenizer 'next)
  (if (eq? (tokenizer 'peek) '*open-bracket*)
      (begin (tokenizer 'next)
             (let loop ((expr (list 'vector))
                        (token (tokenizer 'peek)))
               (cond ((eq? token '*close-bracket*)
                      (tokenizer 'next)
                      (reverse expr))
                     (else 
                      (let ((e (expression tokenizer)))
                        (assert-comma-separator tokenizer '*close-bracket*)
                        (loop (cons e expr) (tokenizer 'peek)))))))
      (parser-error #f "invalid start of array literal. " (tokenizer 'next))))

(define (let-expr tokenizer)
  (let ((letkw (letkw? (tokenizer 'peek))))
    (cond (letkw
	   (tokenizer 'next)
	   (let loop ((result '()))
	     (let ((sym (tokenizer 'next)))
	       (if (not (name? sym))
		   (parser-error #f "expected name instead of " sym))
	       (if (reserved-name? sym)
		   (parser-error #f "invalid variable name " sym))
	       (if (eq? (tokenizer 'peek) '*assignment*)
		   (tokenizer 'next)
		   (parser-error #f "expected assignment instead of " (tokenizer 'next)))
	       (let ((expr (expression tokenizer)))
		 (cond ((eq? (tokenizer 'peek) '*comma*)
			(tokenizer 'next)
			(loop (append result (list (list sym expr)))))
		       (else (append (list letkw) 
				     (cons (append result (list (list sym expr))) 
					   (list (func-body-expr tokenizer))))))))))
	  (else 
	   (func-call-expr (literal-expr tokenizer) tokenizer)))))

(define (letkw? sym)
  (if (and (symbol? sym)
	   (or (eq? sym 'let)
	       (eq? sym 'letseq)
	       (eq? sym 'letrec)))
      (cond ((eq? sym 'letseq)
             'let*)
            (else sym))
      #f))

(define (func-def-expr tokenizer)
  (if (eq? (tokenizer 'peek) 'function)
      (begin (tokenizer 'next)
             (merge-lambda (list 'lambda (func-params-expr tokenizer)) 
                           (func-body-expr tokenizer)))
      #f))

(define (merge-lambda lambda-expr lambda-body)
  (if (not (list? lambda-body))
      (merge-lambda lambda-expr (list 'begin lambda-body))
      (if (<= 1 (length lambda-body))
          (append lambda-expr (list lambda-body))
          (let loop ((lambda-expr lambda-expr)
                     (lambda-body (if (eq? (car lambda-body) 'begin)
                                      (cdr lambda-body)
                                      lambda-body)))
            (if (null? lambda-body)
                lambda-expr
                (loop (append lambda-expr (list (car lambda-body)))
                      (cdr lambda-body)))))))

(define (func-body-expr tokenizer)
  (if (eq? (tokenizer 'peek) '*open-brace*)
      (block-expr tokenizer)
      (expression tokenizer)))

(define (func-call-expr func-val tokenizer)
  (if (and (name? func-val)
           (table-ref *macros* func-val #f))
      (macro-call-expr func-val tokenizer)
      (cond ((eq? (tokenizer 'peek) '*open-paren*)
             (tokenizer 'next)
             (let ((expr (cons func-val (func-args-expr tokenizer))))
               (if (eq? (tokenizer 'peek) '*close-paren*)
                   (begin (tokenizer 'next) 
                          expr)
                   (parser-error expr "expected closing-parenthesis after function argument list instead of " (tokenizer 'next)))))
            (else func-val))))

(define (macro-call-expr macro-name tokenizer)
  (if (not (eq? (tokenizer 'peek) '*open-paren*))
      (parser-error "expected macro argument list. " (tokenizer 'next))
      (tokenizer 'next))
  (let ((m (table-ref *macros* macro-name))
        (args (func-args-expr tokenizer)))
    (if (eq? (tokenizer 'peek) '*close-paren*)
        (tokenizer 'next)
        (parser-error #f "expected closing-parenthesis after macro arguments. " (tokenizer 'next)))
    (expand-macro macro-name m args)))

(define (expand-macro macro-name m args)
  (if (not (= (length (+macro-params m)) (length args)))
      (parser-error #f "macro " macro-name " expects exactly " (length (+macro-params m)) " arguments."))
  (replace_all (replace_all (+macro-body m) (mk-eval-macro-params (+macro-params m)) args transform: eval)
               (+macro-params m) args))

(define (mk-eval-macro-params params)
  (let loop ((params params)
             (result '()))
    (cond ((null? params)
           (reverse result))
          (else
           (loop (cdr params) (cons (string->symbol (string-append "~" (symbol->string (car params)))) result))))))

(define (record-def-stmt tokenizer)
  (if (eq? (tokenizer 'peek) 'record)
      (begin (tokenizer 'next)
	     (let ((token (tokenizer 'peek)))
	       (if (not (variable? token))
		   (parser-error #f "expected record name. " (tokenizer 'next)))
	       (mk-record-expr (tokenizer 'next) tokenizer)))
      (macro-def-stmt tokenizer)))

(define (mk-record-expr name tokenizer)
  (if (eq? (tokenizer 'peek) '*open-paren*)
      (begin (tokenizer 'next)
	     (let loop ((token (tokenizer 'peek))
			(members '()))
	       (cond ((variable? token)
		      (set! token (tokenizer 'next))
		      (assert-comma-separator tokenizer '*close-paren*)
		      (loop (tokenizer 'peek) (cons token members)))
		     ((eq? token '*close-paren*)
		      (tokenizer 'next)
		      (def-struct-expr name (reverse members)))
		     (else
		      (parser-error #f "invalid record specification. " (tokenizer 'next))))))
      (parser-error #f "expected record member specification. " (tokenizer 'next))))

(define (def-struct-expr name members)
  (append (list 'begin
		(append (list 'define-structure name) members))
	  (mk-struct-accessors/modifiers name members)))

(define (mk-record-constructor recname members)
  (list 'lambda (append (list '#!key) members)
        (cons (string->symbol (string-append "make-" recname))
              members)))

(define (mk-struct-accessors/modifiers name members)
  (let ((sname (symbol->string name)))
    (let loop ((members members)
               (expr (list (list 'define (string->symbol sname) 
                                 (mk-record-constructor sname members))
                           (list 'define 
                                 (string->symbol (string-append "is_" sname))
                                 (string->symbol (string-append sname "?"))))))
      (if (null? members)
          (reverse expr)
          (begin (loop (cdr members)
                       (append expr (member-accessor/modifier name (car members)))))))))

(define (member-accessor/modifier name mem)
  (let ((sname (symbol->string name))
	(smem (symbol->string mem)))
    (let ((scm-accessor (string->symbol (string-append sname "-" smem)))
	  (scm-modifier (string->symbol (string-append sname "-" smem "-set!")))
	  (slgn-accessor (string->symbol (string-append sname "_" smem)))
	  (slgn-modifier (string->symbol (string-append sname "_set_" smem))))
      (list (list 'define slgn-accessor scm-accessor)
	    (list 'define slgn-modifier scm-modifier)))))

(define (assert-comma-separator tokenizer end-seq-char)
  (let ((token (tokenizer 'peek)))
    (if (or (eq? token '*comma*)
            (eq? token end-seq-char))
        (if (eq? token '*comma*) (tokenizer 'next))
        (parser-error #f "expected comma or " end-seq-char " instead of " (tokenizer 'next)))))

(define (func-args-expr tokenizer)
  (let loop ((args '()))
    (let ((token (tokenizer 'peek)))
      (if (not (eq? token '*close-paren*))
          (cond ((variable? token)
                 (let ((sym (tokenizer 'next)))
                   (if (eq? (tokenizer 'peek) '*assignment*)
                       (begin (tokenizer 'next)
                              (let ((expr (expression tokenizer)))
                                (assert-comma-separator tokenizer '*close-paren*)
                                (loop (append args (list (slgn-variable->scm-keyword sym) expr)))))
                       (begin (tokenizer 'put sym)
                              (let ((expr (expression tokenizer)))
                                (assert-comma-separator tokenizer '*close-paren*)
                                (loop (append args (list expr))))))))
                (else
                 (let ((expr (expression tokenizer)))
                   (assert-comma-separator tokenizer '*close-paren*)
                   (loop (append args (list expr))))))
          args))))

(define (func-params-expr tokenizer)
  (if (eq? (tokenizer 'peek) '*open-paren*)
      (begin (tokenizer 'next)
             (let loop ((params '()))
               (let ((token (tokenizer 'peek)))
                 (cond ((variable? token)
                        (let ((sym (tokenizer 'next)))
                          (if (reserved-name? sym)
                              (parser-error #f "function parameter cannot be a reserved name. " sym))
                          (cond ((param-directive? sym)
                                 (loop (cons (slgn-directive->scm-directive sym) params)))
                                ((eq? (tokenizer 'peek) '*assignment*)
                                 (tokenizer 'next)
                                 (let ((expr (expression tokenizer)))
                                   (assert-comma-separator tokenizer '*close-paren*)
                                   (loop (cons (list sym expr) params))))
                                (else 
                                 (assert-comma-separator tokenizer '*close-paren*)
                                 (loop (cons sym params))))))
                       (else 
                        (if (eq? token '*close-paren*)
                            (begin (tokenizer 'next)
                                   (reverse params))
                            (parser-error #f "expected closing-parenthesis after parameter list instead of " (tokenizer 'next))))))))
      (parser-error #f "expected opening-parenthesis at the start of parameter list instead of " (tokenizer 'next))))

(define (param-directive? sym)
  (memq sym '(@optional @key @rest)))

(define (closure-member-access var tokenizer)
  (if (variable? (tokenizer 'peek))
      (let loop ((expr `(,var ',(tokenizer 'next))))
	(if (eq? (tokenizer 'peek) '*period*)
	    (begin (tokenizer 'next)
		   (if (variable? (tokenizer 'peek))
		       (loop (cons expr `(',(tokenizer 'next))))
		       (parser-error expr "expected name instead of " (tokenizer 'next))))
	    expr))
      (parser-error #f "expected name instead of " (tokenizer 'next))))

(define (add-expr tokenizer)
  (swap-operands (cons '+ (list (term-expr tokenizer)))))

(define (sub-expr tokenizer)
  (swap-operands (cons '- (list (term-expr tokenizer)))))

(define (mult-expr tokenizer)
  (swap-operands (cons '* (list (factor-expr tokenizer)))))

(define (div-expr tokenizer)
  (swap-operands (cons '/ (list (factor-expr tokenizer)))))

(define (eq-expr tokenizer)
  (swap-operands (cons 'eqv? (list (addsub-expr tokenizer)))))

(define (lt-expr tokenizer)
  (swap-operands (cons '< (list (addsub-expr tokenizer)))))

(define (lteq-expr tokenizer)
  (swap-operands (cons '<= (list (addsub-expr tokenizer)))))

(define (gt-expr tokenizer)
  (swap-operands (cons '> (list (addsub-expr tokenizer)))))

(define (gteq-expr tokenizer)
  (swap-operands (cons '>= (list (addsub-expr tokenizer)))))

(define (and-expr tokenizer)
  (swap-operands (cons 'and (list (cmpr-expr tokenizer)))))

(define (or-expr tokenizer)
  (swap-operands (cons 'or (list (cmpr-expr tokenizer)))))

(define (term-expr tokenizer)
  (let loop ((expr (factor-expr tokenizer)))
    (if (mult-div-opr? (tokenizer 'peek))
        (case (tokenizer 'next)
          ((*asterisk*) (loop (swap-operands (append (mult-expr tokenizer) (list expr)))))
          ((*backslash*) (loop (swap-operands (append (div-expr tokenizer) (list expr))))))
        expr)))

(define (add-sub-opr? token)
  (or (eq? token '*plus*)
      (eq? token '*minus*)))

(define (mult-div-opr? token)
  (or (eq? token '*asterisk*)
      (eq? token '*backslash*)))

(define (cmpr-opr? token)
  (or (eq? token '*equals*)
      (eq? token '*less-than*)
      (eq? token '*greater-than*)
      (eq? token '*less-than-equals*)
      (eq? token '*greater-than-equals*)))

(define (and-or-opr? token)
  (or (eq? token '*and*)
      (eq? token '*or*)))

(define (swap-operands expr)
  (if (= 3 (length expr))
      (list (car expr) (caddr expr) (cadr expr))
      expr))

(define (variable? sym)
  (and (symbol? sym)
       (char-valid-name-start? (string-ref (symbol->string sym) 0))))

(define (reserved-name? sym)
  (and (symbol? sym)
       (memq sym '(var import record if case try catch finally
                       function let letseq letrec macro))))

(define (name? sym) 
  (or (variable? sym)
      (reserved-name? sym)))

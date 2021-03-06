;;;
;;; Name:     imath-test.scm
;;; Purpose:  Code to generate random rational number test cases.
;;; Notes:    Written for DrScheme (PLT Scheme)
;;;
(require (lib "27.ss" "srfi"))

;; Generate a random natural number with the specified number
;; of digits.
(define (random-big-natural digits)
  (let loop ((d "") (digits digits))
    (if (zero? digits)
        (string->number d 10)
        (let ((rnd (random 10)))
          (loop (string-append d (list->string
                                  (list
                                   (integer->char
                                    (+ rnd
                                       (char->integer #\0))))))
                (- digits 1))))))

(define (random-big-integer digits pneg)
  (let ((base (random-big-natural digits)))
    (if (< (random-real) pneg)
        (* base -1)
        base)))

;; Generate a random rational number with the specified number
;; of numerator and denominator digits.  The pneg parameter is
;; the probability that the generated value will be negative.
(define (random-big-rational n-digits d-digits pneg)
  (let ((num (random-big-natural n-digits))
        (den (random-big-natural d-digits)))
    (if (zero? den)
        (random-big-rational n-digits d-digits pneg)
        (if (< (random-real) pneg)
            (- (/ num den))
            (/  num den)))))

;; Create a rational generator with a fixed negative probability.
;; Always generates rationals.
(define (make-rat-generator prob-neg)
  (lambda (n-digits d-digits num)
    (random-big-rational n-digits d-digits prob-neg)))

;; Create a rational generator with a fixed negative probability.
;; With probability prob-backref, generates a back-reference to
;; an earlier input value, rather than a new value.  This is
;; used to make sure argument overlapping works the way it should.
(define (make-backref-generator prob-neg prob-backref)
  (lambda (n-digits d-digits num)
    (if (and (> num 1)
             (< (random-real) prob-backref))
        (let ((ref (+ (random (- num 1)) 1)))
          (string-append "=" (number->string ref)))
        (random-big-rational n-digits d-digits prob-neg))))

;; Just like make-backref-generator, except the second argument is
;; always an integer, and the backreference can only be to the first
;; argument.
(define (make-backref-generator-2 prob-neg prob-backref)
  (lambda (n-digits d-digits num)
    (case num
      ((1) (random-big-rational n-digits d-digits prob-neg))
      ((2) (random-big-integer n-digits prob-neg))
      (else
       (if (< (random-real) prob-backref)
           "=1"
           (random-big-rational n-digits d-digits prob-neg))))))

(define (make-output-test-generator prob-neg max-dig)
  (lambda (n-digits d-digits num)
    (cond ((= num 1)
           (random-big-rational n-digits d-digits prob-neg))
          ((= num 2)
           (let loop ((radishes '(10 16 8 4 2)))
             (cond ((null? radishes)
                    (+ (random 34) 2))
                   ((< (random-real) 0.3)
                    (car radishes))
                   (else
                    (loop (cdr radishes))))))
          (else
           (random max-dig))
          )))

;; Given a test name, an argument generator, and an operation to
;; compute the desired solution, return a function that generates
;; a random test case for a given number of digits of precision
;; in the numerator and denominator.
(define (make-test-case-generator name arg-gen op)
  (lambda (n-digits d-digits)
    (let ((args (list (arg-gen n-digits d-digits 1)
                      (arg-gen n-digits d-digits 2)
                      (arg-gen n-digits d-digits 3))))
      (let* ((arg1 (car args))
             (arg2 (if (equal? (cadr args) "=1")
                       arg1 (cadr args)))
             (soln (if (and (eq? op /)
                            (zero? arg2))
                       "$MP_UNDEF"
                       (op arg1 arg2))))
        (list
         name
         args
         (list soln))))))

;; Glue strings together with the specified joiner.
(define (join-strings joiner lst)
  (cond ((null? lst) "")
        ((null? (cdr lst)) (car lst))
        (else
         (string-append (car lst) joiner
                        (join-strings joiner (cdr lst))))))

;; Convert a test case generated by a test case generator function
;; into a writable string, in the format used by imtest.c
(define (test-case->string tcase)
  (let ((s (open-output-string))
        (stringify (lambda (v)
                     (let ((s (open-output-string)))
                       (display v s)
                       (get-output-string s)))))
    (display (car tcase) s)
    (display ":" s)
    (display (join-strings "," (map stringify (cadr tcase)))
             s)
    (display ":" s)
    (display (join-strings "," (map stringify (caddr tcase)))
             s)
    (get-output-string s)))

;; Some syntactic sugar for simple counting loops.
(define-syntax for
  (syntax-rules (= to step)
    ((_ var = lo to hi body ...)
     (let loop ((var lo))
       (cond ((<= var hi)
              (begin body ...)
              (loop (+ var 1))))))
    ((_ var = lo to hi step expr body ...)
     (let loop ((var lo))
       (cond ((<= var hi)
              (begin body ...)
              (loop (+ var expr))))))
    ((_ var = hi downto lo body ...)
     (let loop ((var hi))
       (cond ((>= var lo)
              (begin body ...)
              (loop (- var 1))))))
    ((_ var = hi downto lo step expr body ...)
     (let loop ((var hi))
       (cond ((>= var lo)
              (begin body ...)
              (loop (- var expr))))))
    ))

(define qadd (make-test-case-generator
              'qadd (make-backref-generator 0.3 0.2) +))
(define qsub (make-test-case-generator
              'qsub (make-backref-generator 0.3 0.2) -))
(define qmul (make-test-case-generator
              'qmul (make-backref-generator 0.3 0.2) *))
(define qdiv (make-test-case-generator
              'qdiv (make-backref-generator 0.3 0.2) /))
(define qtodec (make-test-case-generator
                'qtodec (make-output-test-generator 0.3 25)
                (lambda (a b) '?)))
(define qaddz (make-test-case-generator
               'qaddz (make-backref-generator-2 0.3 0.2) +))
(define qsubz (make-test-case-generator
               'qsubz (make-backref-generator-2 0.3 0.2) -))
(define qmulz (make-test-case-generator
               'qmulz (make-backref-generator-2 0.3 0.2) *))
(define qdivz (make-test-case-generator
               'qdivz (make-backref-generator-2 0.3 0.2) /))

(define (write-test-cases test-fn lo-size hi-size num-each fname)
  (let ((out (open-output-file fname)))
    (for num = lo-size to hi-size
         (for den = hi-size downto lo-size
              (for ctr = 1 to num-each
                   (display (test-case->string (test-fn num den))
                            out)
                   (newline out))))
    (close-output-port out)))

(define (write-lots-of-tests)
;  (write-test-cases qadd 1 20 2 "qadd.t")
;  (write-test-cases qsub 1 20 2 "qsub.t")
 ; (write-test-cases qmul 1 20 2 "qmul.t")
;  (write-test-cases qdiv 1 20 2 "qdiv.t")
 ; (write-test-cases qtodec 1 20 2 "qtodec.t")
  (write-test-cases qaddz 1 20 2 "qaddz.t")
  (write-test-cases qsubz 1 20 2 "qsubz.t")
  (write-test-cases qmulz 1 20 2 "qmulz.t")
  (write-test-cases qdivz 1 20 2 "qdivz.t"))

;;; -*- Mode: LISP; Package: Specware; Base: 10; Syntax: Common-Lisp -*-

(in-package "PARSER4")

;;; ========================================================================
;;;
;;;  TODO: In doc: still refers to SW3
;;;  TODO: In doc: Change references to modules
;;;  TODO: In doc: Remove reference to spec-definition within a spec
;;;  TODO: In doc: import sc-term, not just spec-name
;;;  TODO: In doc: sort-declaration now uses qualified name, not just name
;;;  TODO: In doc: sort-definition now uses qualified name, not just name
;;;  TODO: In doc: op-declaration now uses qualified name, not just name
;;;  TODO: In doc: op-definition now uses qualified name, not just name
;;;  TODO: In doc: use "=", not :EQUALS in claim definition
;;;  TODO: In doc: sort-quotient relation is expression, but that's ambiguous -- need tight-expression
;;;
;;; ========================================================================
;;;
;;;  TODO: In code: compare op-definition with doc
;;;  TODO: In code: We should add :record* as a parser production.
;;;  TODO: In code: Re-enable field selection
;;;
;;; ========================================================================
;;;
;;;  TODO: In doc and code: The syntax for naming axioms is pretty ugly
;;;
;;; ========================================================================
;;;
;;;  NOTE: :LOCAL-SORT-VARIABLE as :CLOSED-SORT       would introduce ambiguities, so we parse as :SORT-REF          and post-process
;;;  NOTE: :LOCAL-VARIABLE      as :CLOSED-EXPRESSION would introduce ambiguities, so we parse as :ATOMIC-EXPRESSION and post-process
;;;
;;;  NOTE: We use normally use :NAME whereever the doc says :NAME,
;;;        but use :NON_KEYWORD_NAME instead for :SORT-NAME and :LOCAL-VARIABLE
;;;
;;;  NOTE: "{}" is parsed directly as :UNIT-PRODUCT-SORT,
;;;        but in the documentation, it's viewed as 0 entries in :SORT-RECORD

;;; ========================================================================
;;;  Primitives
;;; ========================================================================

(define-sw-parser-rule :SYMBOL    () nil nil :documentation "Primitive")
(define-sw-parser-rule :STRING    () nil nil :documentation "Primitive")
(define-sw-parser-rule :NUMBER    () nil nil :documentation "Primitive")
(define-sw-parser-rule :CHARACTER () nil nil :documentation "Primitive")

;;; These simplify life...

;;; The rationale for :NON_KEYWORD_NAME --
;;;
;;; If we were to use :SYMBOL everywhere in a rule, e.g.
;;;
;;; (define-sw-parser-rule :FOO ()
;;;   (:tuple "foo" (1 :SYMBOL) (2 :SYMBOL) (3 :SYMBOL))
;;;   (foo 1 2 3)
;;;
;;; then after substitutions we'd get lisp forms such as
;;;  (foo x y z)
;;; where the names x y z would be viewed as lisp variables.
;;;
;;; But if we use :NON_KEYWORD_NAME instead, e.g.:
;;;
;;; (define-sw-parser-rule :FOO ()
;;;   (:tuple "foo" (1 :NON_KEYWORD_NAME) (2 :NON_KEYWORD_NAME) (3 :NON_KEYWORD_NAME))
;;;   (foo 1 2 3)
;;;
;;; then after substitutions we'd get lisp forms such as
;;;  (foo "x" "y" "z")
;;; where "x", "y" "z" are the symbol-name's of the symbols x y z
;;;
;;; There might be simpler schemes, but this works well enough...

(define-sw-parser-rule :NON_KEYWORD_NAME ()
  (1 :SYMBOL)
  (lisp::symbol-name (quote 1)))

(define-sw-parser-rule :EQUALS ()
  (:anyof "=" "is"))

;;;  NOTE: We use normally use :NAME whereever the doc says :NAME,
;;;        but use :NON_KEYWORD_NAME instead for :SORT-NAME and :LOCAL-VARIABLE
(define-sw-parser-rule :NAME ()
  (:anyof
   ((:tuple "=")                   "=") ; so we can refer to = (and "is" ?) as an operator in a term
   ((:tuple "*")                   "*") ; so we can refer to * as an operator in a term
   ((:tuple "translate")      "translate") ; so we can use translate as a function
   ((:tuple "colimit")        "colimit") ; so we can use colimit as a function
   ((:tuple "diagram")        "diagram") ; so we can use diagram as a function
   ((:tuple "print")          "print") ; so we can use print as a function
   ((:tuple (1 :NON_KEYWORD_NAME)) 1)
   ))

;;; ========================================================================
;;; The first rules are those for the spec calculus. Such rules are all
;;; prefixed with SC-. It would be nice if the grammar could be factored
;;; but it may not be straightforward. For instance, imports refer to SC terms.
;;; ========================================================================

;;; ========================================================================
;;;  TOPLEVEL
;;; ========================================================================

(define-sw-parser-rule :TOPLEVEL () ; toplevel needs to be anyof rule
  (:anyof
    (1 :SC-TOPLEVEL-TERM)
    (1 :SC-TOPLEVEL-DECLS))
  (1))

;; (:tuple (1 :FILE-DECLS))
;; (define-sw-parser-rule :FILE-DECLS ()
;;     (1 (:repeat :SC-DECL nil))
;;   1)

(define-sw-parser-rule :SC-TOPLEVEL-TERM ()
  (:tuple (1 :SC-TERM))
  (make-sc-toplevel-term 1 ':left-lc ':right-lc))

(define-sw-parser-rule :SC-TOPLEVEL-DECLS ()
  (:tuple (1 :SC-DECLS))
  (make-sc-toplevel-decls 1 ':left-lc ':right-lc))

(define-sw-parser-rule :SC-DECLS ()
  (1 (:repeat :SC-DECL nil))
  (list . 1))

(define-sw-parser-rule :SC-DECL ()
  (:tuple  (1 :NAME) :EQUALS (2 :SC-TERM))
  (make-sc-decl 1 2 ':left-lc ':right-lc))

;;; ========================================================================
;;;  SC-TERM
;;; ========================================================================

(define-sw-parser-rule :SC-TERM ()
  (:anyof
   (1 :SC-PRINT)
   (1 :SC-URI)
   (1 :SPEC-DEFINITION)
   (1 :SC-LET)
   (1 :SC-WHERE)
   (1 :SC-TRANSLATE)
   (1 :SC-QUALIFY)
   (1 :SC-DIAG)
   (1 :SC-COLIMIT)
   ;; (1 :SC-DOM)
   ;; (1 :SC-COD)
   ;; (1 :SC-LIMIT)
   ;; (1 :SC-APEX)
   ;; (1 :SC-SHAPE)
   ;; (1 :SC-DIAG-MORPH)
   (1 :SC-SPEC-MORPH)
   (1 :SC-HIDE)
   (1 :SC-EXPORT)
   (1 :SC-GENERATE))
  1)

;;; ========================================================================
;;;  SC-PRINT
;;; ========================================================================

(define-sw-parser-rule :SC-PRINT ()
  (:tuple "print" (1 :SC-TERM))
  (make-sc-print 1 ':left-lc ':right-lc))

;;; ========================================================================
;;;  SC-URI
;;; ========================================================================

;; The following does not correspond to syntax in RFC 2396. It is not clear
;; that it should. Perhaps, a URI below should evaluate
;; to something of the form given in the RFC.

;; Because things come through the tokenizer, the rules below permit
;; white space between path elements and the white space is lost. We treat
;; ".." as a special path element. While it is supported in the RFC for
;; relative paths, it is not part standard URI grammar.

;; Maybe one day we will want network addresses.

(define-sw-parser-rule :SC-URI ()
  (:anyof
   (1 :SC-ABSOLUTE-URI)
   (1 :SC-RELATIVE-URI))
  1)

(define-sw-parser-rule :SC-ABSOLUTE-URI ()
  (:tuple "/" (1 :SC-URI-PATH) (:optional (:tuple "#" (2 :NAME))))
  (make-sc-absolute-uri 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :SC-RELATIVE-URI ()
  (:tuple (1 :SC-URI-PATH) (:optional (:tuple "#" (2 :NAME))))
  (make-sc-relative-uri 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :SC-URI-PATH ()
  (:tuple (1 (:repeat :SC-URI-ELEMENT "/")))
  (list . 1))

;; The following is a horrible hack. We want ".." as a path element
;; but the tokenizer treats "." as a special character. The way things
;; are below, one could put white space between successive "."'s.
;; Should really change things in the tokenizer.
(define-sw-parser-rule :SC-URI-ELEMENT ()
  (:anyof
    ((:tuple (1 :NAME))  1)
    ((:tuple "..")     "..")
  ))

;;; ========================================================================
;;;  SPEC-DEFINITION
;;;  http://www.specware.org/manual/html/modules.html
;;;  TODO: In doc: Change references to modules
;;; ========================================================================

(define-sw-parser-rule :SPEC-DEFINITION ()
  (:anyof
   (:tuple "spec" (1 (:optional :QUALIFIER)) "{" (2 (:optional :DECLARATION-SEQUENCE)) "}")
   (:tuple "spec" (1 (:optional :QUALIFIER)) (2 (:optional :DECLARATION-SEQUENCE)) :END-SPEC))
  (make-spec-definition 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :END-SPEC ()
  (:anyof "end" "end-spec"))

(define-sw-parser-rule :DECLARATION-SEQUENCE ()
  (1 (:repeat :DECLARATION nil))
  (list . 1))

;;; ========================================================================
;;;  DECLARATION
;;;  http://www.specware.org/manual/html/declarations.html
;;; ========================================================================

(define-sw-parser-rule :DECLARATION ()
  (:anyof
   (1 :IMPORT-DECLARATION)
   (1 :SORT-DECLARATION)
   (1 :OP-DECLARATION)
   (1 :DEFINITION))
  1)

;;;  TODO: In doc: Remove reference to spec-definition within a spec
(define-sw-parser-rule :DEFINITION ()
  (:anyof
   (1 :SORT-DEFINITION)
   (1 :OP-DEFINITION)
   (1 :CLAIM-DEFINITION))
   ;; (1 :SPEC-DEFINITION)  ;; obsolete
  1)

;;; ------------------------------------------------------------------------
;;;  IMPORT-DECLARATION
;;; ------------------------------------------------------------------------

;;;  TODO: In doc: import sc-term, not just spec-name
(define-sw-parser-rule :IMPORT-DECLARATION ()
  (:tuple "import" (1 :SC-TERM))
  (make-import-declaration 1 ':left-lc ':right-lc))

;;; ------------------------------------------------------------------------
;;;  SORT-DECLARATION
;;; ------------------------------------------------------------------------

;;;  TODO: In doc: sort-declaration now uses qualified name, not just name
(define-sw-parser-rule :SORT-DECLARATION ()
  (:tuple "sort" (1 :QUALIFIABLE-SORT-NAME) (:optional (2 :FORMAL-SORT-PARAMETERS)))
  (make-sort-declaration 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :FORMAL-SORT-PARAMETERS ()
  (:anyof :SINGLE-SORT-VARIABLE :LOCAL-SORT-VARIABLE-LIST))

(define-sw-parser-rule :SINGLE-SORT-VARIABLE ()
  (1 :LOCAL-SORT-VARIABLE)
  (list 1))    ; e.g. "x" => (list "x")

(define-sw-parser-rule :LOCAL-SORT-VARIABLE-LIST ()
  (:tuple "(" (1 (:repeat :LOCAL-SORT-VARIABLE ",")) ")")
  (list . 1)) ; e.g. ("x" "y" "z") => (list "x" "y" "z")

(define-sw-parser-rule :LOCAL-SORT-VARIABLE ()
  (1 :NON_KEYWORD_NAME) ; don't allow "="
  1)

;;; ------------------------------------------------------------------------
;;;  SORT-DEFINITION
;;; ------------------------------------------------------------------------

;;;  TODO: In doc: sort-definition now uses qualified name, not just name
(define-sw-parser-rule :SORT-DEFINITION ()
  (:tuple "sort" (1 :QUALIFIABLE-SORT-NAME) (:optional (2 :FORMAL-SORT-PARAMETERS)) :EQUALS (3 :SORT))
  (make-sort-definition 1 2 3 ':left-lc ':right-lc))

;;; ------------------------------------------------------------------------
;;;  OP-DECLARATION
;;; ------------------------------------------------------------------------

;;;  TODO: In doc: op-declaration now uses qualified name, not just name
(define-sw-parser-rule :OP-DECLARATION ()
  (:tuple "op" (1 :QUALIFIABLE-OP-NAME) (:optional (2 :FIXITY)) ":" (3 :SORT-SCHEME))
  (make-op-declaration 1 2 3 ':left-lc ':right-lc))

(define-sw-parser-rule :FIXITY ()
  (:tuple (1 :ASSOCIATIVITY) (2 :PRIORITY))
  (make-fixity 1 2 ':left-lc ':right-lc))

#||
If we want the precedence to be optional:
(define-sw-parser-rule :FIXITY ()
  (:anyof
   ((:tuple "infixl" (:optional (1 :NAT-LITERAL))) (make-fixity :|Left| 1 ':left-lc ':right-lc))
   ((:tuple "infixr" (:optional (1 :NAT-LITERAL))) (make-fixity :|Left| 1 ':left-lc ':right-lc))
||#

(define-sw-parser-rule :ASSOCIATIVITY ()
  (:anyof
   ((:tuple "infixl")  :|Left|)
   ((:tuple "infixr")  :|Right|)))

(define-sw-parser-rule :PRIORITY ()
  :NUMBER) ; we want a raw number here, not a :NAT-LITERAL

(define-sw-parser-rule :SORT-SCHEME ()
  (:tuple (:optional (1 :SORT-VARIABLE-BINDER)) (2 :SORT))
  (make-sort-scheme 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :SORT-VARIABLE-BINDER ()
  (:tuple "fa" (1 :LOCAL-SORT-VARIABLE-LIST))
  1)

;;; ------------------------------------------------------------------------
;;;  OP-DEFINITION
;;; ------------------------------------------------------------------------

;;;  TODO: In doc: op-definition now uses qualified name, not just name
;;;  TODO: In code: compare op-definition with doc
(define-sw-parser-rule :OP-DEFINITION ()
  (:tuple "def"
          (:optional (1 :SORT-VARIABLE-BINDER))
          (2 :QUALIFIABLE-OP-NAME)
          (:optional (3 :FORMAL-PARAMETERS))
          (:optional (:tuple ":" (4 :SORT)))
          :EQUALS
          (5 :EXPRESSION))
  (make-op-definition 1 2 3 4 5 ':left-lc ':right-lc))

(define-sw-parser-rule :FORMAL-PARAMETERS ()
  (1 (:repeat :FORMAL-PARAMETER))
  (list . 1))

(define-sw-parser-rule :FORMAL-PARAMETER ()
  :CLOSED-PATTERN)

;;; ------------------------------------------------------------------------
;;;  CLAIM-DEFINITION
;;; ------------------------------------------------------------------------

;;;  TODO: In doc: use "=", not :EQUALS in claim definition
(define-sw-parser-rule :CLAIM-DEFINITION ()
  ;; :EQUALS would be too confusing. e.g. "axiom x = y" would mean "axiom named x is defined as y"
  (:tuple (1 :CLAIM-KIND) (2 :LABEL) "is" (3 :CLAIM))
  (make-claim-definition 1 2 3 ':left-lc ':right-lc))

(define-sw-parser-rule :CLAIM-KIND ()
  (:anyof ((:tuple "axiom")       :|Axiom|)
          ((:tuple "theorem")     :|Theorem|)
          ((:tuple "conjecture")  :|Conjecture|)))

;;;  TODO: In doc and code: The syntax for naming axioms is pretty ugly
(define-sw-parser-rule :LABEL ()
  :ANY-TEXT-UP-TO-EQUALS)

;;;  TODO: In doc and code: The syntax for naming axioms is pretty ugly
(define-sw-parser-rule :ANY-TEXT-UP-TO-EQUALS ()
  (1 (:repeat :DESCRIPTION-ELEMENT nil))
  (make-claim-name (list . 1)))

;;;  TODO: In doc and code: The syntax for naming axioms is pretty ugly
(define-sw-parser-rule :DESCRIPTION-ELEMENT ()
  (:anyof
   :NON_KEYWORD_NAME
   :NUMBER_AS_STRING
   :STRING
   :CHARACTER
   "true" "false" "fa" "ex"
   "module" "spec" "import" "sort" "def" "op" "end"
   "fn" "case" "of" "let" "if" "then" "else" "in"
   "project" "relax" "restrict" "quotient" "choose" "embed" "embed?"
   "select" "as" "infixl" "infixr"
   "axiom" "theorem" "conjecture"
   "_" "::" ":" "->" "|" "(" ")" "[" "]" "{" "}" "*" "." "/" ","
   ))

(define-sw-parser-rule :NUMBER_AS_STRING ()
  (:tuple (1 :NUMBER))
  (format nil "~D" 1))

(define-sw-parser-rule :CLAIM ()
  (:tuple (:optional (1 :SORT-QUANTIFICATION)) (2 :EXPRESSION))
  (cons 1 2))

(define-sw-parser-rule :SORT-QUANTIFICATION ()
  (:tuple "sort" (1 :SORT-VARIABLE-BINDER))
  1)

;;; ========================================================================
;;;   SORT
;;;   http://www.specware.org/manual/html/sorts.html
;;; ========================================================================

(define-sw-parser-rule :SORT ()
  (:anyof
   (1 :SORT-SUM                :documentation "Co-product sort")
   (1 :SORT-ARROW              :documentation "Function sort")
   (1 :SLACK-SORT              :documentation "Slack sort")
   )
  1)

(define-sw-parser-rule :SLACK-SORT ()
  (:anyof
   (1 :SORT-PRODUCT            :documentation "Product sort")
   (1 :TIGHT-SORT              :documentation "Tight sort")
   )
  1)

(define-sw-parser-rule :TIGHT-SORT ()
  (:anyof
   (1 :SORT-INSTANTIATION      :documentation "Sort instantiation")
   (1 :CLOSED-SORT             :documentation "Closed sort -- unambiguous termination")
   )
  1)

(define-sw-parser-rule :CLOSED-SORT ()
  (:anyof
   (1 :SORT-REF                :documentation "Qualifiable sort name")  ; could refer to sort or sort variable
   (1 :SORT-RECORD             :documentation "Sort record")
   (1 :SORT-RESTRICTION        :documentation "Sort restriction")
   (1 :SORT-COMPREHENSION      :documentation "Sort comprehension")
   (1 :SORT-QUOTIENT           :documentation "Sort quotient")
   (1 :PARENTHESIZED-SORT      :documentation "Parenthesized Sort")
   )
  1)

;;; ------------------------------------------------------------------------
;;;   SORT-SUM
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :SORT-SUM ()
  (:tuple (1 (:repeat :SORT-SUMMAND nil)))
  (make-sort-sum (list . 1) ':left-lc ':right-lc))

(define-sw-parser-rule :SORT-SUMMAND ()
  (:tuple "|" (1 :CONSTRUCTOR) (:optional (2 :SLACK-SORT)))
  (make-sort-summand 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :CONSTRUCTOR ()
  :NAME)

;;; ------------------------------------------------------------------------
;;;   SORT-ARROW
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :SORT-ARROW ()
  (:tuple (1 :ARROW-SOURCE) "->" (2 :SORT))
  (make-sort-arrow 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :ARROW-SOURCE ()
  (:anyof :SORT-SUM :SLACK-SORT))

;;; ------------------------------------------------------------------------
;;;   SORT-PRODUCT
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :SORT-PRODUCT ()
  (:tuple (1 :TIGHT-SORT) "*" (2 (:repeat :TIGHT-SORT "*")))
  (make-sort-product (list 1 . 2) ':left-lc ':right-lc))

;;; ------------------------------------------------------------------------
;;;   SORT-INSTANTIATION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :SORT-INSTANTIATION ()
  ;; Don't use :SORT-REF for first arg, since that could
  ;;  refer to sort variables as well as sorts,
  ;;  which we don't want to allow here.
  (:tuple (1 :QUALIFIABLE-SORT-NAME) (2 :ACTUAL-SORT-PARAMETERS))
  (make-sort-instantiation 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :ACTUAL-SORT-PARAMETERS ()
  (:anyof
   ((:tuple (1 :CLOSED-SORT))       (list 1))
   ((:tuple (1 :PROPER-SORT-LIST))  1)
   ))

(define-sw-parser-rule :PROPER-SORT-LIST ()
  (:tuple "(" (1 :SORT) "," (2 (:repeat :SORT ",")) ")")
  (list 1 . 2))

;;; ------------------------------------------------------------------------

(define-sw-parser-rule :QUALIFIABLE-SORT-NAME ()
  (:anyof :UNQUALIFIED-SORT-NAME :QUALIFIED-SORT-NAME))

(define-sw-parser-rule :UNQUALIFIED-SORT-NAME ()
  (1 :SORT-NAME)
  (ATerm::mkUnQualifiedId 1))

(define-sw-parser-rule :QUALIFIED-SORT-NAME ()
  (:tuple (1 :QUALIFIER) "." (2 :SORT-NAME))
  (ATerm::mkQualifiedId 1 2))

(define-sw-parser-rule :QUALIFIER ()
  (1 :NAME)
  1)

;;;  NOTE: We use normally use :NAME whereever the doc says :NAME,
;;;        but use :NON_KEYWORD_NAME instead for :SORT-NAME and :LOCAL-VARIABLE
(define-sw-parser-rule :SORT-NAME ()
  :NON_KEYWORD_NAME)

;;; ------------------------------------------------------------------------
;;;   SORT-REF
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :SORT-REF ()
  (1 :QUALIFIABLE-SORT-NAME)
  (make-sort-ref 1 ':left-lc ':right-lc))

;;; ------------------------------------------------------------------------
;;;   SORT-RECORD
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :SORT-RECORD ()
  (:anyof
   (1 :UNIT-PRODUCT-SORT)
   (:tuple "{" (1 :FIELD-SORT-LIST) "}"))
  1)

;;;  NOTE: "{}" is parsed directly as :UNIT-PRODUCT-SORT,
;;;        but in the documentation, it's viewed as 0 entries in :SORT-RECORD
;;;  TODO: In code: We should add :record* as a parser production.
(define-sw-parser-rule :UNIT-PRODUCT-SORT ()
  (:anyof
   (:tuple "{" "}")
   (:tuple "(" ")"))
  (make-sort-record  nil        ':left-lc ':right-lc) :documentation "Unit product")

(define-sw-parser-rule :FIELD-SORT-LIST ()
  (1 (:repeat :FIELD-SORT ","))
  (make-sort-record  (list . 1) ':left-lc ':right-lc) :documentation "Record Sort")

(define-sw-parser-rule :FIELD-SORT ()
  (:tuple (1 :FIELD-NAME) ":" (2 :SORT))
  (make-field-sort 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :FIELD-NAME ()
  :NAME)

;;; ------------------------------------------------------------------------
;;;   SORT-RESTRICTION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :SORT-RESTRICTION ()
  ;; The multiple uses of "|" in the grammar complicates this rule.
  ;; E.g., without parens required here, sort comprehension {x : Integer | f x}
  ;; could be parsed as a one-element field sort with x of type (Integer | f x).
  ;; But with parens required here, that would need to be {x : (Integer | f x)}
  ;; to get that effect.
  (:tuple "(" (1 :SLACK-SORT) "|" (2 :EXPRESSION) ")")
  (make-sort-restriction 1 2 ':left-lc ':right-lc) :documentation "Subsort")

;;; ------------------------------------------------------------------------
;;;   SORT-COMPREHENSION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :SORT-COMPREHENSION ()
  (:tuple "{" (1 :ANNOTATED-PATTERN) "|" (2 :EXPRESSION) "}")
  (make-sort-comprehension 1 2 ':left-lc ':right-lc) :documentation "Sort comprehension")

;;; ------------------------------------------------------------------------
;;;   SORT-QUOTIENT
;;; ------------------------------------------------------------------------

;;;  TODO: In doc: sort-quotient relation is expression, but that's ambiguous -- need tight-expression
(define-sw-parser-rule :SORT-QUOTIENT ()
  (:tuple (1 :CLOSED-SORT) "/" (2 :TIGHT-EXPRESSION)) ; CLOSED-EXPRESSION?
  (make-sort-quotient 1 2 ':left-lc ':right-lc) :documentation "Quotient")

;;; ------------------------------------------------------------------------
;;;   PARENTHESIZED-SORT
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :PARENTHESIZED-SORT ()
  (:tuple "(" (1 :SORT) ")")
  1)

;;; ========================================================================
;;;   EXPRESSION
;;;   http://www.specware.org/manual/html/expressions.html
;;; ========================================================================

(define-sw-parser-rule :EXPRESSION ()
  (:anyof
   (1 :LAMBDA-FORM      :documentation "Function definition")
   (1 :CASE-EXPRESSION  :documentation "Case")
   (1 :LET-EXPRESSION   :documentation "Let")
   (1 :IF-EXPRESSION    :documentation "If-then-else")
   (1 :QUANTIFICATION   :documentation "Quantification (fa/ex)")
   (1 :TIGHT-EXPRESSION :documentation "Tight expression -- suitable for annotation")
   )
  1)

(define-sw-parser-rule :NON-BRANCH-EXPRESSION ()
  (:anyof
   (1 :NON-BRANCH-LET-EXPRESSION  :documentation "Let not ending in case or lambda")
   (1 :NON-BRANCH-IF-EXPRESSION   :documentation "If-then-else not ending in case or lambda")
   (1 :NON-BRANCH-QUANTIFICATION  :documentation "Quantification (fa/ex) not ending in case or lambda")
   (1 :TIGHT-EXPRESSION           :documentation "Tight expression -- suitable for annotation")
   )
  1)

(define-sw-parser-rule :TIGHT-EXPRESSION ()
  (:anyof
   (1 :APPLICATION          :documentation "Application")
   (1 :ANNOTATED-EXPRESSION :documentation "Annotated (i.e. typed) expression")
   (1 :CLOSED-EXPRESSION    :documentation "Closed expression -- unambiguous termination")
   )
  1)

;;;  UNQUALIFIED-OP-REF is outside SELECTABLE-EXPRESSION to avoid ambiguity with "A.B.C"
;;;   being both SELECT (C, TWO-NAME-EXPRESSION (A,B))
;;;          and SELECT (C, SELECT (B, UNQUALIFIED-OP-REF A))
;;;  "X . SELECTOR" will be parsed as TWO-NAME-EXPRESSION and be disambiguated in post-processing
(define-sw-parser-rule :CLOSED-EXPRESSION ()
  (:anyof
   (1 :UNQUALIFIED-OP-REF     :documentation "Op reference or Variable reference")
   (1 :SELECTABLE-EXPRESSION  :documentation "Closed expression -- unambiguous termination")
   )
  1)

;;;  NOTE: An expressions such as A.B is a three-way ambiguous selectable-expression :
;;;         OpRef (Qualified (A,B))
;;;         Select (B, OpRef (Qualified (unqualified, A)))
;;;         Select (B, VarRef A)
;;;        So we parse as TWO-NAME-EXPRESSION and resolve in post-processing.
(define-sw-parser-rule :SELECTABLE-EXPRESSION ()
  (:anyof
   (1 :TWO-NAME-EXPRESSION        :documentation "Reference to op or var, or selection")  ; resolve in post-processing
   ;; (1 :QUALIFIED-OP-REF        :documentation "Qualified reference to op")             ; see TWO-NAME-EXPRESSION
   ;; (1 :FIELD-SELECTION         :documentation "Field Selection")                       ; see TWO-NAME-EXPRESSION
   (1 :LITERAL                    :documentation "Literal: Boolean, Nat, Character, String")
   (1 :FIELD-SELECTION            :documentation "Selection")
   (1 :TUPLE-DISPLAY              :documentation "Tuple")
   (1 :RECORD-DISPLAY             :documentation "Record")
   (1 :SEQUENTIAL-EXPRESSION      :documentation "Sequence of expressions")
   (1 :LIST-DISPLAY               :documentation "List")
   (1 :STRUCTOR                   :documentation "Project, Embed, etc.")
   (1 :PARENTHESIZED-EXPRESSION   :documentation "Parenthesized expression")
   (1 :MONAD-EXPRESSION           :documentation "Monadic expression")
   )
  1)

;;; ------------------------------------------------------------------------
;;;   UNQUALIFIED-OP-REF
;;; ------------------------------------------------------------------------

;;; Note: If a dot follows, this production will become a dead-end,
;;;       since dot is not legal after a TIGHT-EXPRESSION,
;;;       but the competing TWO-NAME-EXPRESSION may succeed.
(define-sw-parser-rule :UNQUALIFIED-OP-REF ()
  (:tuple (1 :NAME))
  (make-unqualified-op-ref 1 ':left-lc ':right-lc))

;;; ------------------------------------------------------------------------
;;;   NAME-DOT-NAME
;;; ------------------------------------------------------------------------

;;; Note: Without the dot, this production fails,
;;;       but the competing UNQUALIFIED-OP-REF may succeed.
(define-sw-parser-rule :TWO-NAME-EXPRESSION ()
  (:tuple (1 :NAME) "." (2 :NAME))
  (make-two-name-expression 1 2 ':left-lc ':right-lc))

;;; ------------------------------------------------------------------------
;;;   LAMBDA-FORM
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :LAMBDA-FORM ()
  (:tuple "fn" (1 :MATCH))
  (make-lambda-form 1 ':left-lc ':right-lc)
  :documentation "Lambda abstraction")

;;; ------------------------------------------------------------------------
;;;   CASE-EXPRESSION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :CASE-EXPRESSION ()
  (:tuple "case" (1 :EXPRESSION) "of" (2 :MATCH))
  (make-case-expression 1 2 ':left-lc ':right-lc)
  :documentation "Case statement")

;;; ------------------------------------------------------------------------
;;;   LET-EXPRESSION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :LET-EXPRESSION ()
  (:anyof
   ((:tuple "let" (1 :RECLESS-LET-BINDING)      "in" (2 :EXPRESSION)) (make-let-binding-term     1 2 ':left-lc ':right-lc) :documentation "Let Binding")
   ((:tuple "let" (1 :REC-LET-BINDING-SEQUENCE) "in" (2 :EXPRESSION)) (make-rec-let-binding-term 1 2 ':left-lc ':right-lc) :documentation "RecLet Binding")
   ))

(define-sw-parser-rule :NON-BRANCH-LET-EXPRESSION () ; as above, but not ending with "| .. -> .."
  (:anyof
   ((:tuple "let" (1 :RECLESS-LET-BINDING)      "in" (2 :NON-BRANCH-EXPRESSION)) (make-let-binding-term     1 2 ':left-lc ':right-lc) :documentation "Let Binding")
   ((:tuple "let" (1 :REC-LET-BINDING-SEQUENCE) "in" (2 :NON-BRANCH-EXPRESSION)) (make-rec-let-binding-term 1 2 ':left-lc ':right-lc) :documentation "RecLet Binding")
   ))

(define-sw-parser-rule :RECLESS-LET-BINDING ()
 (:tuple (1 :PATTERN) :EQUALS (2 :EXPRESSION))
 (make-recless-let-binding 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :REC-LET-BINDING-SEQUENCE ()
  (1 (:repeat :REC-LET-BINDING nil))
  (list . 1))

(define-sw-parser-rule :REC-LET-BINDING ()
  (:tuple "def" (1 :NAME) (2 :FORMAL-PARAMETER-SEQUENCE) (:optional (:tuple ":" (3 :SORT))) :EQUALS (4 :EXPRESSION))
  (make-rec-let-binding 1 2 3 4 ':left-lc ':right-lc))

(define-sw-parser-rule :FORMAL-PARAMETER-SEQUENCE ()
  (1 (:repeat :FORMAL-PARAMETER ""))
  (list . 1))

;;; ------------------------------------------------------------------------
;;;   IF-EXPRESSION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :IF-EXPRESSION ()
  (:tuple "if" (1 :EXPRESSION) "then" (2 :EXPRESSION) "else" (3 :EXPRESSION))
  (make-if-expression 1 2 3 ':left-lc ':right-lc)  :documentation "If-Then-Else")

(define-sw-parser-rule :NON-BRANCH-IF-EXPRESSION () ; as above, but not ending with "| .. -> .."
  (:tuple "if" (1 :EXPRESSION) "then" (2 :EXPRESSION) "else" (3 :NON-BRANCH-EXPRESSION))
  (make-if-expression 1 2 3 ':left-lc ':right-lc)  :documentation "If-Then-Else")

;;; ------------------------------------------------------------------------
;;;   QUANTIFICATION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :QUANTIFICATION ()
  (:tuple (1 :QUANTIFIER) (2 :LOCAL-VARIABLE-LIST) (3 :EXPRESSION))
  (make-quantification 1 2 3 ':left-lc ':right-lc)
  :documentation "Quantification")

(define-sw-parser-rule :NON-BRANCH-QUANTIFICATION () ; as above, but not ending with "| .. -> .."
  (:tuple (1 :QUANTIFIER) (2 :LOCAL-VARIABLE-LIST) (3 :NON-BRANCH-EXPRESSION))
  (make-quantification 1 2 3 ':left-lc ':right-lc)
  :documentation "Quantification")

(define-sw-parser-rule :QUANTIFIER ()
 (:anyof
  ((:tuple "fa")  forall-op)
  ((:tuple "ex")  exists-op)))

(define-sw-parser-rule :LOCAL-VARIABLE-LIST ()
  (:tuple "(" (1 (:repeat :ANNOTATED-VARIABLE ",")) ")")
  (make-local-variable-list (list . 1) ':left-lc ':right-lc))

(define-sw-parser-rule :ANNOTATED-VARIABLE ()
  (:tuple (1 :LOCAL-VARIABLE) (:optional (:tuple ":" (2 :SORT))))
  (make-annotated-variable 1 2 ':left-lc ':right-lc))

;;;  NOTE: We use normally use :NAME whereever the doc says :NAME,
;;;        but use :NON_KEYWORD_NAME instead for :SORT-NAME and :LOCAL-VARIABLE
(define-sw-parser-rule :LOCAL-VARIABLE ()
  :NON_KEYWORD_NAME)

;;; ------------------------------------------------------------------------
;;;   APPLICATION
;;; ------------------------------------------------------------------------

;;; Application is greatly complicated by the possibility of infix operators,
;;; overloading, type inference, etc.  See the description of Applications
;;; in http://www.specware.org/manual/html/expressions.html
;;;
;;; :APPLICATION        ::= :PREFIX-APPLICATION | :INFIX-APPLICATION
;;; :PREFIX-APPLICATION ::= :APPLICATION-HEAD :ACTUAL-PARAMETER
;;; :APPLICATION-HEAD   ::= :CLOSED-EXPRESSION | :PREFIX-APPLICATION
;;; :ACTUAL-PARAMETER   ::= :CLOSED-EXPRESSION
;;; :INFIX-APPLICATION  ::= :ACTUAL-PARAMETER :QUALIFIABLE-OP-NAME :ACTUAL-PARAMETER
;;;
;;; Note that if "P N Q" (e.g. "P + Q") reduces to
;;;  :CLOSED-EXPRESSION :QUALIFIABLE-OP-NAME :CLOSED-EXPRESSION
;;; then it can be reduced
;;;  => :INFIX-APPLICATION                                     [ (+ P Q)   ]
;;; or
;;;  => :APPLICATION-HEAD :ACTUAL-PARAMETER :ACTUAL-PARAMETER  [ P + Q     ]
;;;  => :PREFIX-APPLICATION :ACTUAL-PARAMETER                  [ (P +) Q   ]
;;;  => :APPLICATION-HEAD :ACTUAL-PARAMETER                    [ (P +) Q   ]
;;;  => :PREFIX-APPLICATION                                    [ ((P +) Q) ]
;;;
;;; Also, "P M Q N R" might parse as "(P M Q) N R" or "P M (Q N R)",
;;; depending on precedences of M and N.
;;; For now, the parser here does not have access to the necessary information
;;; to resolve such things, so the disambiguation is done in a post-processing
;;; phase.  See <sw>/meta-slang/infix.sl

(define-sw-parser-rule :APPLICATION ()
  (:tuple (1 :CLOSED-EXPRESSION) (2 :CLOSED-EXPRESSIONS)) ;  (:optional (:tuple ":" (3 :SORT)))
  (make-application 1 2 ':left-lc ':right-lc) ; see notes above
  :documentation "Application")

(define-sw-parser-rule :CLOSED-EXPRESSIONS ()
  (1 (:repeat :CLOSED-EXPRESSION))
  (list . 1))

;;; ------------------------------------------------------------------------
;;;   ANNOTATED-EXPRESSION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :ANNOTATED-EXPRESSION ()
  ;;  "P : S1 : S2" is legal,  meaning P is of type S1, which is also of type S2
  (:tuple (1 :TIGHT-EXPRESSION) ":" (2 :SORT))
  (make-annotated-expression 1 2 ':left-lc ':right-lc)
  :documentation "Annotated term")

;;; ------------------------------------------------------------------------

(define-sw-parser-rule :QUALIFIABLE-OP-NAME ()
  (:anyof :UNQUALIFIED-OP-NAME :QUALIFIED-OP-NAME))

(define-sw-parser-rule :UNQUALIFIED-OP-NAME ()
  (1 :OP-NAME)
  (ATerm::mkUnQualifiedId 1))

(define-sw-parser-rule :QUALIFIED-OP-NAME ()
  (:tuple (1 :QUALIFIER) "." (2 :OP-NAME))
  (ATerm::mkQualifiedId 1 2))

(define-sw-parser-rule :OP-NAME ()
  (1 :NAME)
  1)

;;; ------------------------------------------------------------------------
;;;   LITERAL
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :LITERAL ()
  (:anyof
   :BOOLEAN-LITERAL
   :NAT-LITERAL
   :CHAR-LITERAL
   :STRING-LITERAL))

(define-sw-parser-rule :BOOLEAN-LITERAL ()
  (:anyof
   ((:tuple "true")  (make-boolean-literal t   ':left-lc ':right-lc))
   ((:tuple "false") (make-boolean-literal nil ':left-lc ':right-lc))
   ))

(define-sw-parser-rule :NAT-LITERAL ()
  (1 :NAT) ; A sequence of digits -- see lexer for details
  (make-nat-literal 1 ':left-lc ':right-lc))

(define-sw-parser-rule :NAT () :NUMBER) ; more explicit synonym

(define-sw-parser-rule :CHAR-LITERAL ()
  (1 :CHARACTER) ; see lexer for details, should be same as in following comment
  (make-char-literal 1 ':left-lc ':right-lc))

;;; :CHAR-LITERAL        ::= #:CHAR-LITERAL-GLYPH
;;; :CHAR-LITERAL-GLYPH  ::= :CHAR-GLYPH | "
;;; :CHAR-GLYPH          ::= :LETTER | :DECIMAL-DIGIT | :OTHER-CHAR-GLYPH
;;; :OTHER-CHAR-GLYPH    ::=  ! | : | @ | # | $ | % | ^ | & | * | ( | ) | _ | - | + | =
;;;                         | | | ~ | ` | . | , | < | > | ? | / | ; | ' | [ | ] | { | }
;;;                         | \\ | \"
;;;                         | \a | \b | \t | \n | \v | \f | \r | \s
;;;                         | \x :HEXADECIMAL-DIGIT :HEXADECIMAL-DIGIT
;;;  :HEXADECIMAL-DIGIT  ::= :DECIMAL-DIGIT | a | b | c | d | e | f | A | B | C | D | E | F

(define-sw-parser-rule :STRING-LITERAL ()
  (1 :STRING) ; see lexer for details, should be same as in following comment
  (make-string-literal 1 ':left-lc ':right-lc))

;;; :STRING-LITERAL         ::= " :STRING-BODY "
;;; :STRING-BODY            ::= { :STRING-LITERAL-GLYPH }*
;;; :STRING-LTIERAL-GLYPH   ::= :CHAR-GLYPH | :SIGNIFICANT-WHITESPACE
;;; :SIGNIFICANT-WHITESPACE ::= space | tab | newline

;;; ------------------------------------------------------------------------
;;;   FIELD-SELECTION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :FIELD-SELECTION ()
  (:tuple (1 :SELECTABLE-EXPRESSION) "." (2 :FIELD-SELECTOR))
  (make-field-selection 2 1 ':left-lc ':right-lc))  ;; fix

(define-sw-parser-rule :FIELD-SELECTOR ()
  (:anyof
   ((:tuple (1 :NAT))         (make-nat-selector        1 ':left-lc ':right-lc))
   ((:tuple (1 :FIELD-NAME))  (make-field-name-selector 1 ':left-lc ':right-lc))
   ))

;;; ------------------------------------------------------------------------
;;;  TUPLE-DISPLAY
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :TUPLE-DISPLAY ()
  (:tuple "(" (:optional (1 :TUPLE-DISPLAY-BODY)) ")")
  (make-tuple-display 1 ':left-lc ':right-lc)
  :documentation "Tuple")

(define-sw-parser-rule :TUPLE-DISPLAY-BODY ()
  (:tuple (1 :EXPRESSION) "," (2 (:repeat :EXPRESSION ",")))
  (list 1 . 2))

;;; ------------------------------------------------------------------------
;;;  RECORD-DISPLAY
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :RECORD-DISPLAY ()
  (:tuple "{" (:optional (1 :RECORD-DISPLAY-BODY)) "}")
  1
  :documentation "Record")

(define-sw-parser-rule :RECORD-DISPLAY-BODY ()
  (1 (:repeat :FIELD-FILLER ","))
  (make-record-display (list . 1) ':left-lc ':right-lc)
  :documentation "Record")

(define-sw-parser-rule :FIELD-FILLER ()
  (:tuple (1 :FIELD-NAME) "=" (2 :EXPRESSION))
  (make-field-filler 1 2 ':left-lc ':right-lc))

;;; ------------------------------------------------------------------------
;;;  SEQUENTIAL-EXPRESSION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :SEQUENTIAL-EXPRESSION ()
  (:tuple "(" (1 :OPEN-SEQUENTIAL-EXPRESSION) ")")
  1
  :documentation "Sequence")

(define-sw-parser-rule :OPEN-SEQUENTIAL-EXPRESSION ()
  ;;    we collect here as "(void ; void ; void) ; expr"
  ;; but will interpret as "void ; (void ; (void ; expr))"
  (:tuple (1 (:repeat :VOID-EXPRESSION ";")) ";" (2 :EXPRESSION))
  (make-sequential-expression (list . 1) 2 ':left-lc ':right-lc)  ; fix semantics
  :documentation "Sequence")

(define-sw-parser-rule :VOID-EXPRESSION ()
  (1 :EXPRESSION)
  1)

;;; ------------------------------------------------------------------------
;;;  LIST-DISPLAY
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :LIST-DISPLAY ()
  (:anyof
   ((:tuple "[" "]")                         (make-list-display '() ':left-lc ':right-lc) :documentation "Empty List")
   ((:tuple "[" (1 :LIST-DISPLAY-BODY) "]")  1                                            :documentation "List")
   ))

(define-sw-parser-rule :LIST-DISPLAY-BODY ()
  (1 (:repeat :EXPRESSION ","))
  (make-list-display (list . 1) ':left-lc ':right-lc)
  :documentation "List")

;;; ------------------------------------------------------------------------
;;;  STRUCTOR
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :STRUCTOR ()
  (:anyof
   :PROJECTOR
   :RELAXATOR
   :RESTRICTOR
   :QUOTIENTER
   :CHOOSER
   :EMBEDDER
   :EMEBDDING-TEST))

;;; ------------------------------------------------------------------------

(define-sw-parser-rule :PROJECTOR ()
  (:tuple "project" (1 :FIELD-SELECTOR))
  (make-projector 1 ':left-lc ':right-lc)
  :documentation "Projection")

(define-sw-parser-rule :RELAXATOR ()
  (:tuple "relax"    (1 :CLOSED-EXPRESSION))
  (make-relaxator 1 ':left-lc ':right-lc)
  :documentation "Relaxation")

(define-sw-parser-rule :RESTRICTOR ()
  (:tuple "restrict" (1 :CLOSED-EXPRESSION))
  (make-restrictor 1 ':left-lc ':right-lc)
  :documentation "Restriction")

(define-sw-parser-rule :QUOTIENTER ()
  (:tuple "quotient" (1 :CLOSED-EXPRESSION))
  (make-quotienter 1  ':left-lc ':right-lc)
  :documentation "Quotient")

(define-sw-parser-rule :CHOOSER ()
  (:tuple "choose"   (1 :CLOSED-EXPRESSION))
  (make-chooser 1  ':left-lc ':right-lc)
  :documentation "Choice")

(define-sw-parser-rule :EMBEDDER ()
  ; (:tuple (:optional "embed") (1 :CONSTRUCTOR))
  (:tuple "embed" (1 :CONSTRUCTOR))
  (make-embedder 1 ':left-lc ':right-lc)
  :documentation "Embedding")

(define-sw-parser-rule :EMEBDDING-TEST ()
  (:tuple "embed?"  (1 :CONSTRUCTOR))
  (make-embedding-test 1 ':left-lc ':right-lc)
  :documentation "Embedding Test")

;;; ------------------------------------------------------------------------

(define-sw-parser-rule :PARENTHESIZED-EXPRESSION ()
  (:tuple "(" (1 :EXPRESSION) ")")
  1)

;;; ------------------------------------------------------------------------
;;;   MONAD-EXPRESSION
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :MONAD-EXPRESSION ()
  (:anyof
   :MONAD-TERM-EXPRESSION
   :MONAD-BINDING-EXPRESSION
   ))

(define-sw-parser-rule :MONAD-TERM-EXPRESSION ()
  (:tuple "{" (1 :EXPRESSION) ";" (2 :MONAD-STMT-LIST) "}")
  (make-monad-term-expression 1 2 ':left-lc ':right-lc)
  :documentation "Monadic sequence")

(define-sw-parser-rule :MONAD-BINDING-EXPRESSION ()
  (:tuple "{" (1 :PATTERN) "<-" (2 :EXPRESSION) ";" (3 :MONAD-STMT-LIST) "}")
  (make-monad-binding-expression 1 2 3 ':left-lc ':right-lc)
  :documentation "Monadic binding")

(define-sw-parser-rule :MONAD-STMT-LIST ()
  (:anyof
   ((:tuple (1 :EXPRESSION))                                             1)
   ((:tuple (1 :EXPRESSION) ";" (2 :MONAD-STMT-LIST))                    (make-monad-term-expression    1 2   ':left-lc ':right-lc))
   ((:tuple (1 :PATTERN) "<-" (2 :EXPRESSION) ";" (3 :MONAD-STMT-LIST))  (make-monad-binding-expression 1 2 3 ':left-lc ':right-lc))
   ))

;;; ========================================================================
;;;  MATCH
;;;  http://www.specware.org/manual/html/matchesandpatterns.html
;;; ========================================================================

;;(define-sw-parser-rule :MATCH ()
;;  (:tuple (:optional "|") (1 (:repeat :BRANCH "|")))
;;  (list . 1))

(define-sw-parser-rule :MATCH ()
  (:tuple (:optional "|") (1 :AUX-MATCH))
  1)

(define-sw-parser-rule :AUX-MATCH ()
  (:anyof
   ((:tuple (1 :NON-BRANCH-BRANCH) "|" (2 :AUX-MATCH)) (cons 1 2))
   ((:tuple (1 :BRANCH))                               (cons 1 nil))
   ))

(define-sw-parser-rule :BRANCH ()
  (:tuple (1 :PATTERN) "->" (2 :EXPRESSION))
  (make-branch 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :NON-BRANCH-BRANCH () ; as above, but not ending with "| .. -> .."
  ;; i.e., a branch that doesn't end in a branch
  (:tuple (1 :PATTERN) "->" (2 :NON-BRANCH-EXPRESSION))
  (make-branch 1 2 ':left-lc ':right-lc))

;;; ========================================================================
;;;  PATTERN
;;;  http://www.specware.org/manual/html/matchesandpatterns.html
;;; ========================================================================

(define-sw-parser-rule :PATTERN ()
  (:anyof
   :ANNOTATED-PATTERN
   :TIGHT-PATTERN))

(define-sw-parser-rule :TIGHT-PATTERN ()
  (:anyof
   :ALIASED-PATTERN
   :CONS-PATTERN
   :EMBED-PATTERN
   :QUOTIENT-PATTERN
   :RELAX-PATTERN
   :CLOSED-PATTERN))

(define-sw-parser-rule :CLOSED-PATTERN ()
  (:anyof
   :VARIABLE-PATTERN
   :WILDCARD-PATTERN
   :LITERAL-PATTERN
   :LIST-PATTERN
   :TUPLE-PATTERN
   :RECORD-PATTERN
   :PARENTHESIZED-PATTERN))

;;; ------------------------------------------------------------------------

(define-sw-parser-rule :ANNOTATED-PATTERN ()
  (:tuple (1 :PATTERN) ":" (2 :SORT))                            (make-annotated-pattern  1 2            ':left-lc ':right-lc) :documentation "Annotated Pattern")

(define-sw-parser-rule :ALIASED-PATTERN   ()
  (:tuple (1 :VARIABLE-PATTERN) "as" (2 :TIGHT-PATTERN))         (make-aliased-pattern    1 2            ':left-lc ':right-lc) :documentation "Aliased pattern")

(define-sw-parser-rule :CONS-PATTERN ()
  (:tuple (1 :CLOSED-PATTERN) "::" (2 :TIGHT-PATTERN))           (make-cons-pattern       1 2            ':left-lc ':right-lc) :documentation "CONS pattern")

(define-sw-parser-rule :EMBED-PATTERN ()
  (:tuple (1 :CONSTRUCTOR) (2 :CLOSED-PATTERN))                  (make-embed-pattern      1 2            ':left-lc ':right-lc) :documentation "Embed pattern")

(define-sw-parser-rule :QUOTIENT-PATTERN ()
  (:tuple "quotient" (1 :CLOSED-EXPRESSION) (2 :TIGHT-PATTERN))  (make-quotient-pattern   1 2            ':left-lc ':right-lc) :documentation "Quotient pattern")

(define-sw-parser-rule :RELAX-PATTERN ()
  (:tuple "relax"    (1 :CLOSED-EXPRESSION) (2 :TIGHT-PATTERN))  (make-relax-pattern      1 2            ':left-lc ':right-lc) :documentation "Relax pattern")

(define-sw-parser-rule :VARIABLE-PATTERN ()
  (1 :LOCAL-VARIABLE)                                            (make-variable-pattern   1              ':left-lc ':right-lc) :documentation "Variable pattern")

(define-sw-parser-rule :WILDCARD-PATTERN ()
  (:tuple "_")                                                   (make-wildcard-pattern                  ':left-lc ':right-lc) :documentation "Wildcard pattern")

(define-sw-parser-rule :LITERAL-PATTERN ()
  (:anyof
   ((:tuple "true")                                              (make-boolean-pattern    't             ':left-lc ':right-lc) :documentation "Boolean Pattern")
   ((:tuple "false")                                             (make-boolean-pattern    'nil           ':left-lc ':right-lc) :documentation "Boolean Pattern")
   ((:tuple (1 :NAT))                                            (make-nat-pattern        1              ':left-lc ':right-lc) :documentation "Nat Pattern")
   ((:tuple (1 :CHARACTER))                                      (make-char-pattern       1              ':left-lc ':right-lc) :documentation "Char Pattern")
   ((:tuple (1 :STRING))                                         (make-string-pattern     1              ':left-lc ':right-lc) :documentation "String Pattern")
   ))

(define-sw-parser-rule :LIST-PATTERN ()
  (:anyof
   ((:tuple "[" "]")                                             (make-list-pattern       ()            ':left-lc ':right-lc) :documentation "The empty list")
   ((:tuple "[" (1 (:repeat :PATTERN ",")) "]")                  (make-list-pattern       (list . 1)    ':left-lc ':right-lc) :documentation "List enumeration")
   ))

(define-sw-parser-rule :TUPLE-PATTERN ()
  (:anyof
   ((:tuple "(" ")")                                             (make-tuple-pattern      ()            ':left-lc ':right-lc) :documentation "Empty tuple pattern")
   ((:tuple "(" (1 :PATTERN) "," (2 (:repeat :PATTERN ",")) ")") (make-tuple-pattern      (list 1 . 2)  ':left-lc ':right-lc) :documentation "Tuple pattern")
   ))

(define-sw-parser-rule :RECORD-PATTERN ()
  (:tuple "{" (1 (:repeat :FIELD-PATTERN ",")) "}")              (make-record-pattern     (list . 1)    ':left-lc ':right-lc) :documentation "Record pattern")

(define-sw-parser-rule :FIELD-PATTERN ()
  (:tuple (1 :FIELD-NAME) (:optional (:tuple "=" (2 :PATTERN))))
  (make-field-pattern 1 2 ':left-lc ':right-lc)
  :documentation "Unstructured record element")

(define-sw-parser-rule :PARENTHESIZED-PATTERN ()
  (:tuple "(" (1 :PATTERN) ")")                                  1                                                                  :documentation "Parenthesized pattern")

;;; ========================================================================
;;;  SC-LET
;;;  SC-WHERE
;;;  These refer to names for specs, etc.
;;;  E.g.  let SET = /a/b/c in spec import SET ... end-spec
;;; ========================================================================

(define-sw-parser-rule :SC-LET ()
  (:tuple "let" (1 :SC-DECLS) "in" (2 :SC-TERM))
  (make-sc-let 1 2 ':left-lc ':right-lc))

;; The "where" is experimental. The semantics of "t where decls end" is the
;; same as "let decls in t"

(define-sw-parser-rule :SC-WHERE ()
  (:tuple (2 :SC-TERM) "where" "{" (1 :SC-DECLS) "}")
  (make-sc-where 1 2 ':left-lc ':right-lc))

;;; ========================================================================
;;;  SC-QUALIFY
;;; ========================================================================

(define-sw-parser-rule :SC-QUALIFY ()
  (:tuple (1 :QUALIFIER) "qualifying" (2 :SC-TERM))
  (make-sc-qualify 1 2 ':left-lc ':right-lc))

;;; ========================================================================
;;;  SC-HIDE
;;;  SC-EXPORT
;;; ========================================================================

(define-sw-parser-rule :SC-HIDE ()
  (:tuple "hide" "{" (:optional :QUALIFIABLE-NAME-LIST) "}" "in" (2 :SC-TERM))
  (make-sc-hide 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :SC-EXPORT ()
  (:tuple "export" "{" (:optional :QUALIFIABLE-NAME-LIST) "}" "from" (2 :SC-TERM))
  (make-sc-export 1 2 ':left-lc ':right-lc))

;; Right now we simply list the names to hide or export. Later
;; we might provide some sort of expressions or patterns
;; that match sets of identifiers.
;; (define-sw-parser-rule :SC-NAME-EXPR ()
;;   (:tuple "{" (1 (:optional :QUALIFIABLE-NAME-LIST)) "}")
;; (list . 1))

(define-sw-parser-rule :QUALIFIABLE-NAME-LIST ()
  (1 (:repeat :QUALIFIABLE-NAME ","))
  (list . 1)
)

;;; ========================================================================
;;;  SC-TRANSLATE
;;; ========================================================================

(define-sw-parser-rule :SC-TRANSLATE ()
  (:tuple "translate" (1 :SC-TERM) "by" (2 :SC-TRANSLATE-EXPR))
  (make-sc-translate 1 2 ':left-lc ':right-lc))

;; Right now a translation is just a name mapping. Later we may
;; provide support for matching patterns
(define-sw-parser-rule :SC-TRANSLATE-EXPR ()
  (:tuple "{" (1 (:repeat :SC-TRANSLATE-MAP ",")) "}")
  (make-sc-translate-expr (list . 1) ':left-lc ':right-lc))

(define-sw-parser-rule :SC-TRANSLATE-MAP ()
  (:tuple (1 :QUALIFIABLE-OP-NAME) :MAPS-TO (2 :QUALIFIABLE-OP-NAME))
  (make-sc-translate-map 1 2 ':left-lc ':right-lc))

;;; ------------------------------------------------------------------------
;;;  QUALIFIABLE-NAME (might refer to sort or op)
;;; ------------------------------------------------------------------------

(define-sw-parser-rule :QUALIFIABLE-NAME ()
  ;; might be sort or op name, but will be of the form XXX or QQQ.XXX
  (:anyof :UNQUALIFIED-NAME :QUALIFIED-NAME))

(define-sw-parser-rule :UNQUALIFIED-NAME ()
  (1 :NAME)
  (list 1))

(define-sw-parser-rule :QUALIFIED-NAME ()
  (:tuple (1 :QUALIFIER) "." (2 :NAME))
  (list 1 2))

;;; ========================================================================
;;;  SC-SPEC-MORPH
;;; ========================================================================

(define-sw-parser-rule :SC-SPEC-MORPH ()
  (:tuple "morphism" (1 :SC-TERM) "->" (2 :SC-TERM)
	  "{" (3 (:optional :SC-SPEC-MORPH-ELEM-LIST)) "}")
  (make-sc-spec-morph 1 2 3 ':left-lc ':right-lc))

(define-sw-parser-rule :SC-SPEC-MORPH-ELEM-LIST ()
  (1 (:repeat :SC-SPEC-MORPH-ELEM ","))
  (list . 1))

(define-sw-parser-rule :SC-SPEC-MORPH-ELEM ()
  (:tuple (1 :QUALIFIABLE-OP-NAME) :MAPS-TO (2 :QUALIFIABLE-OP-NAME))
  (make-sc-spec-morph-elem 1 2 ':left-lc ':right-lc))

;;; ========================================================================
;;;  SC-SHAPE
;;; ========================================================================

;;; ========================================================================
;;;  SC-DIAG
;;; ========================================================================

(define-sw-parser-rule :SC-DIAG ()
  (:tuple "diagram" "{" (1 (:repeat :SC-DIAG-ELEM ",")) "}")
  (make-sc-diag (list . 1) ':left-lc ':right-lc))

(define-sw-parser-rule :SC-DIAG-ELEM ()
  (:anyof
   (1 :SC-DIAG-NODE)
   (1 :SC-DIAG-EDGE))
  1)

(define-sw-parser-rule :SC-DIAG-NODE ()
  (:tuple (1 :NAME) :MAPS-TO (2 :SC-TERM))
  (make-sc-diag-node 1 2 ':left-lc ':right-lc))

(define-sw-parser-rule :SC-DIAG-EDGE ()
  (:tuple (1 :NAME) ":" (2 :NAME) "->" (3 :NAME) :MAPS-TO (4 :SC-TERM))
  (make-sc-diag-edge 1 2 3 4 ':left-lc ':right-lc))

;;; ========================================================================
;;;  SC-COLIMIT
;;; ========================================================================

(define-sw-parser-rule :SC-COLIMIT ()
  (:tuple "colimit" (1 :SC-TERM))
  (make-sc-colimit 1 ':left-lc ':right-lc))

;;; ========================================================================
;;;  SC-DIAG-MORPH
;;; ========================================================================

;;; ========================================================================
;;;  SC-DOM
;;;  SC-COD
;;; ========================================================================

;;; ========================================================================
;;;  SC-LIMIT
;;;  SC-APEX
;;; ========================================================================

;;; ========================================================================
;;;  SC-GENERATE
;;; ========================================================================

(define-sw-parser-rule :SC-GENERATE ()
  (:tuple "generate" (1 :NAME) (2 :SC-TERM) (:optional (:tuple "in" (3 :STRING))))
  (make-sc-generate 1 2 3 ':left-lc ':right-lc))

(define-sw-parser-rule :MAPS-TO ()
  (:tuple "+->")
)

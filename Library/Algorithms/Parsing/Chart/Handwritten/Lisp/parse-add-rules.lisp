;;; -*- Mode: LISP; Package: Parser; Base: 10; Syntax: Common-Lisp -*-

(in-package :Parser4)

;;; ============================================================================

(defparameter +token-rule+  (make-parser-token-rule :name :TOKEN))

;;; ============================================================================

(defmacro define-sw-parser-rule (name parents &optional pattern semantics 
				 &key 
				 (precedence +default-precedence+)
				 documentation)
  `(add-parser-main-rule
    *current-parser*
    ',name 
    ',(if (listp parents) parents (list parents))
    ',pattern 
    ',semantics
    ',precedence
    ',documentation))

;;; ============================================================================

(defun add-parser-main-rule (parser rule-name parent-names pattern semantics precedence documentation)
  (debugging-comment "--------------------------------------------------------------------------------")
  (debugging-comment "Adding rule ~S" rule-name)
  (if (null pattern)
      (let ((new-rule (make-parser-atomic-rule :name rule-name)))
	(setf (parser-rule-main-rule? new-rule) t)
	(add-parser-rule-semantics     new-rule semantics)
	(add-parser-rule-precedence    new-rule precedence)
	(add-parser-rule-documentation new-rule documentation)
	(install-parser-rule parser new-rule))
      (let* ((pattern 
	      (if (and (consp pattern) 
		       (or (numberp (first pattern))
			   (eq (first pattern) :optional)))
		  `(:tuple ,pattern)
		  pattern))
	     (optional-pattern?
	      (not (build-parser-rule parser rule-name pattern 
				      (list semantics precedence documentation)))))
	(when optional-pattern?
	  (warn "Ignoring rule ~S, because pattern begins with :optional: ~S"
		rule-name 
		pattern)
	  (return-from add-parser-main-rule nil))))
  (dolist (parent-name parent-names)
    (extend-anyof-rule parser parent-name rule-name))
  rule-name)

;;; ============================================================================

(defun build-parser-rule (parser name pattern &optional s-p-d o-s)
  (let ((new-rule (build-parser-rule-aux parser name pattern s-p-d o-s)))
    (cond ((symbolp new-rule)
	   new-rule)
	  (t
	   (when s-p-d
	     (setf (parser-rule-main-rule? new-rule) t)
	     (add-parser-rule-semantics         new-rule (elt s-p-d 0))
	     (add-parser-rule-precedence        new-rule (elt s-p-d 1))
	     (add-parser-rule-documentation     new-rule (elt s-p-d 2)))
	   (when o-s
	     (setf (parser-rule-optional?         new-rule) (elt o-s 0))
	     (setf (parser-rule-default-semantics new-rule) (elt o-s 1)))
	   (install-parser-rule parser new-rule)
	   (parser-rule-name new-rule)))))

(defun build-parser-rule-aux (parser name pattern s-p-d o-s)
  (debugging-comment "Build rule ~30S  from  ~A with ~S ~S" name (format nil "~S" pattern) s-p-d o-s)
  (etypecase pattern ; cannot use (ecase (type-of pattern) ...) since 'STRING won't match '(SIMPLE-ARRAY CHARACTER (3)) ,etc.
    (string (build-parser-keyword-rule parser pattern)) ; ignore name
    (symbol (build-parser-id-rule name pattern))
    (cons
     (if (atom (first pattern))
	 (ecase (first pattern)
	   (:anyof    (build-parser-anyof-rule  parser name (rest pattern)))
	   (:tuple    (build-parser-tuple-rule  parser name (rest pattern)))
	   (:pieces   (build-parser-pieces-rule parser name (rest pattern)))
	   (:repeat   (build-parser-repeat-rule parser name (rest pattern)))
	   (:repeat*  (let* ((rulename 
			      (build-parser-rule parser name 
						 `(:anyof 
						   ((:tuple (1 (:optional (:repeat ,@(rest pattern))))) 
						    (if (eq '1 :unspecified) '() (list . 1)))
						   )
						 s-p-d
						 (list t '())))
			     (rule (gethash rulename (parser-ht-name-to-rule parser))))
			(debugging-comment "Rule ~S is now optional: ~S." rulename rule)
			rulename))
           (:repeat+  (build-parser-rule parser name 
					 `(:anyof
					   ((:tuple (1 (:repeat ,@(rest pattern))))
					    (list . 1)))
					 s-p-d
					 o-s))
	   (:repeat++ (build-parser-rule parser name 
					 (let ((elt (second pattern))
					       (sep (third  pattern)))
					   (if (null sep)
					       `(:anyof
						 ((:tuple (1 ,elt) (2 (:repeat ,@(rest pattern))))
						  (list 1 . 2)))
					     `(:anyof
					       ((:tuple (1 ,elt) ,sep (2 (:repeat ,@(rest pattern))))
						(list 1 . 2)))))
					 s-p-d
					 o-s))
	   )
	 (let* ((new-rule (build-parser-rule-aux parser name (first pattern) s-p-d o-s))
		(semantics     (second pattern))
		(keyword-args  (rest (rest pattern)))
		(precedence    (getf keyword-args :PRECEDENCE    +default-precedence+))
		(documentation (getf keyword-args :DOCUMENTATION nil)))
	   (add-parser-rule-semantics     new-rule semantics)
	   (add-parser-rule-precedence    new-rule precedence)
	   (add-parser-rule-documentation new-rule documentation)
	   new-rule)))))

;;; ====================

(defun build-parser-keyword-rule (parser keyword)
  (let ((name (aux-name parser "KW--~A" keyword)))
    (or (maybe-find-parser-rule parser name)
	(let ((newrule
	       (make-parser-keyword-rule :name name :keyword keyword)))
	  (install-parser-keyword-rule parser newrule)
	  newrule))))

(defun install-parser-keyword-rule (parser keyword-rule)
  (let ((keyword-string (parser-keyword-rule-keyword keyword-rule)))
    (setf (gethash keyword-string (parser-ht-string-to-keyword-rule parser))
      keyword-rule)))

;;; ====================

(defun build-parser-id-rule (name subrule-name)
  (make-parser-id-rule :name name :subrule subrule-name))

;;; ====================

(defun build-parser-anyof-rule (parser name alternative-patterns)
  (let* ((patterns        alternative-patterns)
	 (number-of-items (length patterns))
	 (items           (make-array number-of-items :initial-element nil)))
    (dotimes (item-number number-of-items)
      (let ((pattern        (pop patterns))
	    (semantic-index nil)
	    (precedence     nil))
	(loop while (consp pattern) do
	  (cond ((eq (first pattern) :optional)
		 (warn "In rule ~S, :optional is redundant: ~S"
		       name 
		       alternative-patterns)
		 (setq pattern (second pattern)))
		((numberp (first pattern))
		 (setq semantic-index (first pattern))
		 (setq precedence 
		       (getf (rest (rest pattern)) :PRECEDENCE +default-precedence+))
		 (setq pattern (second pattern)))
		(t
		 (return nil))))
	(setf (svref items item-number) 
	      (make-parser-rule-item
	       :rule           (build-parser-rule 
				parser 
				(aux-name parser "~A-~D" name item-number)
				pattern)
	       :precedence     precedence
	       :semantic-index semantic-index))))
    (make-parser-anyof-rule :name name :items items)))

;;; ====================

(defun build-parser-tuple-rule (parser name element-patterns)
  (let* ((patterns        element-patterns)
	 (number-of-items (length patterns))
	 (items           (make-array number-of-items :initial-element nil)))
    (dotimes (item-number number-of-items)
      (let ((pattern        (pop patterns))
	    (optional?      nil)
	    (semantic-index nil)
	    (precedence     nil))
	(loop while (consp pattern) do
	  (cond ((eq (first pattern) :optional)
		 (setq optional? t)
		 (setq pattern (second pattern)))
		((numberp (first pattern))
		 (setq semantic-index (first pattern))
		 (setq precedence 
		       (getf (rest (rest pattern)) :PRECEDENCE +default-precedence+))
		 (setq pattern (second pattern)))
		(t
		 (return nil))))
	(setf (svref items item-number)
	      (make-parser-rule-item
	       :rule           (build-parser-rule 
				parser 
				(aux-name parser "~A-~D" name item-number)
				pattern)
	       :optional?      optional?
	       :precedence     precedence
	       :semantic-index semantic-index))))
    (make-parser-tuple-rule :name name :items items)))

;;; ====================

(defun build-parser-pieces-rule (parser name field-patterns)
  (let* ((patterns        field-patterns)
	 (number-of-items (length patterns))
	 (items           (make-array number-of-items :initial-element nil)))
    (dotimes (item-number number-of-items)
      (let ((pattern        (pop patterns))
	    (semantic-index nil)
	    (precedence     nil))
	(loop while (consp pattern) do
	  (cond ((eq (first pattern) :optional)
		 (warn "In rule ~S, :optional is redundant: ~S"
		       name 
		       field-patterns)
		 (setq pattern (second pattern)))
		((numberp (first pattern))
		 (setq semantic-index (first pattern))
		 (setq precedence 
		       (getf (rest (rest pattern)) :PRECEDENCE +default-precedence+))
		 (setq pattern (second pattern)))
		(t
		 (return nil))))
	(setf (svref items item-number)
	      (make-parser-rule-item
	       :rule           (build-parser-rule 
				parser 
				(aux-name parser "~A-~D" name item-number)
				pattern)
	       :precedence     precedence
	       :semantic-index semantic-index))))
    (make-parser-pieces-rule :name name :items items)))

;;; ====================

(defun build-parser-repeat-rule (parser name pattern)
  (let* ((element-pattern   (first  pattern))
	 (separator-pattern (second pattern))
	 (element-item
	  (let ((semantic-index nil)
		(precedence     nil))
	    (loop while (consp element-pattern) do
	      (cond ((eq (first element-pattern) :optional)
		     (warn "In repeat rule ~S, element may not be :optional: ~S"
			   name 
			   pattern)
		     (setq element-pattern (second element-pattern)))
		    ((numberp (first element-pattern))
		     (setq semantic-index (first element-pattern))
		     (setq precedence 
			   (getf (rest (rest pattern)) :PRECEDENCE +default-precedence+))
		     (setq element-pattern (second element-pattern)))
		    (t
		     (return nil))))
	    (make-parser-rule-item
	     :rule           (build-parser-rule 
			      parser 
			      (aux-name parser "~A-ELT" name) 
			      element-pattern)
	     :precedence     precedence
	     :semantic-index semantic-index)))
	 (separator-item
	  (if (or (null separator-pattern) (equal separator-pattern ""))
	      nil
	    (let ((semantic-index nil)
		  (precedence     nil))
	      (loop while (consp separator-pattern) do
		(cond ((eq (first separator-pattern) :optional)
		       (warn "In repeat rule ~S, separator may not be :optional: ~S"
			     name 
			     pattern)
		       (setq separator-pattern (second separator-pattern)))
		      ((numberp (first separator-pattern))
		       (warn "In repeat rule ~S, semantic index for separator??: ~S"
			     name 
			     pattern)
		       (setq semantic-index (first separator-pattern))
		       (setq precedence 
			     (getf (rest (rest pattern)) :PRECEDENCE +default-precedence+))
		       (setq separator-pattern (second separator-pattern)))
		      (t
		       (return nil))))
	      (make-parser-rule-item
	       :rule           (build-parser-rule 
				parser 
				(aux-name parser "~A-SEP" name) 
				separator-pattern)
	       :precedence     precedence
	       :semantic-index semantic-index))))
	 (items (vector element-item separator-item)))
    (make-parser-repeat-rule :name name :items items)))
    

(defun aux-name (parser pattern &rest vars)
  (let ((str (apply #'format nil pattern vars)))
    (intern (if (parser-case-sensitive? parser) str (string-upcase str)) 
	    (parser-rule-package parser))))

;;; ============================================================================

(defun add-parser-rule-semantics (rule semantics)
  (debugging-comment "Set semantics of ~S to ~S" (parser-rule-name rule) semantics)
  (setf (parser-rule-semantics rule) semantics))

;;; ============================================================================

(defun add-parser-rule-precedence (rule precedence)
  (debugging-comment "Set precedence of ~S to ~S" (parser-rule-name rule) precedence)
  (setf (parser-rule-precedence rule) precedence))

;;; ============================================================================

(defun add-parser-rule-documentation (rule doc)
  (debugging-comment "Set documentation of ~S to ~S" (parser-rule-name rule) doc)
  (setf (parser-rule-documentation rule) doc))

;;; ============================================================================

(defun extend-anyof-rule (parser parent-rule-name child-rule-name)
  (let ((parent-rule (find-parser-rule parser parent-rule-name)))
    (debugging-comment "Adding ~S to alternatives for ~S" child-rule-name parent-rule-name)
    (when (not (parser-anyof-rule-p parent-rule))
      (error "Problem adding ~S to ~S" 
	     child-rule-name
	     parent-rule-name))
    (setf (parser-rule-items parent-rule)
	  (concatenate 'array
		       (parser-rule-items parent-rule)
		       (vector (make-parser-rule-item :rule child-rule-name))))))
	  
;;; ============================================================================


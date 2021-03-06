;;; -*- Mode: LISP; Package: Specware; Base: 10; Syntax: Common-Lisp -*-

(in-package :Parser4)

(defparameter *specware4-tokenizer-parameters*
  (create-tokenizer-parameters 
   ;;
   :name                        'meta-slang
   ;;
   :size-of-character-set       128
   ;;
   :word-symbol-start-chars     "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
   :word-symbol-continue-chars  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'?"
   ;;
   :non-word-symbol-start-chars    "`~!@$^&*-=+\\|:<>/'?"
   :non-word-symbol-continue-chars "`~!@$^&*-=+\\|:<>/'?"  ; note: we need to repeat \ here, since lisp removes one
   ;;
   :number-start-chars          "0123456789"
   :number-continue-chars       "0123456789"
   ;;
   :string-quote-char           #\"
   :string-escape-char          #\\
   ;;
   :whitespace-chars            '(#\space #\tab #\newline #\page #\return)
   ;;
   ;; I think these are called special characters in the user documentation
   :separator-chars             '(#\( #\) #\{ #\} #\[ #\]  ; brackets
				  #\. #\, #\;              ; dot, comma, semi
				  ;; #\'                   ; apostrophe
				  )

   :ad-hoc-keywords             '("end-spec" "..") ; to avoid getting multiple tokens
   :ad-hoc-symbols              '()
   ;;
   :ad-hoc-numbers              '()
   ;;
   :comment-to-eol-chars        "%"
   ;;
   :extended-comment-delimiters '(("(*"            "*)"            t   nil) ; t means recursive
				  ("\\section{"    "\\begin{spec}" nil t)   ; t means ok to terminate with eof
				  ("\\subsection{" "\\begin{spec}" nil t)
				  ("\\document{"   "\\begin{spec}" nil t)
				  ("\\end{spec}"   "\\begin{spec}" nil t)
				  )
   ;;
   :pragma-delimiters           '(("proof" "end-proof" nil nil)
                                  ("#translate" "#end" nil nil)) 
					; First nil:  Not recusive, to avoid problems when the word "proof" appears 
					;             inside an extended comment.
					; Second nil: Not ok to terminate with eof -- that's a hack for the latex stuff.
   ;;
   :case-sensitive?             t
   ;;
   ;; Underbar #\_ is implicitly given its own code as a syllable separator
   ))


(defun extract-specware4-tokens-from-file (file)
  (extract-tokens-from-file file *specware4-tokenizer-parameters*))

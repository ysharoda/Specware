#+Lispworks
(setq *default-package-use-list* '("CL"))

(defpackage "SPECWARE")
(in-package "SPECWARE")

(terpri) ; purely cosmetic

#+allegro(setq excl:*global-gc-behavior* '(10 2.0))

;; The following flag disables the collection of xref information when a lisp
;; file is compiled and loaded. When true, it collects such information,
;; but it seems that for monadic code (with lots of closures), compiling
;; such information is very slow (ie. minutes). Other than changing the
;; load time, there is no change to the behaviour of a program.
#+allegro(setq xref::*record-xref-info* nil)

;;; ---------------
;; The following collection have been adapted from the 2000 load.lisp
;; file. Perhaps they should be factored into a separate file as they
;; are likely to be used for many of the generated lisp applications?

(defun current-directory ()
  #+allegro(excl::current-directory)
  #+Lispworks(hcl:get-working-directory)  ;(current-pathname)
  )

(defun change-directory (directory)
  ;; (lisp::format t "Changing to: ~A~%" directory)
  #+allegro(excl::chdir directory)
  #+Lispworks (hcl:change-directory directory)
  (setq lisp::*default-pathname-defaults* (current-directory)))

#+Lispworks
(defun make-system (new-directory)
  (let ((*default-pathname-defaults*
     (make-pathname :name (concatenate 'string new-directory "/")
            :defaults
            system::*current-working-pathname*))
    (old-directory (current-directory)))
    (change-directory new-directory)
    (unwind-protect (load "system.lisp")
      (change-directory old-directory))))

#-Lispworks
(defun make-system (new-directory)
  (let ((old-directory (current-directory)))
    (change-directory new-directory)
    (unwind-protect (load "system.lisp")
      (change-directory old-directory))))

(defun compile-and-load-lisp-file (file)
   (#+allegro excl::compile-file-if-needed
    #+Lispworks hcl:compile-file-if-needed
    (make-pathname :defaults file :type "lisp"))
   (load (make-pathname :defaults file :type nil)))

(defun load-lisp-file (file &rest ignore)
  (load (make-pathname :defaults file :type "lisp")))

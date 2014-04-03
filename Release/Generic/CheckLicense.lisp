(in-package :Specware)

(defparameter *license-file* ".swlicense")
(defparameter *license-text-file* "SpecwareLicense.txt")
(defvar *license-accepted?* nil)

(defparameter *version-sexpr* (list cl-user::*Specware-Major-Version*
                                    cl-user::*Specware-Minor-Version*
                                    cl-user::*Specware-Patch-Level*))

(defun display-license-and-accept (specware-dir)
  (let ((license-text-file (format nil "~a/~a" specware-dir *license-text-file*)))
    (if Emacs::*use-emacs-interface?*
        (Emacs::eval-in-emacs (format nil "(display-license-and-accept ~s)" license-text-file))
        (progn
          (format *query-io* "Opening ~a~%" license-text-file)
          (and (ignore-errors
                 (with-open-file (s (format nil "~a/~a" specware-dir *license-text-file*)
                                    :direction :input)
                   (loop for line = (read-line s  nil :done)
                         until (eq line :done)
                         do (format *query-io* "~a~%" line)))
                 t)
               (yes-or-no-p "Do you agree to this license?"))))))

(defvar *home-file-name*)
(defvar *specware-file-name*)
(defvar *license-file*)

(defun check-license ()
  (unless *license-accepted?*
    (let* ((home-dir (ensure-final-slash (to-cygwin-name (cl-user::home-dir))))
           (home-file-name (format nil "~a~a" home-dir *license-file*))
           (home-file (probe-file home-file-name))
           (specware-dir (Specware::getenv "SPECWARE4"))
           (specware-file-name (format nil "~a/~a" specware-dir *license-file*))
           (license-file (or home-file (probe-file specware-file-name)))
           (license-val (ignore-errors
                          (with-open-file (s license-file :direction :input)
                            (read s)))))
      (setq *home-file-name* home-file-name)
      (setq *specware-file-name* specware-file-name)
      (setq *license-file* license-file)
      (if (and license-val
               (not (eq :|Less|
                        (car (List-Spec::compare-1-1 #'Integer-Spec::compare
                                                     (cons license-val *version-sexpr*))))))
          (setq *license-accepted?* t)
          (if (display-license-and-accept specware-dir)
              (license-accepted)
            (if Emacs::*use-emacs-interface?*
                (setq *license-accepted?* nil) ; Asynchronous
                (progn (format *query-io* "License not accepted. Exiting...")
                       (setq *license-accepted?* nil)
                       (Specware::exit))))))))

(defun license-accepted ()
  (setq *license-accepted?* t)
  ;; write license file
  (unless (and *license-file*
               (ignore-errors
                 (with-open-file (s *license-file* :direction :output :if-exists :supersede)
                   (print *version-sexpr* s))))
    (unless (ignore-errors
              (with-open-file (s *home-file-name*
                                 :direction :output :if-exists :supersede)
                (print *version-sexpr* s)))
      (unless (ignore-errors
                (with-open-file (s *specware-file-name*
                                   :direction :output :if-exists :supersede)
                  (print *version-sexpr* s)))
        (warn "Unable to write license acceptance file!")))))

(defvar *windows-system-p* (memq system-type '(ms-dos windows-nt windows-95
					       ms-windows)))

;; This is called to start Specware. It is invoked by a command-line
;; argument to Xemacs. This spawns a Lisp process.
(defun run-specware4 (&optional in-current-dir?)
  (interactive "P")
  (let* ((root-dir (if in-current-dir?
		       (strip-final-slash (if (stringp in-current-dir?)
					      in-current-dir?
					    default-directory))
		     (concat (getenv "SPECWARE4"))))
	 (bin-dir (concat root-dir
			  "/Applications/Specware/bin/"
			  (if *windows-system-p*
			      "windows"
			    (symbol-name system-type))))
	 (world-name (concat bin-dir "/Specware4." *lisp-image-extension*)))

    (setq sw:common-lisp-host "localhost")
    (setq-default sw::lisp-host sw:common-lisp-host)
    ;;
    ;; sw:common-lisp-directory is the directory in which the lisp subprocess will
    ;; be executed. It is defined in eli/fi-subproc.el with a default value nil
    ;; This seems to work fine under Unix/Linux but under Windows there is 
    ;; a "stringp, nil" error message. So we set it to "c:." to avoid the problem.
    ;;
    (setq sw:common-lisp-directory (concat root-dir "/"))
    ;;
    ;; Specware can be started in two ways. The familiar way is to start the
    ;; Lisp environment augmented with a Specware image. The term "image" comes
    ;; from the Franz manual. At Kestrel, an image is called a "world". The other
    ;; way is to create a new executable application using the ACL primitive
    ;; generate-application. By executable we mean a .exe in the Windows world.
    ;; The latter requires the Enterprise Edition of ACL. It has the advantage that
    ;; we can ship Specware to users who do not already have ACL installed.
    ;;
    ;; Below we set a parameter sw:common-lisp-image-name. Just to confuse things
    ;; further, this is the name used by eli/fi-subproc.el for the Lisp
    ;; executable (and not an image in the ACL sense). The image file
    ;; (in the ACL sense) or world, is bound to common-lisp-image-file
    ;; If the executable is produced by generate-application, then typically,
    ;; there will not be an ACL image file.
    ;;
    (setq sw:common-lisp-image-name (getenv "LISP_EXECUTABLE"))
    ;;
    ;; A "HEAP_IMAGE" is what Franz calls an image and what Kestrel calls a world.
    ;; The suffix on such files is .dxl.
    ;;
    (setq sw:common-lisp-image-file (getenv "LISP_HEAP_IMAGE"))
    (unless (and sw:common-lisp-image-file (not in-current-dir?))
      (setq sw:common-lisp-image-file world-name))
    (setq sw:common-lisp-image-arguments
      (if *windows-system-p* '("+cn") nil))
    (when (getenv "SOCKET_INIT_FILE")
      (set-socket-init-for-specware))

    (let ((log-warning-minimum-level 'error))
      ;; Don't show spurious warning message
      (sw:common-lisp sw:common-lisp-buffer-name
		      sw:common-lisp-directory
		      sw:common-lisp-image-name
		      (if *windows-system-p*
			  (cons "+cn" sw:common-lisp-image-arguments)
			sw:common-lisp-image-arguments)
		      sw:common-lisp-host
		      sw:common-lisp-image-file
		      ))
    (goto-char (point-max))
    ))

(defun set-socket-init-for-specware ()
  (message "set-socket-init-for-specware")
  (setq sw:common-lisp-image-arguments
    (list "-L" (getenv "SOCKET_INIT_FILE"))))

;; The following is almost the same as the above. The difference is that
;; in the following we execute a Specware application (rather than run Lisp
;; with a Specware world);

(defun run-lisp-application ()
  (interactive)
  (setq sw:common-lisp-host "localhost")
  (setq-default sw::lisp-host sw:common-lisp-host)
;;
;; sw:common-lisp-directory is the directory in which the lisp subprocess will
;; be executed. It is defined in eli/fi-subproc.el with a default value nil
;; This seems to work fine under Unix/Linux but under Windows there is 
;; a "stringp, nil" error message. So we set it to "c:." to avoid the problem.
;;
  (setq sw:common-lisp-directory (getenv "LISP_DIRECTORY"))

;; Below we set a parameter sw:common-lisp-image-name. This is the name 
;; used by eli/fi-subproc.el for the Lisp executable. This is the application
;; we want to run.  The image file (in the ACL sense) or world, is bound 
;; to common-lisp-image-file. If the executable is produced by
;; generate-application, then typically, there will not be an ACL image file.

  (setq sw:common-lisp-image-name (getenv "LISP_EXECUTABLE"))
  (setq sw:common-lisp-image-file (getenv "LISP_HEAP_IMAGE"))
  (setq sw:common-lisp-image-arguments
    (if *windows-system-p* '("+cn") nil))

  (let ((log-warning-minimum-level 'error))
    (sw:common-lisp sw:common-lisp-buffer-name
		    sw:common-lisp-directory
		    sw:common-lisp-image-name
		    sw:common-lisp-image-arguments
		    sw:common-lisp-host
		    sw:common-lisp-image-file)))


(defun run-plain-lisp ()
  (interactive)
  (sleep-for 1)
  (when (inferior-lisp-running-p)
    (sw:exit-lisp)
    (sleep-for 2))
  (setq sw:common-lisp-host "localhost")
;;
;; sw:common-lisp-directory is the directory in which the lisp subprocess will
;; be executed. It is defined in eli/fi-subproc.el with a default value nil
;; This seems to work fine under Unix/Linux but under Windows there is 
;; a "stringp, nil" error message. So we set it to "c:." to avoid the problem.
;;
  (setq sw:common-lisp-directory (getenv "LISP_DIRECTORY"))

;; Below we set a parameter sw:common-lisp-image-name. This is the name 
;; used by eli/fi-subproc.el for the Lisp executable. This is the application
;; we want to run.  The image file (in the ACL sense) or world, is bound 
;; to common-lisp-image-file. If the executable is produced by
;; generate-application, then typically, there will not be an ACL image file.

  (setq sw:common-lisp-image-name (getenv "LISP_EXECUTABLE"))
  (setq sw:common-lisp-image-file nil)
  (setq sw:common-lisp-image-arguments
    (if *windows-system-p* '("+cn") nil))

  (let ((log-warning-minimum-level 'error))
    (sw:common-lisp sw:common-lisp-buffer-name
		    sw:common-lisp-directory
		    sw:common-lisp-image-name)))

;; (simulate-input-expression "t")
(defun simulate-input-expression (str)
  (unless (inferior-lisp-running-p)
    (error "Specware not running. Do M-x run-specware4"))
  (let ((win (get-buffer-window *specware-buffer-name*)))
    (if win (select-window win)
      (sw:switch-to-lisp)))
  (goto-char (point-max))
  (insert str)
  (inferior-lisp-newline))

(defvar *specware-continue-form* nil)
(defvar *last-specware-continue-form* nil)

(defun continue-emacs-computation (process event)
  (let ((fm *specware-continue-form*))
    (setq *last-specware-continue-form* fm)
    (setq *specware-continue-form* nil)
    (eval fm)))

(defun continue-form-when-ready (form)
  (setq *specware-continue-form* form)
  (set-process-sentinel (get-buffer-process *specware-buffer-name*)
			'continue-emacs-computation)
  (simulate-input-expression "(cl-user::exit)"))

(defun build-specware4 (in-current-dir?)
  (interactive "P")
  (let* ((root-dir (if in-current-dir?
		       (strip-final-slash (if (stringp in-current-dir?)
					      in-current-dir?
					    default-directory))
		     (getenv "SPECWARE4")))
	 (dir (concat root-dir "/Applications/Specware/Handwritten/Lisp"))
	 (bin-dir (concat root-dir
			     "/Applications/Specware/bin/"
			     (if *windows-system-p*
				 "windows"
			       (symbol-name system-type))))
	 (slash-dir (sw::normalize-filename "/"))
	 (world-name (concat bin-dir "/Specware4." *lisp-image-extension*)))
    (run-plain-lisp)
    (sw:eval-in-lisp-no-value
     (format "(load %S)"
	     (concat root-dir "/Applications/Handwritten/Lisp/load-utilities")))
    (sw:eval-in-lisp-no-value
     (format "(specware::setenv \"SWPATH\" %S)"
	     (concat (sw::normalize-filename root-dir)
		     (if *windows-system-p* ";" ":")
		     slash-dir)))
    (sw:eval-in-lisp-no-value (format "(specware::setenv \"SPECWARE4\" %S)"
				      (sw::normalize-filename root-dir)))
    (sw:eval-in-lisp-no-value
     (format "(namestring (specware::change-directory %S))" dir))
    (simulate-input-expression "(load \"Specware4.lisp\")")
    (continue-form-when-ready
     (`(build-specware4-continue (, root-dir) (, dir) (, bin-dir)
				 (, slash-dir) (, world-name))))))

(defun build-specware4-continue (root-dir dir bin-dir slash-dir world-name)
  (run-plain-lisp)
  (unless (inferior-lisp-running-p)
    (sleep-for 1))
  (sw:eval-in-lisp-no-value
   (format "(load %S)"
	   (concat root-dir "/Applications/Handwritten/Lisp/load-utilities")))
  (sw:eval-in-lisp-no-value (format "(specware::setenv \"SWPATH\" %S)"
			   (concat (sw::normalize-filename root-dir)
				   (if *windows-system-p* ";" ":")
				   slash-dir)))
  (sw:eval-in-lisp-no-value (format "(specware::setenv \"SPECWARE4\" %S)"
			   (sw::normalize-filename root-dir)))
  (sw:eval-in-lisp-no-value
   (format "(namestring (specware::change-directory %S))" dir))
  (sw:eval-in-lisp-no-value "(load \"Specware4.lisp\")")
  (when (file-exists-p world-name)
    (rename-file world-name (concat bin-dir "/Specware4-saved."
				    *lisp-image-extension*)
		 t))
  (sleep-for 1)
  (simulate-input-expression (format (case *specware-lisp*
				       (cmulisp "(ext:save-lisp %S)")
				       (allegro "(excl::dumplisp :name %S)")
				       (openmcl "(ccl:save-application %S)"))
				     world-name))
;;;    (simulate-input-expression
;;;     "(if (probe-file \"bin/specware2000-new.world\")
;;;	  (progn (when (probe-file \"bin/specware2000.world\")
;;;                   (rename-file  \"bin/specware2000.world\" \"bin/specware2000-old.world\"))
;;;		 (rename-file  \"bin/specware2000-new.world\" \"bin/specware2000.world\")
;;;		 \"Wrote a new bin/specware2000.world\")
;;;	\"Failed to build a new world!\")")
  )

(defun build-specware4-from-base (in-current-dir?)
  (interactive "P")
  (let* ((root-dir (if in-current-dir?
		       (strip-final-slash (if (stringp in-current-dir?)
					      in-current-dir?
					    default-directory))
		     (getenv "SPECWARE4")))
	 (dir (concat root-dir "/Applications/Specware/Handwritten/Lisp"))
	 (bin-dir (concat root-dir
			     "/Applications/Specware/bin/"
			     (if *windows-system-p*
				 "windows"
			       (symbol-name system-type))))
	 (lisp-dir (concat root-dir
			     "/Applications/Specware/lisp"))
	 (slash-dir (sw::normalize-filename "/"))
	 (world-name (concat bin-dir "/Specware4." *lisp-image-extension*))
	 (specware4-lisp (concat lisp-dir "/Specware4.lisp"))
	 (specware4-base-lisp (concat root-dir "/Applications/Specware/Specware4-base.lisp")))
    (run-plain-lisp)
    (sw:eval-in-lisp-no-value
     (format "(load %S)"
	     (concat root-dir "/Applications/Handwritten/Lisp/load-utilities")))
    (sw:eval-in-lisp-no-value (format "(specware::setenv \"SWPATH\" %S)"
				      (concat (sw::normalize-filename root-dir)
					      (if *windows-system-p* ";" ":")
					      slash-dir)))
    (sw:eval-in-lisp-no-value (format "(specware::setenv \"SPECWARE4\" %S)"
				      (sw::normalize-filename root-dir)))
        
    (when (file-exists-p specware4-lisp)
      (copy-file specware4-lisp (concat lisp-dir "/Specware4-saved.lisp") t))
    (when (file-exists-p specware4-base-lisp)
      (copy-file specware4-base-lisp specware4-lisp t))
    (sw:eval-in-lisp-no-value (format "(namestring (specware::change-directory %S))" dir))
    (simulate-input-expression "(load \"Specware4.lisp\")")
    (continue-form-when-ready
     (`(build-specware4-from-base-continue (, root-dir) (, dir) (, bin-dir)
					   (, slash-dir) (, world-name))))))

(defun build-specware4-from-base-continue (root-dir dir bin-dir slash-dir world-name)
  (run-plain-lisp)
  (unless (inferior-lisp-running-p)
    (sleep-for 1))
  (sw:eval-in-lisp-no-value
   (format "(load %S)"
	   (concat root-dir "/Applications/Handwritten/Lisp/load-utilities")))
  (sw:eval-in-lisp-no-value (format "(specware::setenv \"SWPATH\" %S)"
				    (concat (sw::normalize-filename root-dir)
					    (if *windows-system-p* ";" ":")
					    slash-dir)))
  (sw:eval-in-lisp-no-value (format "(specware::setenv \"SPECWARE4\" %S)"
				    (sw::normalize-filename root-dir)))
  (sw:eval-in-lisp-no-value (format "(namestring (specware::change-directory %S))"
				    dir))
  (sw:eval-in-lisp-no-value "(load \"Specware4.lisp\")")
  (when (file-exists-p world-name)
    (rename-file world-name (concat bin-dir "/Specware4-saved."
				    *lisp-image-extension*)
		 t))
  (sleep-for 1)
  (simulate-input-expression (format (case *specware-lisp*
				       (cmulisp "(ext:save-lisp %S)")
				       (allegro "(excl::dumplisp :name %S)")
				       (openmcl "(ccl:save-application %S)"))
				     world-name))
;;;    (simulate-input-expression
;;;     "(if (probe-file \"bin/specware2000-new.world\")
;;;	  (progn (when (probe-file \"bin/specware2000.world\")
;;;                   (rename-file  \"bin/specware2000.world\" \"bin/specware2000-old.world\"))
;;;		 (rename-file  \"bin/specware2000-new.world\" \"bin/specware2000.world\")
;;;		 \"Wrote a new bin/specware2000.world\")
;;;	\"Failed to build a new world!\")")
  )

(defun bootstrap-specware4 (in-current-dir?)
  (interactive "P")
  (let ((root-dir (if in-current-dir? (strip-final-slash default-directory)
		    (concat (getenv "SPECWARE4"))))
	(slash-dir "/"))
    (run-specware4 root-dir)
    (sleep-for 2)
    (sw:eval-in-lisp-no-value
     (format "(namestring (specware::change-directory %S))" root-dir))
    (sw:eval-in-lisp-no-value (format "(specware::setenv \"SWPATH\" %S)"
				      (concat (sw::normalize-filename root-dir)
					      (if *windows-system-p* ";" ":")
					      slash-dir)))
    (sw:eval-in-lisp-no-value (format "(specware::setenv \"SPECWARE4\" %S)"
				      (sw::normalize-filename root-dir)))
    (sw:eval-in-lisp-no-value "#+allegro(sys::set-stack-cushion 10000000)
                               #-allegro()")
    (simulate-input-expression "(time (cl-user::boot))")
    (continue-form-when-ready (`(build-specware4 (, root-dir))))))


(defun test-specware-bootstrap (in-current-dir?)
  (interactive "P")
  (let ((current-dir default-directory))
    (if (not (inferior-lisp-running-p))
	(message "Do M-x bootstrap-specware first")
      (progn (shell-command (concatenate 'string "cd "
					 (if in-current-dir? current-dir
					   *specware-home-directory*)
					 "; /bin/rm */sig/*.sig"))
	     (sleep-for 4)		; Necessary? Enough?
	     (simulate-input-expression "(Bootstrap-Spec::compileBootstrap)")
	     (simulate-input-expression ":exit")
	     (sleep-for 5)
	     (while (inferior-lisp-running-p)
	       (sleep-for 2))
	     (run-plain-lisp)
	     (simulate-input-expression "(load \"load.lisp\")")
	     (simulate-input-expression "(Bootstrap-Spec::compileAll)")))))

(defun run-PSL ()
  (interactive)
  (let* ((root-dir (concat (getenv "SPECWARE4") "/"))
	 (bin-dir (concat root-dir
			  "Applications/PSL/bin/"
			  (if *windows-system-p*
			      "windows"
			    (symbol-name system-type))))
	 (world-name (concat bin-dir "/PSL.dxl")))

    (setq sw:common-lisp-host "localhost")
    (setq-default sw::lisp-host sw:common-lisp-host)
    (setq sw:common-lisp-directory root-dir)
    (setq sw:common-lisp-image-name (getenv "LISP_EXECUTABLE"))
    (setq sw:common-lisp-image-file world-name)
    (setq sw:common-lisp-image-arguments
      (if *windows-system-p* '("+cn") nil))

    (let ((log-warning-minimum-level 'error))
      (sw:common-lisp sw:common-lisp-buffer-name
		      sw:common-lisp-directory
		      sw:common-lisp-image-name
		      sw:common-lisp-image-arguments
		      sw:common-lisp-host
		      sw:common-lisp-image-file
		      ))
    ))

(defun strip-final-slash (dirname)
  (let ((len (length dirname)))
    (if (equal ?/ (elt dirname (- len 1)))
	(substring dirname 0 (- len 1))
      dirname)))

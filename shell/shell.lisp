;;
;;  adams  -  Remote system administration tools
;;
;;  Copyright 2013 Thomas de Grivel <billitch@gmail.com>
;;
;;  Permission to use, copy, modify, and distribute this software for any
;;  purpose with or without fee is hereby granted, provided that the above
;;  copyright notice and this permission notice appear in all copies.
;;
;;  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
;;  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;;  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
;;  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;;  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
;;  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
;;  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
;;

(in-package :adams)

(defvar *debug* '(:shell))
(defvar *default-shell-command* "/bin/sh")
(defparameter *shell-signal-errors* nil)

;;  String functions

(defun read-string (stream)
  (with-output-to-string (out)
    (do ((c #1=(when (listen stream)
		 (read-char stream))
	    #1#))
	((null c))
      (write-char c out))))

(defun make-random-bytes (length)
  (let ((seq (make-array length :element-type '(unsigned-byte 8))))
    (with-open-file (r #P"/dev/random" :element-type '(unsigned-byte 8))
      (read-sequence seq r))
    seq))

(defun make-random-string (length)
  (subseq (cl-base64:usb8-array-to-base64-string (make-random-bytes
						  (ceiling length 4/3))
						 :uri t)
	  0 length))

;;  Errors

(define-condition shell-error (error)
  ((command :type string
	    :initarg :command
	    :reader shell-error-command)
   (status :type fixnum
	   :initarg :status
	   :reader shell-error-status)
   (out :initarg :out
	:reader shell-error-out)
   (err :initarg :err
	:reader shell-error-err))
  (:report (lambda (e stream)
	     (with-slots (command status out err) e
	       (format stream "Shell command returned ~D
Command: ~S
Output: ~S
Error: ~S"
		       status command out err)))))

;;  Shell

(defun sh-quote (string)
  (if (cl-ppcre:scan "^[-+/=.,:_0-9A-Za-z]*$" string)
      string
      (str "\"" (cl-ppcre:regex-replace-all "([$`\\\\\"])" string "\\\\\\1") "\"")))

(defun sh-parse-integer (string)
  (when (< 0 (length string))
    (parse-integer string :radix (cond ((char= #\0 (char string 0)) 8)
				       (:otherwise 10)))))

(defun ascii-set-graphics-mode (stream &rest modes)
  (format stream "~C[~{~D~^;~}m" #\Esc modes))

(defun make-delimiter ()
  (format nil "---- ~A~A~A "
	  (ascii-set-graphics-mode nil 0 0 34 34 40 40)
	  (make-random-string 16)
	  (ascii-set-graphics-mode nil 0 0 37 37 40 40)))

(defclass shell ()
  ((command :type (or string list)
	    :initarg :command
	    :reader shell-command)
   (delimiter :type string
	      :reader shell-delimiter
	      :initform (make-delimiter))))

(defgeneric shell-pid (shell))
(defgeneric shell-new-delimiter (shell))
(defgeneric shell-in (data shell))
(defgeneric shell-out/line (shell))
(defgeneric shell-err (shell))
(defgeneric shell-err/line (shell))
(defgeneric shell-status (shell))
(defgeneric shell-close (shell))
(defgeneric shell-closed-p (shell))

(defmethod shell-status ((shell shell))
  (let* ((delim (make-delimiter))
	 (len (length delim))
	 (lines-head (cons nil nil))
	 (lines-tail lines-head))
    (shell-in (format nil " ; echo \"\\n~A $?\"~%" delim) shell)
    (let* ((status (do ((line #1=(shell-out/line shell) #1#)
			(prev nil line))
		       ((or (null line)
			    (and (< len (length line))
				 (string= delim line :end2 len)))
			(when line
			  (when (find 'shell *debug*)
			    (format *debug-io* "$ ")
			    (force-output *debug-io*))
			  (parse-integer line :start len)))
		     (when prev
		       (when (find 'shell *debug*)
			 (format *debug-io* "~A~%" prev)
			 (force-output *debug-io*))
		       (setf (cdr lines-tail) (cons prev nil)
			     lines-tail (cdr lines-tail)))))
	   (out (cdr lines-head))
	   (err (shell-err/line shell)))
      (when (find :shell *debug*)
	(dolist (line out)
	  (format t "~D│ ~A~%" (shell-pid shell) line))
	(dolist (line err)
	  (format t "~D┃ ~A~&" (shell-pid shell) line)))
      (values status out err))))

;;  Run command

(defgeneric shell-run-command (command shell))

(defmethod shell-run-command ((command string) (shell shell))
  (when (find :shell *debug*)
    (format t "~D╭ $ ~A~%" (shell-pid shell) command))
  (shell-in command shell)
  (shell-status shell))

;;  High level interface

(defmacro with-shell ((shell &optional (command *default-shell-command*))
		      &body body)
  (let ((g!shell (gensym "SHELL-")))
    `(let ((,g!shell (make-shell ,command)))
       (unwind-protect (let ((,shell ,g!shell)) ,@body)
	 (shell-close ,g!shell)))))

(defun shell-run (shell command &rest format-args)
  (let ((cmd (apply 'format nil command format-args)))
    (multiple-value-bind (status out err) (shell-run-command cmd shell)
      (when *shell-signal-errors*
	(assert (= 0 status) ()
		'shell-error :command cmd :status status :out out :err err))
      (values out status err))))
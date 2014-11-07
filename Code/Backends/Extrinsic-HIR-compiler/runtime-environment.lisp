(cl:in-package #:sicl-extrinsic-hir-compiler)

(defclass dynamic-environment-entry () ())

(defclass variable-binding (dynamic-environment-entry)
  ((%symbol :initarg :symbol :reader symbol)
   (%value :initarg :value :reader value)))

(defclass unwind-protect (dynamic-environment-entry)
  ((%thunk :initarg :thunk :reader thunk)))

(defclass catch-tag (dynamic-environment-entry)
  ((%value :initarg :value :reader value)
   ;; The function in this slot takes a single argument which must be
   ;; a list of values to return from the CATCH.  When invoked, this
   ;; function executes the host form (RETURN-FROM <block-name> (APPLY
   ;; #'VALUES ARG)).
   (%function :initarg :function :reader function)))

;;; The dynamic environment is a list of instances of the class
;;; DYNAMIC-ENVIRONMENT-ENTRY.
(defparameter *dynamic-environment* '())

;;; SUFFIX is a suffix of the current dynamic environment.  This
;;; function removes entries until from the runtime environment until
;;; the suffix is reached, executing any UNWIND-PROTECT entries it
;;; finds.
(defun unwind (suffix)
  (loop until (eq suffix *dynamic-environment*)
	for entry = (car *dynamic-environment*)
	do (pop *dynamic-environment*)
	   (when (typep entry 'unwind-protect)
	     (funcall (thunk entry)))))

;;; VALUES is a list of values that should be returned by the CATCH.
(defun throw (tag values)
  ;; Find the entry with the corresponding CATCH tag.  Right now we
  ;; signal an error in the host if the entry is not found.  Later, we
  ;; should signal an entry in the target environment instead.
  (let ((suffix (loop for suffix on *dynamic-environment*
		      for entry = (car suffix)
		      when (and (typep entry 'catch-tag)
				(eq (value entry) tag))
			return suffix
		      finally (error "no such tag ~s" tag))))
    (let ((function (function (car suffix))))
      (unwind (cdr suffix))
      (funcall function values))))

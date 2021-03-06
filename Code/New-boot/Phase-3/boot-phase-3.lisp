(cl:in-package #:sicl-new-boot-phase-3)

(defclass header (closer-mop:funcallable-standard-object)
  ((%class :initarg :class)
   (%rack :initarg :rack))
  (:metaclass closer-mop:funcallable-standard-class))

(defun activate-class-finalization (boot)
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)) boot
    (setf (sicl-genv:special-variable
           'sicl-clos::*standard-direct-slot-definition* e2 t)
          (sicl-genv:find-class 'sicl-clos:standard-direct-slot-definition e1))
    (setf (sicl-genv:special-variable
           'sicl-clos::*standard-effective-slot-definition* e2 t)
          (sicl-genv:find-class 'sicl-clos:standard-effective-slot-definition e1))
    (sicl-genv:fmakunbound 'sicl-clos:direct-slot-definition-class e2)
    (import-functions-from-host
     '(find reverse last remove-duplicates reduce
       mapcar union find-if-not eql count)
     e2)
    (load-file "CLOS/slot-definition-class-support.lisp" e2)
    (load-file "CLOS/slot-definition-class-defgenerics.lisp" e2)
    (load-file "CLOS/slot-definition-class-defmethods.lisp" e2)
    (load-file "CLOS/class-finalization-defgenerics.lisp" e2)
    (load-file "CLOS/class-finalization-support.lisp" e2)
    (load-file "CLOS/class-finalization-defmethods.lisp" e2)))

(defun finalize-all-classes (boot)
  (format *trace-output* "Finalizing all classes.~%")
  (let* ((e2 (sicl-new-boot:e2 boot))
         (finalization-function
           (sicl-genv:fdefinition 'sicl-clos:finalize-inheritance e2)))
    (do-all-symbols (var)
      (let ((class (sicl-genv:find-class var e2)))
        (unless (null class)
          (funcall finalization-function class)))))
  (format *trace-output* "Done finalizing all classes.~%"))

(defun activate-allocate-instance (boot)
  (with-accessors ((e2 sicl-new-boot:e2)) boot
    (setf (sicl-genv:fdefinition 'sicl-clos::allocate-general-instance e2)
          (lambda (class size)
            (make-instance 'header
              :class class
              :rack (make-array size :initial-element 10000000))))
    (setf (sicl-genv:fdefinition 'sicl-clos::general-instance-access e2)
          (lambda (object location)
            (aref (slot-value object '%rack) location)))
    (setf (sicl-genv:fdefinition '(setf sicl-clos::general-instance-access) e2)
          (lambda (value object location)
            (setf (aref (slot-value object '%rack) location) value)))
    (import-functions-from-host
     '((setf sicl-genv:constant-variable) sort assoc list* every
       mapc 1+ 1- subseq butlast position identity nthcdr equal
       remove-if-not)
     e2)
    (load-file "CLOS/class-unique-number-offset-defconstant.lisp" e2)
    (load-file "CLOS/allocate-instance-defgenerics.lisp" e2)
    (load-file "CLOS/allocate-instance-support.lisp" e2)
    (load-file "CLOS/allocate-instance-defmethods.lisp" e2)))

(defun satiate-function (function e2)
  (funcall (sicl-genv:fdefinition
            'sicl-clos::compute-and-set-specializer-profile e2)
           function (sicl-genv:find-class 't e2))
  (funcall (sicl-genv:fdefinition 'sicl-clos::satiate-generic-function e2)
           function))

(defun satiate-all-functions (e1 e2 e3)
  (format *trace-output* "Satiating all functions.~%")
  (do-all-symbols (var)
    (when (and (sicl-genv:fboundp var e3)
               (eq (class-of (sicl-genv:fdefinition var e3))
                   (sicl-genv:find-class 'standard-generic-function e1)))
      (satiate-function (sicl-genv:fdefinition var e3) e2))
    (when (and (sicl-genv:fboundp `(setf ,var) e3)
               (eq (class-of (sicl-genv:fdefinition `(setf ,var) e3))
                   (sicl-genv:find-class 'standard-generic-function e1)))
      (satiate-function (sicl-genv:fdefinition `(setf ,var) e3) e2)))
  (format *trace-output* "Done satiating all functions.~%"))

(defun my-class-of (object)
  (if (typep object 'header)
      (slot-value object '%class)
      (class-of object)))

(defun activate-generic-function-invocation (boot)
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)) boot
    (import-package-from-host '#:sicl-conditions e2)
    (setf (sicl-genv:fdefinition 'sicl-clos::general-instance-p e2)
          (lambda (object)
            (typep object 'header)))
    (setf (sicl-genv:fdefinition 'typep e2)
          (lambda (object type-specifier)
            (sicl-genv:typep object type-specifier e2)))
    (load-file "CLOS/classp-defgeneric.lisp" e2)
    (load-file "CLOS/classp-defmethods.lisp" e2)
    (setf (sicl-genv:fdefinition 'class-of e2)
          #'my-class-of)
    (setf (sicl-genv:fdefinition 'find-class e2)
          (lambda (name)
            (sicl-genv:find-class name e1)))
    (setf (sicl-genv:fdefinition 'sicl-clos:set-funcallable-instance-function e2)
          #'closer-mop:set-funcallable-instance-function)
    (load-file-protected "CLOS/list-utilities.lisp" e2)
    (load-file "CLOS/compute-applicable-methods-support.lisp" e2)
    (load-file "New-boot/Phase-3/sub-specializer-p.lisp" e2)
    (load-file "CLOS/compute-applicable-methods-defgenerics.lisp" e2)
    (load-file "CLOS/compute-applicable-methods-defmethods.lisp" e2)
    (import-package-from-host '#:sicl-method-combination e2)
    (import-function-from-host
     'sicl-method-combination::define-method-combination-expander e2)
    (load-file "Method-combination/define-method-combination-defmacro.lisp" e2)
    (import-functions-from-host
     '(sicl-genv:find-method-combination-template
       (setf sicl-genv:find-method-combination-template)
       sicl-loop::list-cdr sicl-loop::list-car)
     e2)
    (setf (sicl-genv:find-class
           'sicl-method-combination:method-combination-template e1)
          (find-class 'sicl-method-combination:method-combination-template))
    (load-file "CLOS/standard-method-combination.lisp" e2)
    (import-functions-from-host
     '(sicl-method-combination:find-method-combination
       sicl-method-combination:effective-method-form-function)
     e2)
    (load-file "CLOS/find-method-combination-defgenerics.lisp" e2)
    (load-file "CLOS/find-method-combination-defmethods.lisp" e2)
    (load-file "CLOS/compute-effective-method-defgenerics.lisp" e2)
    (load-file "CLOS/compute-effective-method-support.lisp" e2)
    (setf (sicl-genv:fdefinition 'make-method e2)
          (lambda (function)
            (funcall (sicl-genv:fdefinition 'make-instance e2)
                     (sicl-genv:find-class 'standard-method e1)
                     :function function
                     :lambda-list '(x &rest args)
                     :specializers (list (sicl-genv:find-class t e2)))))
    (load-file "CLOS/compute-effective-method-support-c.lisp" e2)
    (load-file "CLOS/compute-effective-method-defmethods-b.lisp" e2)
    (load-file "CLOS/no-applicable-method-defgenerics.lisp" e2)
    (load-file "CLOS/no-applicable-method.lisp" e2)
    (import-functions-from-host
     '(zerop nth intersection make-list caddr) e2)
    (load-file "CLOS/compute-discriminating-function-defgenerics.lisp" e2)
    (load-file "CLOS/compute-discriminating-function-support.lisp" e2)
    (import-functions-from-host
     '(sicl-clos::add-path
       sicl-clos::compute-discriminating-tagbody
       sicl-clos::extract-transition-information
       sicl-clos::make-automaton)
     e2)
    (load-file "CLOS/compute-discriminating-function-support-c.lisp" e2)
    (load-file "CLOS/compute-discriminating-function-defmethods.lisp" e2)
    (load-file-protected "CLOS/satiation.lisp" e2)
    (import-functions-from-host '(format print-object) e2)
    (load-file "New-boot/Phase-3/define-methods-on-print-object.lisp" e2)
    (load-file "New-boot/Phase-3/compute-and-set-specialier-profile.lisp" e2)
    (load-file "CLOS/standard-instance-access.lisp" e2)))

;;; The specializers of the generic functions in E3 are the classes of
;;; the instances in E3, so they are the classes in E2.
(defun define-make-specializer (e2 e3)
  (setf (sicl-genv:fdefinition 'sicl-clos::make-specializer e3)
        (lambda (specializer environment)
          (declare (ignore environment))
          (cond ((symbolp specializer)
                 (sicl-genv:find-class specializer e2))
                (t
                 specializer)))))

;;; In order to make DEFMETHOD work in E3, we need to be able to add
;;; methods to a generic function.  We use the SICL-specific function
;;; ENSURE-METHOD for that, and ENSURE-METHOD calls the Common Lisp
;;; standard function ADD-METHOD.  But the full ADD-METHOD is a bit to
;;; complicated for what we need here.  For one thing, it checks for
;;; existing methods to remove first, and it does some error checking.
;;; We do not need that here, because we are never going to add a
;;; method that requires removing any existing method.  For that
;;; reason, we define a special version of it here.
;;;
;;; Now, we are dealing with generic function metaobjects in E3.  They
;;; are instances of classes in E1, so the accessor methods for thos
;;; generic function metaobjects are to be found in E2.  Therefore,
;;; instead of just using PUSH, we have to find and call the
;;; slot-reader and the slot-writer explicitly which makes this code
;;; look a bit strange.
(defun define-add-method-in-e3 (boot)
  (with-accessors ((e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)) boot
    (let* ((name 'sicl-clos:generic-function-methods)
           (slot-reader (sicl-genv:fdefinition name e2))
           (slot-writer (sicl-genv:fdefinition `(setf ,name) e2)))
      (setf (sicl-genv:fdefinition 'add-method e3)
            (lambda (generic-function method)
              (funcall slot-writer
                       (cons method (funcall slot-reader generic-function))
                       generic-function))))))

(defun define-make-method-for-generic-function-in-e3 (boot)
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e3 sicl-new-boot:e3)) boot
    (setf (sicl-genv:fdefinition 'sicl-clos::make-method-for-generic-function e3)
          (lambda (generic-function specializers keys)
            (declare (ignore generic-function))
            (apply #'make-instance
                   (sicl-genv:find-class 'standard-method e1)
                   :specializers specializers
                   keys)))))

(defun define-defmethod-expander (boot)
  (with-accessors ((e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)) boot
    (setf (sicl-genv:fdefinition 'sicl-clos:defmethod-expander e3)
          (lambda (ct-env function-name rest)
            (multiple-value-bind
                  (qualifiers required remaining
                   specializers declarations documentation forms)
                (sicl-clos::parse-defmethod rest)
              (let* ((lambda-list (append required remaining))
                     (generic-function-var (gensym)))
                `(let* ((,generic-function-var
                          (ensure-generic-function ',function-name :environment ,ct-env)))
                   (sicl-clos:ensure-method
                    ,generic-function-var
                    ,ct-env
                    :lambda-list ',lambda-list
                    :qualifiers ',qualifiers
                    :specializers ,(sicl-clos::canonicalize-specializers specializers)
                    :documentation ,documentation
                    :function
                    ,(funcall
                      (sicl-genv:fdefinition 'sicl-clos:make-method-lambda e3)
                      nil
                      nil
                      `(lambda ,lambda-list
                         ,@declarations
                         ,@forms)
                      nil)))))))))

(defun activate-object-initialization (boot)
  (with-accessors ((e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)) boot
    ;; The function CLASS-OF is called by SHARED-INITIALIZE in order
    ;; to get the slot-definition metaobjects.
    (setf (sicl-genv:fdefinition 'class-of e3)
          (lambda (object) (slot-value object '%class)))
    ;; The support code for SHARED-INITIALIZE in phase 3 will need to
    ;; access various slots of class metaobjects and slot-definition
    ;; metaobjects.  Since we are initializing objects in E3, the
    ;; class metaobjects for these objects are located in E2.
    ;; Therefor, it is handy to load the support code for
    ;; SHARED-INITIALIZE into E2.  Notice, however, that we do not
    ;; want to define SHARED-INITIALIZE itself in E2 because we
    ;; already have a definition for it there (imported from the
    ;; host), and we do want to call SHARED-INITIALIZE from functions
    ;; in E3.
    ;;
    ;; GET-PROPERTIES is called by SHARED-INITIALIZE to get the
    ;; INITARGs of the slot-definition metaobject.
    (import-functions-from-host '(get-properties) e2)
    (setf (sicl-genv:special-variable 'sicl-clos:+unbound-slot-value+ e2 t)
          10000000)
    (load-file "CLOS/slot-bound-using-index.lisp" e2)
    (load-file "CLOS/slot-value-etc-defgenerics.lisp" e2)
    (load-file "CLOS/slot-value-etc-support.lisp" e2)
    (load-file "CLOS/slot-value-etc-defmethods.lisp" e2)
    (load-file "CLOS/instance-slots-offset-defconstant.lisp" e2)
    (load-file "CLOS/shared-initialize-support.lisp" e2)
    ;; The version of SHARED-INITIALIZE-DEFAULT that was defined when
    ;; we loaded the previous file has two problems.  One, it is
    ;; defined in E2, but we need for it to be defined in E3 so that
    ;; it is called from the default method on SHARED-INITIALIZE.  The
    ;; other is that it uses the version of CLASS-OF in E2, but we
    ;; need for it to use the definition of CLASS-OF in E3.
    ;; Therefore, we define a special version of it here.
    (setf (sicl-genv:fdefinition 'sicl-clos::shared-initialize-default e3)
          (lambda (instance slot-names &rest initargs)
            (let* ((class-of (sicl-genv:fdefinition 'class-of e3))
                   (class (funcall class-of instance))
                   (class-slots (sicl-genv:fdefinition 'sicl-clos:class-slots e2))
                   (slots (funcall class-slots class)))
              (apply (sicl-genv:fdefinition
                      'sicl-clos::shared-initialize-default-using-class-and-slots
                      e2)
                     instance slot-names class slots initargs))))
    (load-file "CLOS/shared-initialize-defgenerics.lisp" e3)
    (load-file "CLOS/shared-initialize-defmethods.lisp" e3)
    (load-file "CLOS/initialize-instance-support.lisp" e3)
    (load-file "CLOS/initialize-instance-defgenerics.lisp" e3)
    (load-file "CLOS/initialize-instance-defmethods.lisp" e3)
    (import-function-from-host 'error e2)
    (load-file "CLOS/make-instance-support.lisp" e2)
    (setf (sicl-genv:fdefinition 'make-instance e3)
          (lambda (class &rest initargs)
            (let ((class-metaobject
                    (if (symbolp class)
                        (sicl-genv:find-class class e2)
                        class)))
              (apply (sicl-genv:fdefinition 'sicl-clos::make-instance-default e2)
                     class-metaobject
                     (sicl-genv:fdefinition 'initialize-instance e3)
                     initargs))))))

(defun activate-defmethod-in-e3 (boot)
  (with-accessors ((e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)) boot
    (let ((method-function (sicl-genv:fdefinition 'sicl-clos:method-function e2)))
      (setf (sicl-genv:fdefinition 'sicl-clos::make-method-lambda-default e3)
            (lambda (generic-function method lambda-expression environment)
              (declare (ignore generic-function method environment))
              (let ((args (gensym))
                    (next-methods (gensym)))
                (values
                 `(lambda (,args ,next-methods)
                    (flet ((next-method-p ()
                             (not (null ,next-methods)))
                           (call-next-method (&rest args)
                             (when (null ,next-methods)
                               (error "no next method"))
                             (funcall (funcall ,method-function (car ,next-methods))
                                      (or args ,args)
                                      (cdr ,next-methods))))
                      (declare (ignorable #'next-method-p #'call-next-method))
                      (apply ,lambda-expression
                             ,args)))
                 '())))))
    (load-file "CLOS/make-method-lambda-defuns.lisp" e3)
    (define-make-specializer e2 e3)
    (import-function-from-host 'adjoin e2)
    (load-file "CLOS/add-remove-direct-method-support.lisp" e2)
    (load-file "CLOS/add-remove-direct-method-defgenerics.lisp" e2)
    (load-file "CLOS/add-remove-direct-method-defmethods.lisp" e2)
    (define-add-method-in-e3 boot)
    (define-make-method-for-generic-function-in-e3 boot)
    (import-functions-from-host
     '(cleavir-code-utilities:proper-list-p copy-list)
     e3)
    (load-file "CLOS/ensure-method.lisp" e3)
    (define-defmethod-expander boot)
    (load-file "CLOS/defmethod-defmacro.lisp" e3)))

(defun boot-phase-3 (boot)
  (format *trace-output* "Start of phase 3~%")
  (with-accessors ((e1 sicl-new-boot:e1)
                   (e2 sicl-new-boot:e2)
                   (e3 sicl-new-boot:e3)
                   (e4 sicl-new-boot:e4)) boot
    (change-class e3 'environment)
    (activate-class-finalization boot)
    (finalize-all-classes boot)
    (activate-allocate-instance boot)
    (activate-generic-function-invocation boot)
    (activate-defmethod-in-e3 boot)
    (activate-object-initialization boot)
    (satiate-all-functions e1 e2 e3)
    (load-accessor-defgenerics boot)
    (satiate-all-functions e1 e2 e3)
    (create-mop-classes boot)))

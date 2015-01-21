(cl:in-package #:sicl-extrinsic-hir-compiler)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Main entry point.

(defun eval (form)
  (let* ((cleavir-generate-ast:*compiler* 'cl:eval)
	 (ast (cleavir-generate-ast:generate-ast form *environment*))
	 (hir (cleavir-ast-to-hir:compile-toplevel ast))
	 (lambda-expr (translate hir *environment*))
	 (fun (compile nil lambda-expr)))
    (funcall fun)))

(defmethod cleavir-env:eval (form environment1 (environment2 environment))
  (let* ((cleavir-generate-ast:*compiler* 'cl:eval)
	 (ast (cleavir-generate-ast:generate-ast form environment1))
	 (hir (cleavir-ast-to-hir:compile-toplevel ast))
	 (lambda-expr (translate hir environment2))
	 (fun (compile nil lambda-expr)))
    (funcall fun)))

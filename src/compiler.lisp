(in-package :cl-user)
(defpackage renki.compiler
  (:use :cl
        :renki.ast
        :renki.vm)
  (:export :compile-to-bytecode))
(in-package :renki.compiler)

(defparameter *line-inited* nil)

(defgeneric compile-to-bytecode (obj))

(defmethod compile-to-bytecode :around (obj)
  (if *line-inited*
      (call-next-method)
      (let ((*line-inited* t)
            (*current-line* 0))
        (append (call-next-method)
                (list (make-match-inst))))))

(defmethod compile-to-bytecode ((obj <symbol>))
  (list (make-char-inst (reg-char obj))))

(defmethod compile-to-bytecode ((obj <sequence>))
  (append (compile-to-bytecode (reg-lh obj))
          (compile-to-bytecode (reg-rh obj))))

(defmethod compile-to-bytecode ((obj <alternative>))
  (let ((split (make-split-inst))
        (lh (compile-to-bytecode (reg-lh obj)))
        (jmp (make-jmp-inst))
        (rh (compile-to-bytecode (reg-rh obj)))
        (end (make-empty-inst)))
    (setf (inst-to jmp) (inst-line end))
    (setf (inst-to1 split) (inst-line (car lh)))
    (setf (inst-to2 split) (inst-line (car rh)))
    (append (list split)
            lh
            (list jmp)
            rh
            (list end))))

(defmethod compile-to-bytecode ((obj <kleene>))
  (let* ((split (make-split-inst))
         (operand (compile-to-bytecode (reg-operand obj)))
         (jmp (make-jmp-inst (inst-line split)))
         (end (make-empty-inst)))
    (setf (inst-to1 split) (inst-line (car operand)))
    (setf (inst-to2 split) (inst-line end))
    (append (list split)
            operand
            (list jmp end))))

(defmethod compile-to-bytecode ((obj <group>))
  (compile-to-bytecode (reg-operand obj)))

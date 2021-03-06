(in-package :cl-user)
(defpackage renki-test.vm
  (:use :cl
        :renki.vm
        :prove)
  (:shadowing-import-from :renki.vm
                          :fail))
(in-package :renki-test.vm)

(plan nil)

(subtest "definst"
  (definst test ()
    ((test :reader inst-test)))

  (ok (find-class 'test)
      "can defclass.")

  (ok (member 'inst-test *inst-readers*)
      "can add reader in *inst-readers*."))

(subtest "<empty>"
  (is-type (make-empty-inst)
           '<empty>
           "can make-empty-inst."))

(subtest "<match>"
  (is-type (make-match-inst)
           '<match>
           "can make-match-inst."))

(subtest "<char>"
  (let ((char (make-char-inst #\a)))
    (is-type char
             '<char>
             "can make-char-inst.")

    (is (inst-char char)
        #\a
        "can set char.")))

(subtest "<jmp>"
  (let ((jmp (make-jmp-inst 1)))
    (is-type jmp
             '<jmp>
             "can make-jmp-inst.")

    (is (inst-to jmp)
        1
        "can set to.")

    (setf (inst-to jmp) 2)

    (is (inst-to jmp)
        2
        "can setf to.")))

(subtest "<split>"
  (let ((split (make-split-inst)))
    (is-type split
             '<split>
             "can make-split-inst.")

    (setf (inst-to1 split) 1)
    (setf (inst-to2 split) 2)

    (is (inst-to1 split)
        1
        "can setf to1.")

    (is (inst-to2 split)
        2
        "can setf to2.")))

(subtest "<cond>"
  (let ((table (make-hash-table)))
    (setf (gethash #\a table) 1)
    (is-type (make-cond-inst table)
             '<cond>
             "can make-cond-inst.")

    (let ((cond (make-cond-inst table)))
      (is-type (inst-table cond)
               'hash-table
               "can setf table."))))

(subtest "*current-line*"
  (let ((first (make-empty-inst))
        (second (make-empty-inst)))
    (is (- (inst-line second) (inst-line first))
        1
        "can increment *current-line*.")))

(subtest "curret-char"
  (with-target-string "a"
    (let ((*sp* 0))
      (is (current-char)
          #\a
          "can return the character *sp* indicates."))))

(subtest "curret-inst"
  (let ((*insts* (make-array 1 :initial-contents (list (make-empty-inst))))
        (*pc* 0))
    (is-type (current-inst)
             '<empty>
             "can returt the inst *pc* indicates.")))


(subtest "next-line"
  (let ((*pc* 0))
    (next-line *pc*)

    (is *pc*
        1
        "can incf *pc*.")))

(subtest "goto-line"
  (let ((*pc* 0))
    (goto-line 2)

    (is *pc*
        2
        "can setq *pc*.")))

(subtest "push-thread"
  (let ((*queue* nil)
        (*sp* 0))
    (push-thread 1)

    (is (length *queue*)
        1
        "can push to *queue*.")

    (is (car *queue*)
        (make-thread :pc 1 :sp 0)
        "can push thread to *queue*."
        :test #'equalp)))

(subtest "table-goto"
  (let ((table (make-hash-table)))
    (setf (gethash #\a table) 1)
    (setf (gethash #\b table) 3)

    (with-target-string "abc"
      (table-goto table)
      
      (is *sp*
          1
          "can incf *sp*.")

      (is *pc*
          1
          "can setq *pc*.")

      (table-goto table)

      (is *pc*
          3
          "can dispatch with character.")

      (is (table-goto table)
          :fail
          "can return fail with character not on table."))))

(subtest "match"
  (is (match)
      :match
      "can be expanded to :match."))

(subtest "fail"
  (is (fail)
      :fail
      "can be expanded to :fail."))

(subtest "expand-inst"
  (let* ((form '((inst-char char))))
    (is (expand-inst form)
        (list (sb-impl::unquote '(inst-char char)))
        "can unquote."
        :test #'equalp)))

(subtest "defexec"
  (defexec ((obj test))
    (declare (ignore obj))
    (match))

  (ok (find-method #'exec nil (list 'test))
      "can defmethod.")

  (ok (gethash (find-class 'test) *exec-table*)
      "can register to *exec-table*.")

  (let ((fn (gethash (find-class 'test) *exec-table*)))
    (is-type fn
             'function
             "can register function to *exec-table*.")

    (is (funcall fn (make-instance 'test))
        (list '(match))
        "can funcall registered function.")))

(subtest "with-target-string"
  (with-target-string "ab"
    (is *target*
        "ab"
        "can let *target*.")

    (is *target-length*
        2
        "can let *target-length*.")

    (is *sp*
        0
        "can let *sp*.")))

(subtest "compile-insts"
  (let* ((*current-line* 0)
         (insts (list (make-char-inst #\a) (make-match-inst)))
         (fn (compile-insts insts)))
    (is-type fn
             'function
             "can return function.")

    (is (list (funcall fn "a") (funcall fn "b"))
        (list t nil)
        "can compile insts.")))

(subtest "exec"
  (subtest "<empty>"
    (let ((*pc* 0))
      (exec (make-empty-inst))

      (is *pc*
          1
          "can increment *pc*.")))

  (subtest "<match>"
    (is (exec (make-match-inst))
        :match
        "can returt :match."))

  (subtest "<char>"
    (with-target-string "ab"
      (let ((*pc* 0)
            (*sp* 0)
            (*queue* nil))
        (ok (exec (make-char-inst #\a))
            "can returt T when matching succeeded.")

        (is *sp*
            1
            "can increment *sp*.")

        (is *pc*
            1
            "can increment *pc*.")

        (is (exec (make-char-inst #\a))
            :fail
            "can return :fail when matching failed."))))

  (subtest "<jmp>"
    (let ((*pc* 0))
      (exec (make-jmp-inst 2))

      (is *pc*
          2
          "can set *pc* to inst-to of <jmp>.")))

  (subtest "<split>"
    (let ((*queue* nil)
          (*pc* 0)
          (*sp* 0)
          (split (make-split-inst)))
      (setf (inst-to1 split) 2)
      (setf (inst-to2 split) 3)
      (exec split)

      (is (length *queue*)
          2
          "can push 2 threads.")

      (is (car *queue*)
          (make-thread :pc 2 :sp 0)
          "can save to1 and *sp*."
          :test #'equalp)

      (is (cadr *queue*)
          (make-thread :pc 3 :sp 0)
          "can save to2 and *sp*."
          :test #'equalp)))

  (subtest "<cond>"
    (let ((table (make-hash-table)))
      (setf (gethash #\a table) 1)
      (setf (gethash #\b table) 3)
      (let ((cond (make-cond-inst table)))
        (with-target-string "abc"
          (exec cond)

          (is *sp*
              1
              "can incf *sp*.")

          (is *pc*
              1
              "can setq *pc*.")

          (exec cond)

          (is *pc*
              3
              "can dispatch with character.")

          (is (exec cond)
              :fail
              "can return fail with character not on table."))))))

(subtest "run-vm"
  (subtest ":match"
    (ok (run-vm (list (make-match-inst)) "")
        "can return T."))

  (subtest ":fail"
    (is (run-vm (list (make-char-inst #\b) (make-char-inst #\a)) "a")
        nil
        "can return NIL when *queue* is empty.")

    (let ((split (make-split-inst)))
      (setf (inst-to1 split) 1)
      (setf (inst-to2 split) 2)
      (is (run-vm (list split (make-char-inst #\b) (make-char-inst #\a) (make-match-inst)) "a")
          t
          "can continue when *queue* is not empty.")))

  (subtest ":splitted"
    (let ((*pc* 0)
          (*sp* 0)
          (*queue* 0)
          (split (make-split-inst)))
      (setf (inst-to1 split) 1)
      (setf (inst-to2 split) 2)
      (ok (run-vm (list split (make-char-inst #\a) (make-jmp-inst 4) (make-char-inst #\b) (make-match-inst)) "a")
          "can exec the first thread.")))

  (subtest "t"
    (ok (run-vm (list (make-char-inst #\a) (make-match-inst)) "a")
        "can continue.")))

(finalize)

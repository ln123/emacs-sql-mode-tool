
(defun SQL-Def-Open-definition ()
  (interactive)
  (let* ((outbuf  (get-buffer-create (elt (tabulated-list-get-entry) 1)))
	 (current-sqli-buffer sql-buffer) 
	(output-settings (sql-redirect-value current-sqli-buffer
					     "\\pset " "^\\([^[:blank:]]+\\)[[:blank:]]+\\(.+\\)$"
					     (list 1 2)))
	)
    (with-current-buffer outbuf
      (sql-mode)
      (sql-set-product 'postgres)
      (setq sql-buffer current-sqli-buffer)
      (run-hooks 'sql-set-sqli-hook)
      ;(sql-set-sqli-buffer)
      )
    (sql-redirect current-sqli-buffer "\\pset format unaligned \\pset tuples_only on ")
    (sql-redirect-one current-sqli-buffer
		      (concat "select pg_get_functiondef("
			      (tabulated-list-get-id)
			      " )||';';")
		      outbuf nil)
    (sql-redirect current-sqli-buffer (concat "\\pset format " (cadr (assoc-string "format"  output-settings))
					      "\\pset tuples_only " (cadr (assoc-string "tuples_only"  output-settings))))
    (pop-to-buffer outbuf)
    ))

(defun sql-def-get-object-name-at-point ()
  (and (buffer-local-value 'sql-contains-names (current-buffer))
               (thing-at-point-looking-at
                (concat "\\_<\\sw\\(:?\\sw\\|\\s_\\)*"
                        "\\(?:[.]+\\sw\\(?:\\sw\\|\\s_\\)*\\)*\\_>"))
               (downcase (buffer-substring-no-properties (match-beginning 0)
                                               (match-end 0)))))


(defvar SQL-Def-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "RET") 'SQL-Def-Open-definition)
    map)
  "Local keymap for `SQL-Def-mode' buffers.")

(define-derived-mode SQL-Def-mode tabulated-list-mode "SQL Definition menu"
  "Major mode for SQL Definition menu select"
  (make-local-variable 'sql-buffer)
  )



(defun sql-def-create-def-list (name)
  (let* ((current-sqli-buffer sql-buffer)
	 (output-settings (sql-redirect-value current-sqli-buffer
					      "\\pset " "^\\([^[:blank:]]+\\)[[:blank:]]+\\(.+\\)$"
					      (list 1 2)))
	 (res nil)
	 (split-name (split-string  name "[.]"))
	 (func-name (or (cadr split-name) (car split-name)))
	 (schema (and (cadr split-name) (car split-name)))
	 )
    (sql-redirect current-sqli-buffer "\\pset format unaligned \\pset tuples_only on ")
       
    (setq res (mapcar #'(lambda (c) (list (car c) (vector "Function" (cadr c))))
		      (sql-redirect-value
		       current-sqli-buffer
		       (concat "select proname||'('|| pg_get_function_arguments(oid)||') return '||pg_get_function_result(oid) func_name, oid from pg_proc where proname = '"
			       func-name
			       "' "
			       (if schema
				   (concat " and pronamespace = (select oid from pg_namespace where nspname = '"
					   schema
					   "')"))
			       ";")
		       "^\\(.+\\)|\\(.+\\)$" (list 2 1))))
    (sql-redirect current-sqli-buffer (concat "\\pset format " (cadr (assoc-string "format"  output-settings))
					      "\\pset tuples_only " (cadr (assoc-string "tuples_only"  output-settings))))
    res
    ))

(defun sql-def-buffer-create-for-name-at-point ()
 (interactive)   
 (let ((sql-def-buf (get-buffer-create "*SQL Def*"))
       (current-sqli-buffer (sql-find-sqli-buffer))
      (name (sql-def-get-object-name-at-point)))
  (with-current-buffer sql-def-buf
    (SQL-Def-mode)
    (setq sql-buffer current-sqli-buffer)
   (setq tabulated-list-format
	  (vector '("Object Type" 30 t)
		  `("Object Name" 30 t)))
   (setq tabulated-list-use-header-line t)
   (setq tabulated-list-entries (sql-def-create-def-list name))
   (tabulated-list-init-header)
   (tabulated-list-print))
  (display-buffer sql-def-buf)
  ))



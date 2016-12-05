
;;; Commentary:
;;

;;; Code:

(require 'company)
(require 'cl-lib)
(require 'sql)

(defvar company-sql-comp '("") "completions cache")

(defun company-sql-clear-cache ()
  (interactive)
(setq company-sql-comp '("")))

(defun company-sql-get-from-db (sql-string)
;(message "%s" sql-string) 
  (let* ((current-sqli-buffer ;(sql-find-sqli-buffer)
	  (get-buffer "*SQL*")
	  )
	 (output-settings (sql-redirect-value current-sqli-buffer
					      "\\pset " "^\\([^[:blank:]]+\\)[[:blank:]]+\\(.+\\)$"
					      (list 1 2)))
	 (res nil))
    (sql-redirect current-sqli-buffer "\\pset format unaligned \\pset tuples_only on ")
    
    (setq res (sql-redirect-value current-sqli-buffer sql-string "^\\(.+\\)$" 1))
    (sql-redirect current-sqli-buffer (concat "\\pset format " (cadr (assoc-string "format"  output-settings))
					      "\\pset tuples_only " (cadr (assoc-string "tuples_only"  output-settings))))
    res
    ))


(defun company-sql-prefix()
  "for example `tablename.col' `table.' `str'"
  (with-syntax-table (copy-syntax-table (syntax-table))
    (modify-syntax-entry ?.  "w");treat . as part of word
    (company-grab-symbol)
  ))


(defun company-sql-completions (prefix)
(message "%s" prefix)
  (cl-remove-if (lambda (x) (string-match-p  (concat prefix ".*[.]") x))
		(let ((completions (or (all-completions prefix company-sql-comp) (all-completions (concat "public." prefix) company-sql-comp)))
	(split-name (split-string  prefix "[.]")))
    (if (eq completions nil)
	(progn (nconc company-sql-comp (company-sql-get-from-db (concat "select nspname from pg_namespace n "
								 "where nspname like '" (cl-first split-name) (if (cl-second split-name) ".'" "%'")
								 " union "
								 "select nspname||'.'||relname from pg_namespace n, pg_class c "
								 "where n.oid = c.relnamespace and relkind not in ('i','t') "
								 (if (cl-second split-name)
								     (concat "and nspname like '" (cl-first split-name) "'"
									     " and relname like '" (cl-second split-name) (if (cl-third split-name) ".'" "%'"))
								     (concat "and nspname like 'public'"
									     " and relname like '" (cl-first split-name) (if (cl-second split-name) ".'" "%'")))
								 " union "
								 "select nspname||'.'||proname from pg_namespace n, pg_proc c "
								 "where n.oid = c.pronamespace "
								 (if (cl-second split-name)
								     (concat "and nspname like '" (cl-first split-name) "'"
									     " and proname like '" (cl-second split-name)  "%'")
								     (concat "and nspname like 'public'"
									     " and proname like '" (cl-first split-name)  "%'"))
								 " union "
								 "select nspname||'.'||relname||'.'||attname from pg_namespace n, pg_class c, pg_attribute a "
								 "where n.oid = c.relnamespace and relkind not in ('i','t') and a.attrelid = c.oid "
								 (if (cl-third split-name)
								     (concat "and nspname like '" (cl-first split-name) "'"
									     " and relname like '" (cl-second split-name) "'"
									     " and attname like '" (cl-third split-name) "%'")
								     (concat "and nspname like 'public'"
									     " and relname like '" (cl-first split-name) "'"
									     " and attname like '" (or (cl-second split-name) ".....") "%'")
								     )
								 ";")))
	       (or (all-completions prefix company-sql-comp) (all-completions (concat "public." prefix) company-sql-comp)))
      completions))))


;;;###autoload
(defun company-sql (command &optional arg &rest ignored)
  "`company-mode' completion backend for sql-postgres-mode."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-sql))
    (prefix (and (or (derived-mode-p 'sql-mode) (derived-mode-p 'sql-interactive-mode))
                 (not (company-in-string-or-comment))
                 (or (company-sql-prefix) 'stop)))
    (candidates (company-sql-completions arg))))


(provide 'company-sql)
;;; company-sql.el ends here

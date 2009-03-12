(require 'company)
(require 'nxml-mode)
(require 'rng-nxml)
(eval-when-compile (require 'cl))

(defconst company-nxml-token-regexp
  "\\(?:[_[:alpha:]][-._[:alnum:]]*\\_>\\)")

(defvar company-nxml-in-attribute-value-regexp
  (replace-regexp-in-string "w" company-nxml-token-regexp
   "<w\\(?::w\\)?\
\\(?:[ \t\r\n]+w\\(?::w\\)?[ \t\r\n]*=\
[ \t\r\n]*\\(?:\"[^\"]*\"\\|'[^']*'\\)\\)*\
[ \t\r\n]+\\(w\\(:w\\)?\\)[ \t\r\n]*=[ \t\r\n]*\
\\(\"\\([^\"]*\\>\\)\\|'\\([^']*\\>\\)\\)\\="
   t t))

(defvar company-nxml-in-tag-name-regexp
  (replace-regexp-in-string "w" company-nxml-token-regexp
                            "<\\(/?w\\(?::w?\\)?\\)?\\=" t t))

(defun company-nxml-all-completions (prefix alist)
  (let ((candidates (mapcar 'cdr alist))
        (case-fold-search nil)
        filtered)
    (when (cdar rng-open-elements)
      (push (concat "/" (cdar rng-open-elements)) candidates))
    (setq candidates (sort (all-completions prefix candidates) 'string<))
    (while candidates
      (unless (equal (car candidates) (car filtered))
        (push (car candidates) filtered))
      (pop candidates))
    (nreverse filtered)))

(defmacro company-nxml-prepared (&rest body)
  (declare (indent 0) (debug t))
  `(let ((lt-pos (save-excursion (search-backward "<" nil t)))
         xmltok-dtd)
     (when (and lt-pos (= (rng-set-state-after lt-pos) lt-pos))
       ,@body)))

(defun company-nxml-tag (command &optional arg &rest ignored)
  (case command
    ('prefix (and (eq major-mode 'nxml-mode)
                  rng-validate-mode
                  (company-grab company-nxml-in-tag-name-regexp 1)))
    ('candidates (company-nxml-prepared
                   (company-nxml-all-completions arg
                    (rng-match-possible-start-tag-names))))
    ('sorted t)))

(defun company-nxml-attribute (command &optional arg &rest ignored)
  (case command
    ('prefix (and (eq major-mode 'nxml-mode)
                  rng-validate-mode
                  (memq (char-after) '(?\  ?\t ?\n)) ;; outside word
                  (company-grab rng-in-attribute-regex 1)))
    ('candidates (company-nxml-prepared
                   (and (rng-adjust-state-for-attribute
                         lt-pos (- (point) (length arg)))
                        (company-nxml-all-completions arg
                         (rng-match-possible-attribute-names)))))
    ('sorted t)))

(defun company-nxml-attribute-value (command &optional arg &rest ignored)
  (case command
    ('prefix (and (eq major-mode 'nxml-mode)
                  rng-validate-mode
                  (and (memq (char-after) '(?' ?\" ?\  ?\t ?\n)) ;; outside word
                       (looking-back company-nxml-in-attribute-value-regexp)
                       (or (match-string-no-properties 4)
                           (match-string-no-properties 5)
                           ""))))
    ('candidates (company-nxml-prepared
                   (let (attr-start attr-end colon)
                     (and (looking-back rng-in-attribute-value-regex lt-pos)
                          (setq colon (match-beginning 2)
                                attr-start (match-beginning 1)
                                attr-end (match-end 1))
                          (rng-adjust-state-for-attribute lt-pos attr-start)
                          (rng-adjust-state-for-attribute-value
                           attr-start colon attr-end)
                          (all-completions arg
                           (rng-match-possible-value-strings))))))))

(defun company-nxml (command &optional arg &rest ignored)
  (case command
    ('prefix (or (company-nxml-tag 'prefix)
                 (company-nxml-attribute 'prefix)
                 (company-nxml-attribute-value 'prefix)))
    ('candidates (cond
                  ((company-nxml-tag 'prefix)
                   (company-nxml-tag 'candidates arg))
                  ((company-nxml-attribute 'prefix)
                   (company-nxml-attribute 'candidates arg))
                  ((company-nxml-attribute-value 'prefix)
                   (sort (company-nxml-attribute-value 'candidates arg)
                         'string<))))
    ('sorted t)))

(provide 'company-nxml)
;;; company-nxml.el ends here

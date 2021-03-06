
(setq org-clock-persist 'history)
(org-clock-persistence-insinuate)

;; (setq org-tag-alist
;;       '(
;;         ("home" . ?h)
;;         ("finance" . ?f)
;;         ("eastn" . ?e)
;;         ("avarts" . ?a)
;;         ("erasmus" . ?E)
;;         ("researchfunding" . ?r)))

(defcustom iz-log-dir
  (expand-file-name
   "~/Documents/000WORKFILES/")
  "This directory contains all notes on current projects and classes")

(defcustom org-diary-file
  "PERSONAL/DIARY.org"
  "Path to main org diary file, relative to log dir.")

(defcustom org-todo-file
  "PERSONAL/TODO/TODO.org"
  "Path to main TODO file, relative to log dir.")

(setq diary-file (concat iz-log-dir "PERSONAL/agenda"))

;; Default capture templates

(setq org-capture-templates
      '(("t" "Todo" entry (file+datetree+prompt (concat iz-log-dir org-diary-file))
         ;;; TODOS should have no DATE property active timestamp, so as to show in
         ;; future dates of agenda TODO view. !
         "* TODO %?\nEntered on %(concat \"[\"
                  (substring
                   (format-time-string (cdr org-time-stamp-formats) (current-time))
                   1 -1)
                  \"]\")\n  %i\n%a"
         ;; Note: We need to use custom sexpr (substring ...) in order to create
         ;; an inactive timestamp with the current time.  If we use %U instead, then
         ;; the time of the %U will be the same as that input for %T previously,
         ;; when the user inputs a custom time value.
         )        
        ("j" "Journal" entry (file+datetree+prompt (concat iz-log-dir org-diary-file))
         "* %?\n :PROPERTIES:\n :DATE: %T\n :END:\nEntered on %(concat \"[\"
                  (substring
                   (format-time-string (cdr org-time-stamp-formats) (current-time))
                   1 -1)
                  \"]\")\n  %i\n%a")))

(setq org-agenda-files `(,(concat iz-log-dir org-diary-file)))

(global-set-key (kbd "H-c H-c") 'org-capture)

(setq org-agenda-repeating-timestamp-show-all nil)

;; (setq org-agenda-files (list "~/org/work.org"
;;                              "~/org/school.org" 
;;                              "~/org/home.org"))


;; (defadvice org-agenda (before update-agenda-file-list ())
;;   "Re-createlist of agenda files from contents of relevant directories."
;;   (iz-update-agenda-file-list)
;;   (icicle-mode 1))

;; (defadvice org-agenda (after turn-icicles-off ())
;;   "Turn off icicle mode since it interferes with some other keyboard shortcuts."
;;   (icicle-mode -1))

;; (ad-activate 'org-agenda)

;; (defadvice org-refile (before turn-icicles-on-for-refile ())
;;   "Turn on icicles before running org-refile.
;; Note: This piece of advice needs checking! Maybe not valid."
;;   (icicle-mode 1))

;; (defadvice org-refile (after turn-icicles-off-for-refile ())
;;   "Turn off icicle mode since it interferes with some other keyboard shortcuts."
;;   (icicle-mode -1))

;; (ad-activate 'org-refile)

(defun iz-diary-entry ()
  "Go to or create diary entry for date entered interactively."
  (interactive)
  (find-file (concat iz-log-dir org-diary-file))
  (org-datetree-find-date-create
   (calendar-gregorian-from-absolute
    (org-time-string-to-absolute (org-read-date))))
  (org-show-entry))

(defun iz-update-agenda-file-list ()
  "Set value of org-agenda-files from contents of relevant directories."
  (setq org-agenda-files
        (let ((folders (file-expand-wildcards (concat iz-log-dir "*")))
              (files (file-expand-wildcards (concat iz-log-dir "*.org"))))
          (dolist (folder folders)
            (setq files
                  (append
                   files ;; ignore files whose name starts with dash (-)
                   (file-expand-wildcards (concat folder "/[!-]*.org")))))
          (-reject
           (lambda (f)
             (string-match-p "/\\." f))
           files)))
  (message "the value of org-agenda-files was updated"))

(defvar iz-last-selected-file
  nil
  "Path of file last selected with iz-org-file menu.
Used to refile to date-tree of last selected file.")

(defun iz-goto-last-selected-file ()
  (interactive)
  (if iz-last-selected-file
      (find-file iz-last-selected-file)
    (iz-find-file)))

(defun iz-refile-to-date-tree (&optional use-last-selected)
  "Refile using DATE timestamp to move to file-datetree.
If USE-LAST-SELECTED is not nil, refile to last selected refile target."
  (interactive "P")
  (let ((origin-buffer (current-buffer))
        (origin-filename (buffer-file-name (current-buffer)))
        (date (calendar-gregorian-from-absolute
               (org-time-string-to-absolute
                (or (org-entry-get (point) "CLOSED")
                 (org-entry-get (point) "DATE"))))))
    (org-cut-subtree)
    (if (and iz-last-selected-file use-last-selected)
        (find-file iz-last-selected-file)
      (iz-find-file))
    (org-datetree-find-date-create date)
    (move-end-of-line nil)
    (open-line 1)
    (forward-line)
    (org-paste-subtree 4)
    (save-buffer)
    (find-file origin-filename)))

(defun org-process-entry-from-mobile-org ()
  "Get time from mobile-entry and put it in DATE property."
  (interactive)
  (org-back-to-heading 1)
  (forward-line 1)
  (let ((time (cadr (org-element-timestamp-parser))))
    (org-entry-put nil "DATE" (plist-get time :raw-value)))
  (outline-next-heading))

(defun iz-get-and-refile-mobile-entries ()
  "Refile mobile entries to log buffer.
Use timestamp from mobile to refile under date-tree.

After finishing the refile operation, save a copy of the
processed file with a timestamp, and erase the contents of
from-mobile.org, to wait for next pull operation."
  (interactive)
 (org-mobile-pull)
 (let* ((mobile-file (file-truename "~/org/from-mobile.org"))
        (mobile-buffer (find-file mobile-file))
        (log-buffer (find-file (concat iz-log-dir "0_PRIVATE/DIARY.org"))))
   (with-current-buffer
       mobile-buffer
     (org-map-entries
      (lambda ()
        (let* ((timestamp
                (cdr (assoc "TIMESTAMP_IA" (org-entry-properties))))
               (date
                (calendar-gregorian-from-absolute
                 (org-time-string-to-absolute timestamp))))
          (org-copy-subtree)
          (with-current-buffer
              log-buffer
            (org-datetree-find-date-create date)
            (move-end-of-line nil)
            (open-line 1)
            (forward-line)
            (org-paste-subtree 4)
            (org-set-property "DATE" (concat "<" timestamp ">"))
            (org-set-tags-to ":mobileorg:"))))))
   (copy-file
    mobile-file
    (concat
     (file-name-sans-extension mobile-file)
     (format-time-string "%Y-%m-%d-%H-%M-%S")
     ".org"))
   (with-current-buffer
       mobile-buffer
     (erase-buffer)
     (save-buffer))))

(defun iz-refile-notes-to-log ()
  "Refile notes entered from terminal with quick-entry to log file.
Get date from DATE property of entry and use it to refile the entry
in the log file under date-tree."
  (interactive)
 (let* ((notes-file (concat iz-log-dir "0_INBOX/notes.org"))
        (notes-buffer (find-file notes-file))
        (log-buffer (find-file (concat iz-log-dir "0_PRIVATE/DIARY.org"))))
   (with-current-buffer
       notes-buffer
     (org-map-entries
      (lambda ()
        (let* ((timestamp (org-entry-get (point) "DATE"))
               (date
               (calendar-gregorian-from-absolute
                (org-time-string-to-absolute timestamp))))
          (org-copy-subtree)
          (with-current-buffer
              log-buffer
            (org-datetree-find-date-create date)
            (move-end-of-line nil)
            (open-line 1)
            (forward-line)
            (org-paste-subtree 4)
            (org-set-property "DATE" (concat "<" timestamp ">")))))))
   (copy-file
    notes-file
    (concat
     (file-name-sans-extension notes-file)
     (format-time-string "%Y-%m-%d-%H-%M-%S")
     ".org"))
   (with-current-buffer
       notes-buffer
     (erase-buffer)
     (save-buffer))))

(defun iz-insert-file-as-snippet ()
  (interactive)
  (insert-file-contents (iz-select-file-from-folders)))

(defun iz-select-file-from-folders ()
  (iz-org-file-menu (iz-select-folder)))

(defun iz-org-file-menu (subdir)
  (let*
      ((files
        (file-expand-wildcards (concat iz-log-dir subdir "/[!.]*.org")))
       (projects (mapcar 'file-name-sans-extension
                         (mapcar 'file-name-nondirectory files)))
       (dirs
        (mapcar (lambda (dir)
                  (cons (file-name-sans-extension
                                (file-name-nondirectory dir)) dir))
                files))
       (project-menu (grizzl-make-index projects))
       (selection (cdr (assoc (grizzl-completing-read "Select file: " project-menu)
                              dirs))))
    (setq iz-last-selected-file selection)
    selection))

(defun iz-get-refile-targets ()
  (interactive)
  (setq org-refile-targets '((iz-select-file-from-folders . (:maxlevel . 2)))))

(defun iz-find-file-flat (&optional dired)
  "Open a file by selecting from all org-files in subfolders of iz-log-dir."
  (interactive "P")
  (cond ((equal dired '(4))
         (dired (concat iz-log-dir (iz-select-folder))))
        ((equal dired '(16))
         (progn
           (dired iz-log-dir)
           (sr-speedbar-open)))
        (t
         (let* ((items (iz-make-log-capture-templates-flat))
                (menu-items (mapcar 'car items))
                (menu (grizzl-make-index menu-items))
                (selection (grizzl-completing-read "Select a file:" menu)))
           (when selection
             (find-file
              (car (last (nth 4 (assoc selection items)))))
             (save-excursion (goto-char 0)
                             (if (search-forward "*# -*- mode:org" 100 t)
                                 (org-decrypt-entries))))))))

(defun iz-find-file (&optional dired)
  "Open a file by selecting from subfolders of iz-log-dir."
  (interactive "P")
  (cond ((equal dired '(4))
         (dired (concat iz-log-dir (iz-select-folder))))
        ((equal dired '(16))
         (progn
           (dired iz-log-dir)
           (sr-speedbar-open)))
        (t
         (find-file (iz-select-file-from-folders))
         (goto-char 0)
         (if (search-forward "*# -*- mode:org" 100 t)
             (org-decrypt-entries)))))

;; Following needed to avoid error message ls does not use dired.
(setq ls-lisp-use-insert-directory-program nil)
(require 'ls-lisp)

(defun iz-open-project-folder (&optional open-in-finder)
  "Open a folder associated with a project .org file.
Select the file using iz-select-file-from-folders, and then open folder instead.
If the folder does not exist, create it."
  (interactive "P")
  (let ((path (file-name-sans-extension (iz-select-file-from-folders))))
    (unless  (file-exists-p path) (make-directory path))
    (if open-in-finder (open-folder-in-finder path) (dired path))))

(defvar iz-capture-keycodes "abcdefghijklmnoprstuvwxyzABDEFGHIJKLMNOPQRSTUVWXYZ1234567890.,(){}!@#$%^&*-_=+")

;; From: http://stackoverflow.com/questions/2321904/elisp-how-to-save-data-in-a-file

(defun dump-vars-to-file (varlist filename)
  "simplistic dumping of variables in VARLIST to a file FILENAME"
  (save-excursion
    (let ((buf (find-file-noselect filename)))
      (set-buffer buf)
      (erase-buffer)
      (dump varlist buf)
      (save-buffer)
      (kill-buffer))))

(defun dump (varlist buffer)
  "insert into buffer the setq statement to recreate the variables in VARLIST"
  (loop for var in varlist do
        (print (list 'setq var (list 'quote (symbol-value var)))
               buffer)))

(defvar iz-capture-template-history nil "something")

(defvar iz-capture-template-history-file
  (concat iz-log-dir "capture-template-history.el")
  "Store list of 10 last capture templates used.")

(defun iz-log (&optional goto)
  "Capture log entry in date-tree of selected file.
Select from menu comprized of 2 parts:
1. File selected from subfolders of log dir.
2. 20 latest files where a capture was performed.
"
  (interactive "P")
  (unless iz-capture-template-history
    (if (file-exists-p iz-capture-template-history-file)
        (load-file iz-capture-template-history-file)))
  (let*
      ((menu (grizzl-make-index
              (append
               (mapcar 'file-name-nondirectory
                       (-select 'file-directory-p
                                (file-expand-wildcards
                                 (concat iz-log-dir "[!.]*"))))
               (reverse (mapcar 'car iz-capture-template-history)))))
       (selection (grizzl-completing-read "Select log target:" menu)))
    (cond ((equal ":" (substring selection 0 1))
           (let ((org-capture-entry
                  (cdr (assoc selection iz-capture-template-history))))
             (org-capture goto)))
          (t
           (message "Selection: %s" selection)
           (message "Capture templates made from selection: %s"
                    (iz-make-log-capture-templates selection))
           (iz-make-log-capture-templates selection)
           (org-capture goto)))))

(defun iz-log-flat (&optional goto)
  "Capture log entry in date-tree of selected file.
Select from menu comprized of all org files under the subdirectories
of iz-log-dir."
  (interactive "P")
  (let*
      ((entries (iz-make-log-capture-templates-flat))
       (menu (grizzl-make-index (mapcar 'car entries)))
       (selection (grizzl-completing-read "Select log target:" menu)))
    (let ((org-capture-entry
           (cdr (assoc selection entries))))
      (if (eq major-mode 'org-agenda-mode)
          (org-agenda-capture)
       (org-capture goto)))))

(defun iz-helm-ack ()
  (interactive)
  (dired iz-log-dir)
  (let ((helm-grep-use-ack-p t))
    (helm-do-grep)))

(global-set-key (kbd "H-h a") 'iz-helm-ack)

(defun org-capture-store-template-selection (&optional capt-template)
  "Keep list of 20 latest log files used."
  ;; (message "the arg is: %s" capt-template)
  (unless iz-capture-template-history
    (if (file-exists-p iz-capture-template-history-file)
        (load-file iz-capture-template-history-file)))
  (let* ((temp-path (car (last (nth 3 capt-template))))
         (key (concat ":"
                      (file-name-nondirectory
                       (directory-file-name
                        (file-name-directory temp-path)))
                      "/"
                     (file-name-sans-extension (file-name-nondirectory temp-path))
                     ;; (car capt-template) "-" (cadr capt-template)
                     )))
    (setq iz-capture-template-history
          (-take 20
          (cons (cons key capt-template)
                (-reject (lambda (x) (equal key (car x)))
                         iz-capture-template-history)))))
  (dump-vars-to-file
   '(iz-capture-template-history)
   iz-capture-template-history-file)
  capt-template)

;; (advice-add
;;  'org-capture-select-template
;;  :filter-return
;;  'org-capture-store-template-selection)

;; old version:
(defun iz-log-old (&optional goto)
  "Capture log entry in date-tree of selected file."
  (interactive "P")
  (iz-make-log-capture-templates (iz-select-folder))
  (org-capture goto))

;; (defun iz-select-folder ()
;;   (let*
;;       ((folders (-select 'file-directory-p
;;                          (file-expand-wildcards
;;                           (concat iz-log-dir "*"))))
;;        (folder-menu (grizzl-make-index
;;                      (mapcar 'file-name-nondirectory folders)))
;;        (folder (grizzl-completing-read "Select folder:" folder-menu)))
;;     folder))

(defun iz-select-folder ()
  (let*
      ((folders (-select 'file-directory-p
                         (file-expand-wildcards
                          (concat iz-log-dir "*"))))
       (folder-menu (grizzl-make-index
                     (mapcar 'file-name-nondirectory folders)))
       (folder (grizzl-completing-read "Select folder:" folder-menu)))
    (file-name-nondirectory folder)))

(defun iz-make-log-capture-templates (subdir)
  "Make capture templates for selected subdirectory under datetree."
  (setq org-capture-templates
        (let* ((files
                (file-expand-wildcards
                 (concat iz-log-dir subdir "/[!-]*.org")))
               (dirs
                (mapcar (lambda (dir) (cons (file-name-sans-extension
                                             (file-name-nondirectory dir))
                                            dir))
                        files)))
          (-map-indexed (lambda (index item)
                          (list
                           (substring iz-capture-keycodes index (+ 1 index))
                           (car item)
                           'entry
                           (list 'file+datetree+prompt (cdr item))
                           "* %?\n :PROPERTIES:\n :DATE:\t%^T\n :END:\n\n%i\n"))
                        dirs))))

(defun iz-make-log-capture-templates-flat ()
  "Make capture templates for all subdirectories of iz-log-dir."
  (let (templates
        (subdirs
         (-select
          'file-directory-p (file-expand-wildcards (concat iz-log-dir "*")))))
    (dolist (subdir subdirs templates)
      (setq
       templates
       (append
        templates
        (let* (
               (files
                (file-expand-wildcards
                 (concat subdir "/[!-]*.org")))
               (dirs
                (mapcar
                 (lambda (dir)
                   (cons
                    (concat
                     (file-name-nondirectory
                      (directory-file-name
                       (file-name-directory dir)))
                     ":"
                     (file-name-sans-extension
                      (file-name-nondirectory dir)))
                    dir))
                 files)))
          (mapcar
           (lambda (item)
             (list
              (car item) ;; grizzl-menu item and assoc list key
              "a" ;; this is not used. Choice is by grizzl-menu
              (car item) ;; this is also not used
              'entry
              (list 'file+datetree+prompt (cdr item))
              "* %?\n :PROPERTIES:\n :DATE:\t%^T\n :END:\n\n%i\n"))
           dirs)))))))


(defun iz-todo (&optional goto)
  "Capture TODO entry in date-tree of selected file."
  (interactive "P")
  (iz-make-todo-capture-templates (iz-select-folder))
  (org-capture goto))

(defun iz-make-todo-capture-templates (subdir)
  "Make capture templates for project files"
 (setq org-capture-templates
       (setq org-capture-templates
             (let* (
                    (files
                     (file-expand-wildcards
                      (concat iz-log-dir subdir "/[a-zA-Z0-9]*.org")))
                    (projects (mapcar 'file-name-nondirectory files))
                    (dirs
                     (mapcar (lambda (dir) (cons (file-name-sans-extension
                                                  (file-name-nondirectory dir))
                                                 dir))
                             files)))
               (-map-indexed
                (lambda (index item)
                  (list
                   (substring iz-capture-keycodes index (+ 1 index))
                   (car item)
                   'entry
                   (list 'file+headline (cdr item) "TODOs")
                   "* TODO %?\n :PROPERTIES:\n :DATE:\t%U\n :END:\n\n%i\n"))
                dirs)))))

(defun iz-goto (&optional level)
  (interactive "P")
  (if level
      (setq org-refile-targets (list (cons (iz-select-file-from-folders) (cons :level level))))
    (setq org-refile-targets (list (cons (iz-select-file-from-folders) '(:maxlevel . 3)))))
  (org-refile '(4)))

(defun iz-refile (&optional goto)
  "Refile to selected file."
  (interactive "P")
  (setq org-refile-targets
        (list (cons (iz-select-file-from-folders) '(:maxlevel . 3))))
  (org-refile goto))

(defun iz-org-file-command-menu ()
  "Menu of commands operating on iz org files."
(interactive)
  (let* ((menu (grizzl-make-index
                '(
                  "iz-log"
                  "iz-todo"
                  "iz-refile-to-date-tree"
                  "iz-refile"
                  "iz-open-project-folder"
                  "iz-find-file"
                  "iz-goto"
                  "iz-goto-last-selected-file"
                  "org-agenda"
                  "iz-get-and-refile-mobile-entries"
                  "iz-refile-notes-to-log"
                  "iz-insert-file-as-snippet"
                  "iz-scratchpad-menu"
                  "iz-diary-entry"
                  "org-export-subtree-as-latex-with-header-from-file"
                  "org-export-subtree-as-pdf-with-header-from-file"
                  "org-export-buffer-as-latex-with-header-from-file"
                  "org-export-buffer-as-pdf-with-header-from-file"
                  )))
         (selection (grizzl-completing-read "Select command: " menu)))
    (eval (list (intern selection)))))

(global-set-key (kbd "H-h H-m") 'iz-org-file-command-menu)
(global-set-key (kbd "H-h H-h") 'iz-org-file-command-menu)
(global-set-key (kbd "H-h H-f") 'iz-find-file-flat)
(global-set-key (kbd "H-h H-F") 'iz-find-file)
(global-set-key (kbd "H-h H-s") 'sr-speedbar-toggle)
(global-set-key (kbd "H-h H-d") 'iz-open-project-folder)
(global-set-key (kbd "H-h H-l") 'iz-log-flat)
(global-set-key (kbd "H-h H-L") 'iz-log)
(global-set-key (kbd "H-h L") 'iz-goto-last-selected-file)
(global-set-key (kbd "H-h H-i") 'iz-insert-file-as-snippet)
(global-set-key (kbd "H-h H-t") 'iz-todo)
(global-set-key (kbd "H-h H-r") 'iz-refile)
(global-set-key (kbd "H-h r") 'iz-refile-to-date-tree)
(global-set-key (kbd "H-h H-g") 'iz-goto)
(global-set-key (kbd "H-h H-c H-w") 'iz-refile)
(global-set-key (kbd "H-h H-c H-a") 'org-agenda)
(global-set-key (kbd "H-h H-a") 'org-agenda-list)
(global-set-key (kbd "H-h H-t") 'org-todo-list)

;; Adding alternatives for apple extended keyboard
(global-set-key (kbd "<f13> m") 'iz-org-file-command-menu)
;; (global-set-key (kbd "<f13> <f13>") 'iz-org-file-command-menu)
(global-set-key (kbd "<f13> f") 'iz-find-file-flat)
(global-set-key (kbd "<f13> F") 'iz-find-file)
(global-set-key (kbd "<f13> S") 'sr-speedbar-toggle)
(global-set-key (kbd "<f13> d") 'iz-open-project-folder)
(global-set-key (kbd "<f13> l") 'iz-log-flat)
(global-set-key (kbd "<f13> L") 'iz-log)
(global-set-key (kbd "<f13> C-l") 'iz-goto-last-selected-file)
(global-set-key (kbd "<f13> i") 'iz-insert-file-as-snippet)
(global-set-key (kbd "<f13> t") 'iz-todo)
(global-set-key (kbd "<f13> r") 'iz-refile)
(global-set-key (kbd "<f13> r") 'iz-refile-to-date-tree)
(global-set-key (kbd "<f13> g") 'iz-goto)
(global-set-key (kbd "<f13> c w") 'iz-refile)
(global-set-key (kbd "<f13> c a") 'org-agenda)
(global-set-key (kbd "<f13> a") 'org-agenda-list)
(global-set-key (kbd "<f13> t") 'org-todo-list)

;; Experimental:
(defun iz-make-finance-capture-template ()
  (setq org-capture-templates
        (list
         (list
          "f" "FINANCE"
          'entry
          (list 'file+datetree (concat iz-log-dir "projects/FINANCE.org"))
          "* %^{title}\n :PROPERTIES:\n :DATE:\t%T\n :END:\n%^{TransactionType}p%^{category}p%^{amount}p\n%?\n"
          ))))

(defun superdeft ()
  "Open Deft with a folder selected from the notes directory."
  (interactive)
  (let ((path (concat iz-log-dir (iz-select-folder))))
    (when (and
           (get-buffer  "*Deft*")
           (not (equal deft-directory path)))
      (kill-buffer "*Deft*"))
    (setq deft-directory path)
    (deft)))

(defun deft-log ()
  "Capture datetree log entry in current deft file."
  (interactive)
  (if (get-buffer "*Deft*")
      (deft)
    (superdeft))
  ;; (org-log-here (widget-get (widget-at) :tag))
  )

(defun org-agenda-here ()
  "Open agenda in week view mode."
  (interactive)
  ;; (setq org-agenda-files (list (buffer-file-name)))
  ;; (org-log-here (buffer-file-name) t)
  (org-agenda nil "a"))

(defun org-capture-here ()
  "Create org-capture todo or date entries in FILE, or default files."
  (interactive)
  (message "AT THE START IT WAS: %s" (buffer-file-name))
  (let* ((journal (concat iz-log-dir org-diary-file))
        (todos (concat iz-log-dir org-diary-file)) ;; use same file for the moment
        entry-string 
        (file (if (and (eq major-mode 'org-mode) (buffer-file-name (current-buffer)))
                  (buffer-file-name (current-buffer))
                (file-truename (concat iz-log-dir org-diary-file))))
        (file-base (file-name-base file))
        (tag (format "\t:%s:" (file-name-base file))))
    (message "MAJOR MODE %s" major-mode)
    (message "buffer-file-name is: %s" buffer-file-name)
    ;; (setq org-capture-current-file file)
    ;; TODO: Global variable. Let?
    (setq org-capture-templates
          (list ;; TODO: rewrite this nested list using ` and ,
           (list
            "t"
            (format "TODO: %s" file-base)
            'entry (list 'file+headline todos "Tasks")
            (concat "* TODO %?" tag
                    (concat
                     "\n :PROPERTIES:\n :DATE:\t%U\n :SOURCE_FILE: file:"
                     file
                     "\n :END:\n\n%i\n")))
           (list
            "d"
            (format "DIARY ENTRY: %s" file-base)
            'entry (list 'file+datetree+prompt journal)
            ;; file+datetree does not work with the capture hoook
            ;; (list 'file+datetree+prompt journal)
            (concat "* %?" tag (concat
                                "\n :PROPERTIES:\n :DATE:\t%T\n :SOURCE_FILE: file:"
                                file
                                "\n :END:\n\n%i\n")))))
    (org-capture)))

(defun org-agenda-include-source-file (remove)
  "If property FILE is defined, then add the path stored in FILE to the agenda file list.
REMOVE not yet implemented!
If called with prefix-argument, remove that file instead."
  (interactive "P")
  (org-agenda-switch-to)
  (let ((file (org-entry-get (point) "SOURCE_FILE")))
    (if (and file (file-exists-p
                   (setq file (replace-regexp-in-string "^file:" "" file))))
        (add-to-list 'org-agenda-files file)
      (message "File not found! %s" file))
   (org-agenda nil "a")
   (switch-to-buffer "*Org Agenda*")))

(define-key org-agenda-mode-map "&" 'org-agenda-include-source-file)
;; (org-agenda-add-file "/Users/iani/Documents/000WORKFILES/1_PROJECTS_CURRENT/JOINT_PROJECTS_IU/EASTM.org")

;; (global-set-key (kbd "C-S-s") 'superdeft)
;; (global-set-key (kbd "C-S-d") 'superdeft)
(global-set-key (kbd "C-S-l") 'deft-log)
(global-set-key (kbd "C-c q a") 'org-agenda-here)
(global-set-key (kbd "C-c q c") 'org-capture-here)

(defun org-capture-add-cache ()
  (let* ((heading-components (org-heading-components))
         (heading (nth 4 heading-components))
         (tags (nth 5 heading-components))
         (source-file org-capture-current-file)
         (id (org-id-get-create))
         (date (org-entry-get (point) "DATE")))
    (save-excursion
      (find-file (file-truename (concat iz-log-dir org-diary-file)))
      (end-of-buffer)
      (insert-string
       (format "\n\n* %s\n :PROPERTIES:\n :DATE: %s\n :SOURCE_FILE: %s\n :END:\n\n"
               heading
               ;; tags
               date
               source-file))
      (insert-string
       (format "\n- LINK TO ORIGINAL SECTION: [[id:%s][%s]]\n- LINK TO FILE: file:%s\n"
               id
               heading
               source-file))
      (org-edit-src-save))))

;; Disabled: Problems
;; (add-hook 'org-capture-prepare-finalize-hook 'org-capture-add-cache)

(provide 'org-notes)

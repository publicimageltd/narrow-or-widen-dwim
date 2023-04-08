;;; narrow-or-widen-dwim.el --- Add more intelligence to narrowing or widening  -*- lexical-binding: t; -*-

;; Copyright (C) 2021-2023

;; Author:  <joerg@joergvolbers.de>
;; Keywords: outlines, tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Provides just one command, narrow-or-widen-dwim, which see.

;;; Code:

;;; * Store line position when narrowing

(defvar narrow-or-widen-dwim--window-start nil
  "INTERNAL. Position correction when widening again.")

(defvar narrow-or-widen-dwim-window-split-function
  #'split-window-horizontally
  "Display cloned buffers in a window returned by that function.")

  
;;; * Declare major mode specific functions

;; Declare all major mode specific functions to avoid requir'ing them
;; all. They will be called only if the mode is loaded, anyways.

(declare-function org-narrow-to-block
		  "org"
		  ())
(declare-function org-narrow-to-subtree
		  "org"
		  ())
(declare-function org-edit-src-code
		  "org-src"
		  (&optional code edit-buffer-name))
(declare-function outline-up-heading
		  "outline"
		  (arg &optional invisible-ok))
(declare-function LaTeX-narrow-to-environment
		  "latex"
		  (&optional COUNT))
(declare-function narrow-to-defun
		  "lisp"
		  (&optional INCLUDE-COMMENTS))

;;; * Narrow or widen dwim

(defun narrow-or-widen--switch-buffer-niceley (buf)
  "Select the window displaying BUF or create a new one.
The new window is created by calling the function stored in
`narrow-or-widen-dwim-window-split-function'. It has to return
the window in which the cloned buffer should be displayed."
  (when buf
    (if (get-buffer-window buf)
	(switch-to-buffer buf)
      (select-window (funcall narrow-or-widen-dwim-window-split-function))
      (switch-to-buffer buf t t))))

(defun narrow-or-widen--org-narrow (&optional arg)
  "In org mode, dwim-narrow.
Prefix ARG is used to narrow to the next 'upper' top tree level.
The numeric argument is interpreted unorthodoxically: One
prefix (C-u) means 'one top level up', two prefixes (C-u C-u)
means 'two levels up', etc. Real numeric arguments (like C-u 3)
should not be used; they are divided by four and rounded up to
determine the number of levels 'up'"
  (unless (mod arg 4)
    (user-error "Prefix arg has to be a multiple of 4"))
  (cond
   ((ignore-errors (org-edit-src-code) t)
    (delete-other-windows))
   ((ignore-errors (org-narrow-to-block) t))
   (t
    (progn
      (save-excursion
	(when (> arg 1)
	  (outline-up-heading (ceiling (/ arg 4)) t))
        (if (org-before-first-heading-p)
            (user-error "Point not at a subtree, cannot narrow")
	  (org-narrow-to-subtree)))))))

;;;###autoload
(defun narrow-or-widen-dwim (&optional n)
    "Widen if buffer is narrowed, narrow-dwim otherwise.
Dwim means: region, org-src-block, org-subtree, or
defun, whichever applies first."
  (interactive "p")
  (declare (interactive-only))
  (cond (;; widen, if narrowed:
	 (buffer-narrowed-p)
	 (progn
	   (widen)
	   (when narrow-or-widen-dwim--window-start
	     (set-window-start (selected-window) narrow-or-widen-dwim--window-start t)
	     (setq narrow-or-widen-dwim--window-start nil))))
	;; narrow to region, if defined:
	((region-active-p)
	 (progn
	   (setq narrow-or-widen-dwim--window-start (window-start))
	   (narrow-to-region (region-beginning) (region-end))
	   (deactivate-mark)
	   (goto-char (point-min))))
	;; special handling in org mode buffers:
	((derived-mode-p 'org-mode)
	 (progn
	   (setq narrow-or-widen-dwim--window-start (window-start))
	   (narrow-or-widen--org-narrow n)))
	;; special handling in latex mode buffers:
	((derived-mode-p 'latex-mode)
	 (progn
	   (setq narrow-or-widen-dwim--window-start (window-start))
	   (LaTeX-narrow-to-environment n)))
	;; special handling in prog mode buffers:
	((derived-mode-p 'prog-mode)
	 (let* ((arg (not (eq n 1)))
		(narrow-to-defun-include-comments arg))
	   (setq narrow-or-widen-dwim--window-start (window-start))
	   (narrow-to-defun arg)))
	;; else we don't know what to do:
	(t (user-error "No suitable narrowing command available for this major mode"))))

;;;###autoload
(defun narrow-or-widen-dwim-clone (&optional n)
  "Do `narrow-or-widen-dwim' in a new indirect buffer.
Returns the new buffer."
  (interactive "p")
  (declare (interactive-only))
  (when (buffer-narrowed-p)
    (user-error "You have to widen the buffer to clone something"))
  (let* ((calling-buffer (current-buffer))
         (cloned-buffer (clone-indirect-buffer nil nil t)))
    (narrow-or-widen--switch-buffer-niceley cloned-buffer)
    (with-current-buffer cloned-buffer
      (narrow-or-widen-dwim n))
    (with-current-buffer calling-buffer
      (when (region-active-p)
        (deactivate-mark)))
    cloned-buffer))

;;;###autoload
(defun narrow-or-widen-dwim-stash (&optional n)
  "Move the entity at point in a new buffer."
  (interactive "p")
  (declare (interactive-only))
  (when (buffer-narrowed-p)
    (user-error "You have to widen the buffer to stash something"))
  (let* ((orig-buf (current-buffer))
         (orig-name (buffer-name))
         (new-buf (narrow-or-widen-dwim-clone n)))
    (with-current-buffer new-buf
      (let* ((content (buffer-string)))
        (widen)
        (delete-region (point-min) (point-max))
        (insert content))
      (rename-buffer (format "from '%s'" orig-name)))))

(provide 'narrow-or-widen-dwim)
;;; narrow-or-widen-dwim.el ends here

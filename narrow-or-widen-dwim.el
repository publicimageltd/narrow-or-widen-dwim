;;; narrow-or-widen-dwim.el --- Add more intelligence to narrowing or widening  -*- lexical-binding: t; -*-

;; Copyright (C) 2021

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

(defun narrow-or-widen--org-narrow (&optional arg)
  "In org mode, dwim-narrow.
Prefix ARG is used to narrow to the next 'upper' top tree level.
The numeric argument is interpreted unorthodoxically: One
prefix (C-u) means 'one top level up', two prefixes (C-u C-u)
means 'two levels up', etc. Real numeric arguments (like C-u 3)
should not be used; they are divided by four and rounded up to
determine the number of levels 'up'"
  (cond
   ((ignore-errors (org-edit-src-code) t)
    (delete-other-windows))
   ((ignore-errors (org-narrow-to-block) t))
   (t
    (progn
      (when (> arg 1)
	(outline-up-heading (ceiling (/ arg 4)) t))
      (org-narrow-to-subtree)))))

;;;###autoload
(defun narrow-or-widen-dwim (&optional n)
    "Widen if buffer is narrowed, narrow-dwim otherwise.
Dwim means: region, org-src-block, org-subtree, or
defun, whichever applies first."
  (interactive "p")
  (declare (interactive-only))
  (cond (;; widen, if narrowed:
	 (buffer-narrowed-p)
	 (widen))
	;; narrow to region, if defined:
	((region-active-p)
	 (progn
	   (narrow-to-region (region-beginning)
			     (region-end))
	   (deactivate-mark)
	   (goto-char (point-min))))
	;; special handling in org mode buffers:
	((derived-mode-p 'org-mode)
	 (narrow-or-widen--org-narrow n))
	;; special handling in latex mode buffers:
	((derived-mode-p 'latex-mode)
	 (LaTeX-narrow-to-environment n))
	;; special handling in prog mode buffers:
	((derived-mode-p 'prog-mode)
	 (narrow-to-defun n))
	;; else we don't know what to do:
	(t (user-error "No suitable narrowing command available for this major mode"))))

(provide 'narrow-or-widen-dwim)
;;; narrow-or-widen-dwim.el ends here

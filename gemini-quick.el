;;; gemini-quick.el --- Make a gemini chat api call with your current buffer  -*- lexical-binding: t; -*-

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Just take the current buffer and put it into a gemini api call.

(require 'request)
(require 's)

(defcustom gemini-api-key
  (let ((s))
    (lambda ()
      (setf
       s
       (or
        (getenv "GEMINI_API_KEY")
        (shell-command-to-string "pass gai/gemini-api-key-1")))))
  "Function to get API key for gemini, called without arguments.")

(defun quick-gemini-chat (arg)
  (interactive "P")
  (message "%s" arg))

(defcustom gemini-default-model
  "gemini-1.5-flash"
  "Default model for gemini chat")

(defvar gemini-model gemini-default-model)
(defvar gemini-model
  ;; "gemini-2.0-pro-exp-02-05"
  ;; "gemini-2.0-flash-thinking-exp-01-21"
  ;; "gemini-2.0-flash-lite-preview-02-05"
  "gemini-2.0-flash" )

(define-derived-mode gemini-chat-mode text-mode "Gemini Chat")

;; keymap
(defvar gemini-chat-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "RET" #'gemini-chat-select-markdown-block)
    map)
  "Keymap for `gemini-chat-mode'.")

(defun quick-gemini-chat (arg)
  "Send buffer content (or region) to Gemini and display response in '*gemini-output*'.

With a prefix argument ARG, prompts for a question to append to the buffer content
before sending to Gemini.

The response from Gemini will be displayed in a buffer named '*gemini-output*'.
If there's an error, error details will also be shown in '*gemini-output*'."
  (interactive "P")
  (let* ((text (if (use-region-p)
                   (buffer-substring-no-properties
                    (region-beginning)
                    (region-end))
                 (buffer-substring-no-properties
                  (point-min)
                  (point-max))))
         (text (concat
                text
                (when arg
                  (concat
                   "\n"
                   (read-string "Q: ")))))
         (output-buffer (get-buffer-create "*gemini-output*" (s-trim (shell-command-to-string "date +%s"))))
         (api-key (funcall gemini-api-key))
         (url (concat
               "https://generativelanguage.googleapis.com/v1beta/models/"
               gemini-model
               ":generateContent?key="
               api-key)))
    (message "gemmini chat request...")
    (request
      url
      :headers '(("Content-Type" . "application/json"))
      :data (json-encode
             `(("contents" . ((("parts" . ((("text" . ,text)))))))))
      :type "POST"
      :parser 'json-read
      :success (cl-function
                (lambda (&key data &allow-other-keys)
                  ;; (defvar thedata data)
                  (with-current-buffer
                      output-buffer
                    (erase-buffer)
                    (gemini-chat-mode)
                    (insert
                     (alist-get
                      'text
                      (car
                       (mapcar
                        #'identity
                        (alist-get
                         'parts
                         (alist-get
                          'content
                          (car (mapcar
                                #'identity
                                (alist-get 'candidates data)))))))))
                    (display-buffer
                     (current-buffer)))))
      :error (cl-function
              (lambda (&key data &allow-other-keys)
                (with-current-buffer output-buffer
                  (erase-buffer)
                  (insert (format "%s" data))
                  (display-buffer
                   (current-buffer))))))))

(defun gemini-chat-select-markdown-block ()
  (interactive)
  (let ((beg (progn
               (re-search-backward "^```")
               (forward-line 1)
               (point)))
        (end (progn
               (re-search-forward "^```")
               (beginning-of-line)
               (point))))
    (save-excursion
      (goto-char beg)
      (set-mark beg)
      (goto-char end))))

(provide 'gemini-quick)



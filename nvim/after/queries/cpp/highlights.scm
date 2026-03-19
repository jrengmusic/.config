;; extends

;; Preprocessor directives - make bold lime
((preproc_directive) @keyword.directive (#set! priority 200))

;; Preprocessor arguments (like 'once' in #pragma once)
((preproc_arg) @keyword.directive (#set! priority 200))

;; Preprocessor conditionals - identifiers inside #if/#ifdef/#ifndef
(preproc_if
  condition: (_) @keyword.directive (#set! priority 200))

(preproc_ifdef
  name: (identifier) @keyword.directive (#set! priority 200))

(preproc_defined
  (identifier) @keyword.directive (#set! priority 200))

;; extends

; Azure Pipelines `- bash: |` steps.
;
; nvim-treesitter's yaml injections.scm only injects bash for GitHub Actions
; ("run"), GitLab CI ("script"/"before_script"/"after_script") and Taskfile
; ("cmds"/"cmd"/"sh"). Azure DevOps spells its shell step `bash:`, which isn't
; in that list, so every line of the block scalar stayed a single yaml @string
; — no keywords, no strings, and no comment nodes at all (verify with :Inspect).
; Same shapes as upstream: block scalar (`bash: |`) and plain scalar
; (`bash: echo hi`). The `#offset!` skips the `|`/`>` indicator line so the
; injected range starts at the first script line.
;
; Only bash is added here: `pwsh:`/`powershell:` steps would need the
; `powershell` parser, which isn't in lua/util/treesitter-parsers.lua.
(block_mapping_pair
  key: (flow_node) @_bash
  (#eq? @_bash "bash")
  value: (block_node
    (block_scalar) @injection.content
    (#set! injection.language "bash")
    (#offset! @injection.content 0 1 0 0)))

(block_mapping_pair
  key: (flow_node) @_bash
  (#eq? @_bash "bash")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
    (#set! injection.language "bash")))

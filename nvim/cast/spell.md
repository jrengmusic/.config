## index

| alias    | symbol                  |
| -------- | ----------------------- |
| @keymaps | ../doc/KEYMAPS.md       |
| @lua     | keymaps.cast            |
| @out     | ../lua/core/keymaps.lua |

## output

+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+
| list                                          | separator | structure                                                                                       | file |
+===============================================+===========+=================================================================================================+======+
| - [list]: @keymaps:requires:group=general     |           | @lua:module                                                                                     | @out |
| - [list]: @keymaps:keys:group=general         |           |                                                                                                 |      |
| - [list]: @keymaps:keys:options               |           | @lua:function                                                                                   |      |
|                                               |           | - name: setup                                                                                   |      |
|                                               |           | - [list]: @lua:require                                                                          |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+
| - [list]: @keymaps:requires:group=lsp         |           | @lua:module                                                                                     | @out |
| - [list]: @keymaps:keys:group=lsp             |           |                                                                                                 |      |
| - [list]: @keymaps:keys:group=lsp-clangd      |           | @lua:function-client                                                                            |      |
| - [list]: @keymaps:keys:group=lsp-inlay       |           | - name: setupLsp                                                                                |      |
| - [list]: @keymaps:keys:options               |           | - parameter: event                                                                              |      |
| - [list]: @keymaps:keys:options               |           | - [list]: @lua:require                                                                          |      |
| - [list]: @keymaps:keys:options               |           | - [list]: @lua:key                                                                              |      |
|                                               |           |                                                                                                 |      |
|                                               |           | @lua:guard                                                                                      |      |
|                                               |           | - condition: client and client.name == 'clangd'                                                 |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
|                                               |           |                                                                                                 |      |
|                                               |           | @lua:guard                                                                                      |      |
|                                               |           | - condition: client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+
| - [list]: @keymaps:requires:group=dap         |           | @lua:module                                                                                     | @out |
| - [list]: @keymaps:keys:group=dap             |           |                                                                                                 |      |
| - [list]: @keymaps:keys:options               |           | @lua:function                                                                                   |      |
|                                               |           | - name: setupDap                                                                                |      |
|                                               |           | - [list]: @lua:require                                                                          |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+
| - [list]: @keymaps:requires:group=minipairs   |           | @lua:module                                                                                     | @out |
| - [list]: @keymaps:keys:group=minipairs       |           |                                                                                                 |      |
| - [list]: @keymaps:keys:options               |           | @lua:function                                                                                   |      |
|                                               |           | - name: setupMiniPairs                                                                          |      |
|                                               |           | - [list]: @lua:require                                                                          |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+
| - [list]: @keymaps:keys:group=flash           |           | @lua:module                                                                                     | @out |
| - [list]: @keymaps:keys:options               |           |                                                                                                 |      |
|                                               |           | @lua:function-plain                                                                             |      |
|                                               |           | - name: setupFlash                                                                              |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+
| - [list]: @keymaps:requires:group=textobjects |           | @lua:module                                                                                     | @out |
| - [list]: @keymaps:keys:group=textobjects     |           |                                                                                                 |      |
| - [list]: @keymaps:keys:options               |           | @lua:function                                                                                   |      |
|                                               |           | - name: setupTextobjects                                                                        |      |
|                                               |           | - [list]: @lua:require                                                                          |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+
| - [list]: @keymaps:requires:group=snippets    |           | @lua:module                                                                                     | @out |
| - [list]: @keymaps:keys:group=snippets        |           |                                                                                                 |      |
| - [list]: @keymaps:keys:options               |           | @lua:function                                                                                   |      |
|                                               |           | - name: setupSnippets                                                                           |      |
|                                               |           | - [list]: @lua:require                                                                          |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+
| - [list]: @keymaps:keys:group=99              |           | @lua:module                                                                                     | @out |
| - [list]: @keymaps:keys:options               |           |                                                                                                 |      |
|                                               |           | @lua:function-plain                                                                             |      |
|                                               |           | - name: setup99                                                                                 |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+
| - [list]: @keymaps:keys:group=qf              |           | @lua:module                                                                                     | @out |
| - [list]: @keymaps:keys:options               |           |                                                                                                 |      |
|                                               |           | @lua:function-plain                                                                             |      |
|                                               |           | - name: setupDiagnosticsQf                                                                      |      |
|                                               |           | - parameter: event                                                                              |      |
|                                               |           | - [list]: @lua:key                                                                              |      |
+-----------------------------------------------+-----------+-------------------------------------------------------------------------------------------------+------+

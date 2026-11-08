; extends

; Only the first argument of configured methods is SQL.
(call_expression
  function: (field_expression
    field: (field_identifier) @_sql_api)
  arguments: (arguments
    .
    [
      (string_literal (string_content) @injection.content)
      (raw_string_literal (string_content) @injection.content)
    ])
  (#rust-sql-api? @_sql_api "methods")
  (#set! injection.language "sql"))

; Macro paths are matched exactly, including any namespace.
(macro_invocation
  macro: [
    (identifier)
    (scoped_identifier)
  ] @_sql_api
  (token_tree
    .
    [
      (string_literal (string_content) @injection.content)
      (raw_string_literal (string_content) @injection.content)
    ])
  (#rust-sql-api? @_sql_api "macros")
  (#set! injection.language "sql"))

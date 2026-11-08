local M = {}

-- Method names match any receiver (Tree-sitter cannot resolve Rust types).
M.methods = { "execute", "execute_batch", "prepare", "query_row" }

-- Exact macro paths, without !, e.g. { "sqlx::query", "sqlx::query_as" }.
-- Only the first argument is treated as SQL; aliases must be listed separately.
M.macros = {}

function M.setup()
  vim.treesitter.query.add_predicate("rust-sql-api?", function(match, _, source, predicate)
    local nodes = match[predicate[2]]
    local node = type(nodes) == "table" and nodes[1] or nodes
    return node ~= nil and vim.tbl_contains(M[predicate[3]] or {}, vim.treesitter.get_node_text(node, source))
  end, { force = true })
end

return M

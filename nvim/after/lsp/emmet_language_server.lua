return {
  on_attach = function(client, bufnr)
    vim.keymap.set("i", "<c-s>,", function()
      client.request(
        "textDocument/completion",
        vim.lsp.util.make_position_params(0, client.offset_encoding),
        function(_, result)
          local textEdit = result.items[1].textEdit
          local snip_string = textEdit.newText
          textEdit.newText = ""
          vim.lsp.util.apply_text_edits({ textEdit }, bufnr, client.offset_encoding)
          vim.snippet.expand(snip_string)
        end,
        bufnr
      )
    end, { noremap = true, buffer = bufnr, desc = "Expand emmet" })
  end,
}

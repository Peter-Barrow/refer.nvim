if vim.g.loaded_refer == 1 then
    return
end
vim.g.loaded_refer = 1

local refer = require "refer"

refer.add_command("Files", function(opts)
    require("refer.providers.files").files(opts)
end)
refer.add_command("Grep", function(opts)
    require("refer.providers.files").live_grep(opts)
end)
refer.add_command("Buffers", function(opts)
    require("refer.providers.builtin").buffers(opts)
end)
refer.add_command("OldFiles", function(opts)
    require("refer.providers.builtin").old_files(opts)
end)
refer.add_command("Commands", function(opts)
    require("refer.providers.builtin").commands(opts)
end)
refer.add_command("Macros", function(opts)
    require("refer.providers.builtin").macros(opts)
end)
refer.add_command("References", function(opts)
    require("refer.providers.lsp").references(opts)
end)
refer.add_command("Definitions", function(opts)
    require("refer.providers.lsp").definitions(opts)
end)
refer.add_command("Implementations", function(opts)
    require("refer.providers.lsp").implementations(opts)
end)
refer.add_command("Declarations", function(opts)
    require("refer.providers.lsp").declarations(opts)
end)
refer.add_command("LspServers", function(opts)
    require("refer.providers.lsp").lsp_servers(opts)
end)
refer.add_command("Selection", function(opts)
    require("refer.providers.files").grep_word(opts)
end)
refer.add_command("Lines", function(opts)
    require("refer.providers.files").lines(opts)
end)
refer.add_command("Symbols", function(opts)
    require("refer.providers.lsp").document_symbols(opts)
end)

vim.api.nvim_create_user_command("Refer", function(opts)
    local subcommand_key = opts.fargs[1]
    local func = refer.get_commands()[subcommand_key]
    if func then
        func(opts)
    else
        vim.notify("Refer: Unknown subcommand: " .. subcommand_key, vim.log.levels.ERROR)
    end
end, {
    nargs = 1,
    range = true,
    complete = function(ArgLead, CmdLine, CursorPos)
        local keys = vim.tbl_keys(refer.get_commands())
        table.sort(keys)
        return vim.tbl_filter(function(key)
            return key:find(ArgLead, 1, true) == 1
        end, keys)
    end,
})

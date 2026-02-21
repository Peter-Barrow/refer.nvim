-- Run with: nvim -u .github/repro.lua
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system {
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    }
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup {
    {
        "juniorsundar/refer.nvim",
        -- dir = vim.fn.getcwd(),
        config = function()
            require("refer").setup {
                max_height_percent = 0.4,
                min_height = 1,
                debounce_ms = 100,
                min_query_len = 2,
                available_sorters = { "blink", "mini", "native", "lua" },
                default_sorter = "native",
                preview = {
                    enabled = true,
                    max_lines = 1000,
                },
                ui = {
                    mark_char = "●",
                    mark_hl = "String",
                    input_position = "top",
                    reverse_result = false,
                    winhighlight = "Normal:Normal,FloatBorder:Normal,WinSeparator:Normal,StatusLine:Normal,StatusLineNC:Normal",
                    highlights = {
                        prompt = "Title",
                        selection = "Visual",
                        header = "WarningMsg",
                    },
                },
                providers = {
                    files = {
                        ignored_dirs = { ".git", ".jj", "node_modules", ".cache" },
                        find_command = { "fd", "-H", "--type", "f", "--color", "never" },
                    },
                    grep = {
                        grep_command = { "rg", "--vimgrep", "--smart-case" },
                    },
                },
            }
        end,
    },
}

vim.keymap.set("n", "<space>f", ":Refer Files<CR>", { desc = "Refer Files" })
vim.keymap.set("n", "<space>g", ":Refer Grep<CR>", { desc = "Refer Grep" })
vim.keymap.set("n", "<space>b", ":Refer Buffers<CR>", { desc = "Refer Buffers" })
vim.keymap.set("n", "<space>o", ":Refer OldFiles<CR>", { desc = "Refer Old Files" })
vim.keymap.set("n", "<A-x>", ":Refer Commands<CR>", { desc = "Refer Commands" })


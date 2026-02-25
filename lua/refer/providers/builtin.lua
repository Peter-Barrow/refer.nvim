---@class BuiltinProvider
local M = {}

local refer = require "refer"
local util = require "refer.util"

---Open command picker (like M-x in Emacs)
---Shows all available vim commands with completion
function M.commands(opts)
    local history_state = {
        index = 0,
        prefix = nil,
        last_tick = nil,
        matches = nil,
    }

    local function cycle_history(builtin, direction)
        local input_buf = builtin.picker.input_buf
        local current_tick = vim.api.nvim_buf_get_changedtick(input_buf)

        if history_state.last_tick and current_tick ~= history_state.last_tick then
            history_state.index = 0
            history_state.prefix = nil
            history_state.matches = nil
        end

        if not history_state.matches then
            local input = vim.api.nvim_get_current_line()
            history_state.prefix = input
            history_state.matches = {}
            local seen = {}
            local count = vim.fn.histnr "cmd"
            for i = count, 1, -1 do
                local entry = vim.fn.histget("cmd", i)
                if entry and entry ~= "" and not seen[entry] then
                    if not history_state.prefix or vim.startswith(entry, history_state.prefix) then
                        table.insert(history_state.matches, entry)
                        seen[entry] = true
                    end
                end
            end
        end

        local new_index = history_state.index + direction
        if new_index < 0 then
            new_index = 0
        elseif new_index > #history_state.matches then
            new_index = #history_state.matches
        end

        if new_index == history_state.index then
            return
        end

        local text_to_show
        if new_index == 0 then
            text_to_show = history_state.prefix
        else
            text_to_show = history_state.matches[new_index]
        end

        history_state.index = new_index
        builtin.picker.ui:update_input { text_to_show }

        history_state.last_tick = vim.api.nvim_buf_get_changedtick(input_buf)
    end

    local default_text = nil
    if (opts and opts.range == 2) or vim.fn.mode():find "^[vV\22]" then
        default_text = "'<,'>"
    end

    local preview_applied = false
    local original_win = vim.api.nvim_get_current_win()
    local original_buf = vim.api.nvim_win_get_buf(original_win)

    local function cleanup_preview()
        if preview_applied then
            vim.api.nvim_buf_call(original_buf, function()
                pcall(vim.cmd, "silent! undo")
            end)
            preview_applied = false
        end
    end

    local function do_sub_preview(input)
        cleanup_preview()

        -- Strip optional *do prefix (cdo, cfdo, argdo, bufdo, windo, tabdo)
        -- before matching the substitute pattern, so preview works for both
        -- plain substitutes and do-command substitutes.
        local do_cmd, do_rest = input:match "^([a-z]*do)%s+(.*)$"
        local stripped = do_rest or input

        local range, sep = stripped:match "^([%%'%d,$.<>]*)s(.)"
        if not sep or sep:match "[%w%s]" then
            return
        end

        -- When a *do prefix was present, apply the substitute across the whole
        -- buffer for preview (the real do-loop runs per-line on confirm).
        if do_cmd then
            if range == "" or range == nil then
                stripped = "%" .. stripped
            end
        end
        input = stripped

        local unescaped_count = 0
        local i = 1
        while i <= #input do
            local c = input:sub(i, i)
            if c == "\\" then
                i = i + 2
            elseif c == sep then
                unescaped_count = unescaped_count + 1
                i = i + 1
            else
                i = i + 1
            end
        end

        local preview_input = input
        if unescaped_count >= 3 then
            local esc_sep = sep:gsub("%W", "%%%1")
            local match_flags = input:match(esc_sep .. "([&cegiInp#lr]*)$")
            if match_flags and match_flags:match "c" then
                local new_flags = match_flags:gsub("c", "")
                preview_input = input:sub(1, -(#match_flags + 1)) .. new_flags
            end
        end

        vim.api.nvim_buf_call(original_buf, function()
            vim.cmd "let &ul=&ul"
            local ok = pcall(vim.cmd, "noautocmd keepjumps " .. preview_input)
            if ok then
                preview_applied = true
            end
        end)
    end

    return refer.pick(
        function(input)
            if input == "" then
                return vim.fn.getcompletion("", "command")
            end
            local matches = vim.fn.getcompletion(input, "cmdline")
            local prefix = input:match "^'[<a-z],'[>a-z]" or input:match "^%d+,%d+"
            if prefix then
                local remainder = input:sub(#prefix + 1)
                if not remainder:match "[%s%.%/:\\\\]" then
                    local new_matches = {}
                    for _, m in ipairs(matches) do
                        if not vim.startswith(m, prefix) then
                            table.insert(new_matches, prefix .. m)
                        else
                            table.insert(new_matches, m)
                        end
                    end
                    return new_matches
                end
            end
            return matches
        end,
        function(input_text)
            cleanup_preview()
            vim.fn.histadd("cmd", input_text)
            vim.cmd(input_text)
        end,
        vim.tbl_deep_extend("force", {
            prompt = "M-x > ",
            default_text = default_text,
            keymaps = {
                ["<C-p>"] = function(_, builtin)
                    cycle_history(builtin, 1)
                end,
                ["<C-n>"] = function(_, builtin)
                    cycle_history(builtin, -1)
                end,
            },
            on_change = function(input, update_ui_callback)
                do_sub_preview(input)

                local matches
                if input == "" then
                    matches = vim.fn.getcompletion("", "command")
                else
                    matches = vim.fn.getcompletion(input, "cmdline")
                    local prefix = input:match "^'[<a-z],'[>a-z]" or input:match "^%d+,%d+"
                    if prefix then
                        local remainder = input:sub(#prefix + 1)
                        if not remainder:match "[%s%.%/:\\\\]" then
                            local new_matches = {}
                            for _, m in ipairs(matches) do
                                if not vim.startswith(m, prefix) then
                                    table.insert(new_matches, prefix .. m)
                                else
                                    table.insert(new_matches, m)
                                end
                            end
                            matches = new_matches
                        end
                    end
                end
                update_ui_callback(matches)
            end,
            on_close = function()
                cleanup_preview()
                if opts and opts.on_close then
                    opts.on_close()
                end
            end,
        }, opts or {})
    )
end

---Open buffer picker
---Shows all listed buffers with bufnr, path, and cursor position
---Keymap <C-x> closes the selected buffer
function M.buffers(opts)
    local bufs = vim.api.nvim_list_bufs()
    local items = {}

    for _, bufnr in ipairs(bufs) do
        if vim.bo[bufnr].buflisted then
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name ~= "" then
                local relative_path = util.get_relative_path(name)
                local row_col = vim.api.nvim_buf_get_mark(bufnr, '"')
                if row_col[1] == 0 then
                    row_col[1] = 1
                end
                if row_col[2] == 0 then
                    row_col[2] = 1
                end
                local entry = string.format("%d: %s:%d:%d", bufnr, relative_path, row_col[1], row_col[2])
                table.insert(items, entry)
            end
        end
    end

    return refer.pick(
        items,
        util.jump_to_location,
        vim.tbl_deep_extend("force", {
            prompt = "Buffers > ",
            keymaps = {
                ["<Tab>"] = "toggle_mark",
                ["<CR>"] = "select_entry",
                ["<C-x>"] = function(selection, builtin)
                    local parser = util.parsers.buffer
                    local data = parser(selection)
                    if data and data.bufnr then
                        local win = builtin.parameters.original_win
                        if win and vim.api.nvim_win_is_valid(win) then
                            local current_view_buf = vim.api.nvim_win_get_buf(win)
                            if current_view_buf == data.bufnr then
                                local scratch = vim.api.nvim_create_buf(false, true)
                                vim.bo[scratch].bufhidden = "wipe"
                                vim.api.nvim_win_set_buf(win, scratch)
                            end
                        end

                        pcall(vim.api.nvim_buf_delete, data.bufnr, { force = true })

                        for i, item in ipairs(items) do
                            if item == selection then
                                table.remove(items, i)
                                break
                            end
                        end

                        builtin.actions.refresh()
                    end
                end,
            },
            parser = util.parsers.buffer,
        }, opts or {})
    )
end

---Open recent files picker
---Shows files from v:oldfiles that are still readable
function M.old_files(opts)
    local results = {}

    for _, file in ipairs(vim.v.oldfiles) do
        if vim.fn.filereadable(file) == 1 then
            table.insert(results, file)
        end
    end

    return refer.pick(
        results,
        nil,
        vim.tbl_deep_extend("force", {
            prompt = "Recent Files > ",
            keymaps = {
                ["<Tab>"] = "toggle_mark",
                ["<CR>"] = "select_entry",
            },
            parser = util.parsers.file,
            on_select = function(selection, data)
                util.jump_to_location(selection, data)
                pcall(vim.cmd, 'normal! g`"')
            end,
        }, opts or {})
    )
end

---Open macro editor
---Shows all populated registers and allows live editing of their contents
function M.macros(opts)
    local items = {}
    local registers = 'abcdefghijklmnopqrstuvwxyz0123456789"/-*+.'
    for i = 1, #registers do
        local reg = registers:sub(i, i)
        local val = vim.fn.getreg(reg)
        if val ~= "" then
            -- Convert control chars to human readable <Esc>, <CR>, etc.
            local readable_val = vim.fn.keytrans(val)
            table.insert(items, string.format("%s: %s", reg, readable_val))
        end
    end

    local caller_win = vim.api.nvim_get_current_win()
    local caller_buf = vim.api.nvim_win_get_buf(caller_win)

    local function edit_macro(reg, initial_content, original_win, original_buf, parent_opts)
        local preview_applied = false
        local preview_view = nil
        local preview_fold = nil

        local function cleanup_preview()
            if preview_applied then
                vim.api.nvim_win_call(original_win, function()
                    pcall(vim.cmd, "silent! undo")
                    if preview_view then
                        vim.fn.winrestview(preview_view)
                        preview_view = nil
                    end
                end)
                if preview_fold then
                    vim.wo[original_win].foldmethod = preview_fold.foldmethod
                    vim.wo[original_win].foldexpr   = preview_fold.foldexpr
                    vim.wo[original_win].foldenable = preview_fold.foldenable
                    vim.wo[original_win].foldlevel  = preview_fold.foldlevel
                    vim.wo[original_win].foldcolumn = preview_fold.foldcolumn
                    preview_fold = nil
                end
                preview_applied = false
            end
        end

        local function do_macro_preview(input)
            cleanup_preview()
            if input == "" then
                return
            end

            vim.api.nvim_win_call(original_win, function()
                vim.cmd "let &ul=&ul"
                preview_fold = {
                    foldmethod = vim.wo[original_win].foldmethod,
                    foldexpr   = vim.wo[original_win].foldexpr,
                    foldenable = vim.wo[original_win].foldenable,
                    foldlevel  = vim.wo[original_win].foldlevel,
                    foldcolumn = vim.wo[original_win].foldcolumn,
                }
                vim.wo[original_win].foldmethod = "manual"
                vim.wo[original_win].foldexpr   = ""
                vim.wo[original_win].foldenable = false
                preview_view = vim.fn.winsaveview()
                local termcodes = vim.api.nvim_replace_termcodes(input, true, true, true)
                local ok, err = pcall(vim.cmd, "noautocmd keepjumps normal! " .. termcodes)
                if ok then
                    preview_applied = true
                else
                    preview_view = nil
                    vim.notify("do_macro_preview failed: " .. tostring(err), vim.log.levels.WARN)
                end
            end)
        end

        local function save_macro(input_text)
            cleanup_preview()
            local termcodes = vim.api.nvim_replace_termcodes(input_text, true, true, true)
            vim.fn.setreg(reg, termcodes)
            vim.notify("Updated register '" .. reg .. "'")
        end

        refer.pick(
            {},
            save_macro,
            vim.tbl_deep_extend("force", {
                prompt = string.format("Edit Macro [%s] > ", reg),
                default_text = initial_content,
                preview = { enabled = false },
                keymaps = {
                    ["<CR>"] = "select_input",
                },
                on_change = function(input, update_ui_callback)
                    do_macro_preview(input)
                    update_ui_callback {}
                end,
                on_close = function()
                    cleanup_preview()
                end,
                on_confirm = save_macro,
            }, parent_opts or {})
        )

        do_macro_preview(initial_content)
    end

    local picker = refer.pick(
        items,
        function(selection)
            local reg = selection:sub(1, 1)
            local content = selection:sub(4)

            vim.schedule(function()
                edit_macro(reg, content, caller_win, caller_buf, opts)
            end)
        end,
        vim.tbl_deep_extend("force", {
            prompt = "Macros > ",
            preview = { enabled = false },
            keymaps = {
                ["<CR>"] = "select_entry",
                ["<C-r>"] = function(selection, builtin)
                    if not selection or selection == "" then
                        return
                    end
                    local reg = selection:sub(1, 1)
                    vim.fn.setreg(reg, "")
                    builtin.actions.close()
                    vim.schedule(function()
                        edit_macro(reg, "", caller_win, caller_buf, opts)
                    end)
                end,
            },
        }, opts or {})
    )
    picker.items = items
    return picker
end

return M

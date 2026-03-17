local api = vim.api
local util = require "refer.util"

---@class PreviewModule
local M = {}

---@type number|nil Cached preview buffer handle
local preview_buf = nil

---@type number Namespace ID for preview highlight
local preview_ns = api.nvim_create_namespace "refer_preview"

---@type number Monotonically increasing counter; each show()/cleanup() increments it
---so stale async callbacks can self-cancel.
local current_preview_id = 0

---Safely close a uv file descriptor, ignoring errors.
---@param fd integer
local function safe_close(fd)
    vim.uv.fs_close(fd, function() end)
end

---@class PreviewOpts
---@field filename string File path to preview
---@field lnum? number Line number to jump to (1-indexed)
---@field col? number Column number to jump to (1-indexed)
---@field target_win number Window handle to show preview in
---@field max_lines? number Maximum lines to read (default: 1000)

---Show preview in the target window
---@param opts PreviewOpts Preview options
function M.show(opts)
    local filename = opts.filename
    local lnum = opts.lnum or 1
    local col = opts.col or 1
    local target_win = opts.target_win
    local max_lines = opts.max_lines or 1000

    current_preview_id = current_preview_id + 1
    local my_id = current_preview_id

    if not api.nvim_win_is_valid(target_win) then
        return
    end

    -- Fast-path: buffer already loaded in memory — switch synchronously.
    local bufnr = vim.fn.bufnr(filename)
    if bufnr ~= -1 and api.nvim_buf_is_loaded(bufnr) then
        api.nvim_win_call(target_win, function()
            if api.nvim_win_get_buf(target_win) ~= bufnr then
                api.nvim_win_set_buf(target_win, bufnr)
            end
            if lnum and col then
                pcall(api.nvim_win_set_cursor, target_win, { lnum, col - 1 })
                vim.cmd "normal! zz"
                api.nvim_buf_clear_namespace(bufnr, preview_ns, 0, -1)
                local line_len = #api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or 0
                api.nvim_buf_set_extmark(bufnr, preview_ns, lnum - 1, 0, {
                    end_row = lnum - 1,
                    end_col = line_len,
                    hl_group = "Search",
                    priority = 100,
                })
            end
        end)
        return
    end

    -- Ensure the scratch preview buffer exists.
    if not preview_buf or not api.nvim_buf_is_valid(preview_buf) then
        preview_buf = api.nvim_create_buf(false, true)
        vim.bo[preview_buf].bufhidden = "hide"
        vim.bo[preview_buf].buftype = "nofile"
        vim.bo[preview_buf].swapfile = false
    end
    local buf = preview_buf

    local display_name = filename .. " (Preview)"
    pcall(api.nvim_buf_set_name, buf, display_name)

    -- Synchronous binary check — no I/O deferral needed here.
    if util.is_binary(filename) then
        api.nvim_buf_set_lines(buf, 0, -1, false, { "[Binary File - Preview Disabled]" })
        api.nvim_win_set_buf(target_win, buf)
        return
    end

    -- Async file read via vim.uv.
    vim.uv.fs_open(filename, "r", 438, function(err_open, fd)
        if err_open or not fd then
            return
        end

        vim.uv.fs_fstat(fd, function(err_stat, stat)
            if err_stat or not stat then
                safe_close(fd)
                return
            end

            -- Read only as many bytes as needed for max_lines (heuristic: 200 bytes/line).
            local read_size = math.min(stat.size, max_lines * 200)

            vim.uv.fs_read(fd, read_size, 0, function(err_read, data)
                safe_close(fd)

                if err_read or not data then
                    return
                end

                -- Stale-check: a newer show()/cleanup() was called while we were reading.
                if my_id ~= current_preview_id then
                    return
                end

                vim.schedule(function()
                    -- Re-check inside vim.schedule in case picker closed during I/O.
                    if my_id ~= current_preview_id then
                        return
                    end
                    if not api.nvim_buf_is_valid(buf) then
                        return
                    end
                    if not api.nvim_win_is_valid(target_win) then
                        return
                    end

                    -- Split into lines and trim to max_lines.
                    local lines = vim.split(data, "\n", { plain = true })
                    if #lines > max_lines then
                        lines = vim.list_slice(lines, 1, max_lines)
                    end

                    -- Strip embedded CR / newline characters.
                    for i, line in ipairs(lines) do
                        if line:find "[\r\n]" then
                            lines[i] = line:gsub("[\r\n]", " ")
                        end
                    end

                    api.nvim_buf_set_lines(buf, 0, -1, false, lines)

                    local ft = vim.filetype.match { filename = filename }
                    if ft then
                        vim.bo[buf].filetype = ft
                    end

                    api.nvim_win_set_buf(target_win, buf)

                    if lnum and col then
                        api.nvim_win_call(target_win, function()
                            pcall(api.nvim_win_set_cursor, target_win, { lnum, col - 1 })
                            vim.cmd "normal! zz"
                            api.nvim_buf_clear_namespace(buf, preview_ns, 0, -1)
                            local line_len = #api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or 0
                            api.nvim_buf_set_extmark(buf, preview_ns, lnum - 1, 0, {
                                end_row = lnum - 1,
                                end_col = line_len,
                                hl_group = "Search",
                                priority = 100,
                            })
                        end)
                    end
                end)
            end)
        end)
    end)
end

---Clean up the preview buffer
function M.cleanup()
    current_preview_id = current_preview_id + 1
    if preview_buf and api.nvim_buf_is_valid(preview_buf) then
        api.nvim_buf_clear_namespace(preview_buf, preview_ns, 0, -1)
        api.nvim_buf_delete(preview_buf, { force = true })
    end
    preview_buf = nil
end

return M

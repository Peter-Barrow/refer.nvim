local preview = require "refer.preview"

describe("refer.preview", function()
    local buf1, buf2, win

    before_each(function()
        buf1 = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "hello world", "second line" })

        buf2 = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "another file", "line two" })

        vim.api.nvim_buf_set_name(buf1, "/tmp/refer_test_preview_1.lua")
        vim.api.nvim_buf_set_name(buf2, "/tmp/refer_test_preview_2.lua")

        win = vim.api.nvim_get_current_win()
    end)

    after_each(function()
        preview.cleanup()
        pcall(vim.api.nvim_buf_delete, buf1, { force = true })
        pcall(vim.api.nvim_buf_delete, buf2, { force = true })
    end)

    local preview_ns = vim.api.nvim_create_namespace "refer_preview"

    it("sets an extmark on an already-loaded buffer", function()
        preview.show { filename = "/tmp/refer_test_preview_1.lua", lnum = 1, col = 1, target_win = win }

        local marks = vim.api.nvim_buf_get_extmarks(buf1, preview_ns, 0, -1, {})
        assert.is_true(#marks > 0)
    end)

    it("clears extmark on already-loaded buffer after cleanup", function()
        preview.show { filename = "/tmp/refer_test_preview_1.lua", lnum = 1, col = 1, target_win = win }

        local marks_before = vim.api.nvim_buf_get_extmarks(buf1, preview_ns, 0, -1, {})
        assert.is_true(#marks_before > 0)

        preview.cleanup()

        local marks_after = vim.api.nvim_buf_get_extmarks(buf1, preview_ns, 0, -1, {})
        assert.are.same(0, #marks_after)
    end)

    it("clears extmark from previous buffer when switching to another loaded buffer", function()
        preview.show { filename = "/tmp/refer_test_preview_1.lua", lnum = 1, col = 1, target_win = win }
        preview.show { filename = "/tmp/refer_test_preview_2.lua", lnum = 1, col = 1, target_win = win }

        local marks_buf1 = vim.api.nvim_buf_get_extmarks(buf1, preview_ns, 0, -1, {})
        assert.are.same(0, #marks_buf1)

        local marks_buf2 = vim.api.nvim_buf_get_extmarks(buf2, preview_ns, 0, -1, {})
        assert.is_true(#marks_buf2 > 0)

        preview.cleanup()
        marks_buf2 = vim.api.nvim_buf_get_extmarks(buf2, preview_ns, 0, -1, {})
        assert.are.same(0, #marks_buf2)
    end)

    it("does not error when lnum is beyond the buffer line count (loaded buffer)", function()
        assert.has_no.errors(function()
            preview.show { filename = "/tmp/refer_test_preview_1.lua", lnum = 999, col = 1, target_win = win }
        end)

        local marks = vim.api.nvim_buf_get_extmarks(buf1, preview_ns, 0, -1, {})
        assert.are.same(0, #marks)
    end)

    it("does not error when lnum is 0 or negative (loaded buffer)", function()
        assert.has_no.errors(function()
            preview.show { filename = "/tmp/refer_test_preview_1.lua", lnum = 0, col = 1, target_win = win }
        end)

        local marks = vim.api.nvim_buf_get_extmarks(buf1, preview_ns, 0, -1, {})
        assert.are.same(0, #marks)
    end)

    it("still highlights a valid line in range normally", function()
        preview.show { filename = "/tmp/refer_test_preview_1.lua", lnum = 2, col = 1, target_win = win }

        local marks = vim.api.nvim_buf_get_extmarks(buf1, preview_ns, 0, -1, {})
        assert.is_true(#marks > 0)
        assert.are.same(1, marks[1][2])
    end)
end)

describe("refer.preview async (file-read) path", function()
    local tmpfile = "/tmp/refer_test_preview_async.txt"
    local win

    before_each(function()
        local fd = io.open(tmpfile, "w")
        fd:write "line one\nline two\nline three\n"
        fd:close()

        win = vim.api.nvim_get_current_win()
    end)

    after_each(function()
        preview.cleanup()
        os.remove(tmpfile)
    end)

    local preview_ns = vim.api.nvim_create_namespace "refer_preview"

    it("does not error when lnum exceeds file line count (async path)", function()
        assert.has_no.errors(function()
            preview.show { filename = tmpfile, lnum = 9999, col = 1, target_win = win }
        end)

        vim.wait(500, function()
            return vim.api.nvim_win_get_buf(win) ~= 0
        end)

        local preview_buf = vim.api.nvim_win_get_buf(win)
        local marks = vim.api.nvim_buf_get_extmarks(preview_buf, preview_ns, 0, -1, {})
        assert.are.same(0, #marks)
    end)

    it("does not error when lnum exceeds max_lines truncation (async path)", function()
        assert.has_no.errors(function()
            preview.show { filename = tmpfile, lnum = 3, col = 1, target_win = win, max_lines = 2 }
        end)

        vim.wait(500, function()
            return vim.api.nvim_win_get_buf(win) ~= 0
        end)

        local preview_buf = vim.api.nvim_win_get_buf(win)
        local marks = vim.api.nvim_buf_get_extmarks(preview_buf, preview_ns, 0, -1, {})
        assert.are.same(0, #marks)
    end)

    it("highlights a valid line within the async preview buffer", function()
        preview.show { filename = tmpfile, lnum = 2, col = 1, target_win = win }

        vim.wait(500, function()
            local buf = vim.api.nvim_win_get_buf(win)
            local marks = vim.api.nvim_buf_get_extmarks(buf, preview_ns, 0, -1, {})
            return #marks > 0
        end)

        local preview_buf = vim.api.nvim_win_get_buf(win)
        local marks = vim.api.nvim_buf_get_extmarks(preview_buf, preview_ns, 0, -1, {})
        assert.is_true(#marks > 0)
        assert.are.same(1, marks[1][2])
    end)
end)

describe("refer.preview file not found", function()
    local nonexistent_file = "/tmp/refer_nonexistent_file_12345.txt"
    local win

    before_each(function()
        os.remove(nonexistent_file)
        win = vim.api.nvim_get_current_win()
    end)

    after_each(function()
        preview.cleanup()
    end)

    it("does not error when file does not exist", function()
        assert.has_no.errors(function()
            preview.show { filename = nonexistent_file, lnum = 1, col = 1, target_win = win }
        end)
    end)

    it("shows 'File Not Found' message in preview buffer", function()
        preview.show { filename = nonexistent_file, lnum = 1, col = 1, target_win = win }

        vim.wait(100, function()
            return vim.api.nvim_win_get_buf(win) ~= 0
        end)

        local preview_buf = vim.api.nvim_win_get_buf(win)
        local lines = vim.api.nvim_buf_get_lines(preview_buf, 0, -1, false)
        assert.is_true(#lines > 0)
        assert.is_not_nil(lines[1]:find "%[File Not Found%]")
        assert.is_not_nil(lines[1]:find(nonexistent_file, 1, true))
    end)
end)

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
end)

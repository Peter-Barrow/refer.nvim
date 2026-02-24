local builtin = require "refer.providers.builtin"

describe("builtin.commands preview", function()
    local picker
    local buf

    before_each(function()
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(0, buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "foo", "foo", "foo" })
    end)

    after_each(function()
        if picker then
            picker:close()
        end
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end)

    it("applies substitute preview on change", function()
        picker = builtin.commands()
        picker.opts.on_change("%s/foo/bar/g", function() end)

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.same({ "bar", "bar", "bar" }, lines)
    end)

    it("works with range prefix", function()
        picker = builtin.commands()
        picker.opts.on_change("1,2s/foo/bar/g", function() end)

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.same({ "bar", "bar", "foo" }, lines)
    end)

    it("undoes preview on close", function()
        picker = builtin.commands()
        picker.opts.on_change("1,2s/foo/bar/g", function() end)

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.same({ "bar", "bar", "foo" }, lines)

        picker:close()

        lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.same({ "foo", "foo", "foo" }, lines)
    end)

    it("applies substitute preview for cdo s/foo/bar/g", function()
        picker = builtin.commands()
        picker.opts.on_change("cdo s/foo/bar/g", function() end)

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.are.same({ "bar", "bar", "bar" }, lines)
    end)
end)

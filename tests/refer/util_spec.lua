local util = require "refer.util"
local stub = require "luassert.stub"

describe("refer.util", function()
    describe("parse_selection", function()
        it("parses buffer format", function()
            local input = "1: src/main.lua:10:5"
            local expected = {
                bufnr = 1,
                filename = "src/main.lua",
                lnum = 10,
                col = 5,
            }
            assert.are.same(expected, util.parse_selection(input, "buffer"))
        end)

        it("parses grep format", function()
            local input = "src/main.lua:10:5:local x = 1"
            local expected = {
                filename = "src/main.lua",
                lnum = 10,
                col = 5,
                content = "local x = 1",
            }
            assert.are.same(expected, util.parsers.grep(input))
        end)

        it("parses grep format fallback (no column)", function()
            local input = "src/main.lua:10:local x = 1"
            local expected = {
                filename = "src/main.lua",
                lnum = 10,
                col = 1,
                content = "local x = 1",
            }
            assert.are.same(expected, util.parsers.grep(input))
        end)

        it("parses lsp format", function()
            local input = "src/main.lua:10:5"
            local expected = {
                filename = "src/main.lua",
                lnum = 10,
                col = 5,
            }
            assert.are.same(expected, util.parse_selection(input, "lsp"))
        end)

        it("parses simple file format", function()
            local input = "src/main.lua"
            local expected = {
                filename = "src/main.lua",
                lnum = 1,
                col = 1,
            }
            assert.are.same(expected, util.parse_selection(input, "file"))
        end)

        it("returns nil for invalid format", function()
            assert.is_nil(util.parse_selection("invalid", "buffer"))
        end)
    end)

    describe("complete_line", function()
        it("completes simple prefix", function()
            assert.are.same("test", util.complete_line("te", "test"))
        end)

        it("replaces after separator", function()
            assert.are.same("path/to/file", util.complete_line("path/to/fi", "file"))
        end)

        it("handles spaces as separators", function()
            assert.are.same("command argument", util.complete_line("command arg", "argument"))
        end)

        it("handles overlapping path components correctly", function()
            assert.are.same(":e lua/custom/", util.complete_line(":e lua/", "lua/custom/"))
        end)

        it("handles partial overlapping path components", function()
            assert.are.same(":e lua/custom/", util.complete_line(":e lua", "lua/custom/"))
        end)

        it("handles simple overlapping strings", function()
            assert.are.same("abcde", util.complete_line("abc", "abcde"))
        end)

        it("handles no overlap correctly", function()
            assert.are.same(":e lua/", util.complete_line(":e ", "lua/"))
        end)

        it("handles standard fallback when no overlap", function()
            assert.are.same("folder/edit", util.complete_line("folder/file", "edit"))
            assert.are.same("foo.baz", util.complete_line("foo.bar", "baz"))
        end)
    end)

    describe("get_relative_path", function()
        it("strips cwd from path", function()
            local abs = "/home/user/project/src/main.lua"
            local s = stub(vim.fn, "fnamemodify", "src/main.lua")

            assert.are.same("src/main.lua", util.get_relative_path(abs))
            assert.stub(s).was.called_with(abs, ":.")
            s:revert()
        end)

        it("leaves outside paths alone", function()
            local abs = "/etc/hosts"
            local s = stub(vim.fn, "fnamemodify", "/etc/hosts")

            assert.are.same("/etc/hosts", util.get_relative_path(abs))
            assert.stub(s).was.called_with(abs, ":.")
            s:revert()
        end)
    end)

    describe("is_binary", function()
        local tmpdir = vim.fn.tempname()

        before_each(function()
            vim.fn.mkdir(tmpdir, "p")
        end)

        after_each(function()
            vim.fn.delete(tmpdir, "rf")
        end)

        it("returns true for file containing null bytes", function()
            local path = tmpdir .. "/binary.bin"
            local f = io.open(path, "wb")
            f:write("hello\0world")
            f:close()
            assert.is_true(util.is_binary(path))
        end)

        it("returns false for plain text file", function()
            local path = tmpdir .. "/text.txt"
            local f = io.open(path, "w")
            f:write("hello world\nline two\n")
            f:close()
            assert.is_false(util.is_binary(path))
        end)

        it("returns false for non-existent file", function()
            assert.is_false(util.is_binary(tmpdir .. "/nonexistent.txt"))
        end)
    end)

    describe("get_line_content", function()
        local tmpdir = vim.fn.tempname()

        before_each(function()
            vim.fn.mkdir(tmpdir, "p")
        end)

        after_each(function()
            vim.fn.delete(tmpdir, "rf")
        end)

        it("returns the correct line from a file on disk", function()
            local path = tmpdir .. "/lines.txt"
            local f = io.open(path, "w")
            f:write("line one\nline two\nline three\n")
            f:close()
            assert.are.same("line two", util.get_line_content(path, 2))
        end)

        it("returns empty string for non-existent file", function()
            assert.are.same("", util.get_line_content(tmpdir .. "/nope.txt", 1))
        end)

        it("returns empty string for out-of-range line number", function()
            local path = tmpdir .. "/short.txt"
            local f = io.open(path, "w")
            f:write("only one line\n")
            f:close()
            assert.are.same("", util.get_line_content(path, 99))
        end)

        it("returns line from a loaded buffer", function()
            local path = tmpdir .. "/buf.txt"
            local f = io.open(path, "w")
            f:write("disk content\n")
            f:close()

            vim.cmd("edit " .. vim.fn.fnameescape(path))
            local bufnr = vim.fn.bufnr(path)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "buffer content" })

            assert.are.same("buffer content", util.get_line_content(path, 1))

            vim.cmd("bwipeout! " .. bufnr)
        end)
    end)

    describe("parsers.lsp", function()
        it("parses filename:lnum:col:content format", function()
            local result = util.parsers.lsp("src/init.lua:10:5:some content")
            assert.are.same({
                filename = "src/init.lua",
                lnum = 10,
                col = 5,
                content = "some content",
            }, result)
        end)

        it("parses filename:lnum:col format without content", function()
            local result = util.parsers.lsp("src/init.lua:10:5")
            assert.are.same({
                filename = "src/init.lua",
                lnum = 10,
                col = 5,
            }, result)
        end)
    end)

    describe("parsers.buffer", function()
        it("parses bufnr: filename:lnum:col format", function()
            local result = util.parsers.buffer("5: src/main.lua:20:3")
            assert.are.same({
                bufnr = 5,
                filename = "src/main.lua",
                lnum = 20,
                col = 3,
            }, result)
        end)

        it("returns nil for non-matching input", function()
            assert.is_nil(util.parsers.buffer("not a buffer line"))
        end)
    end)

    describe("parse_selection edge cases", function()
        it("returns nil for empty string", function()
            assert.is_nil(util.parse_selection("", "file"))
        end)

        it("returns nil for nil input", function()
            assert.is_nil(util.parse_selection(nil, "file"))
        end)

        it("returns nil for unknown format", function()
            assert.is_nil(util.parse_selection("something", "unknown_format"))
        end)
    end)
end)

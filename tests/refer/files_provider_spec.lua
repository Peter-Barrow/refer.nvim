local files = require "refer.providers.files"

describe("refer.providers.files", function()
    describe("_escape_fd_regex", function()
        it("passes through plain alphanumeric strings", function()
            assert.are.same("init", files._escape_fd_regex "init")
            assert.are.same("fooBar123", files._escape_fd_regex "fooBar123")
        end)

        it("passes through dashes and underscores", function()
            assert.are.same("foo-bar_baz", files._escape_fd_regex "foo-bar_baz")
        end)

        it("escapes dots", function()
            assert.are.same("init\\.lua", files._escape_fd_regex "init.lua")
        end)

        it("escapes plus", function()
            assert.are.same("foo\\+bar", files._escape_fd_regex "foo+bar")
        end)

        it("escapes asterisk", function()
            assert.are.same("test\\*", files._escape_fd_regex "test*")
        end)

        it("escapes question mark", function()
            assert.are.same("file\\?", files._escape_fd_regex "file?")
        end)

        it("escapes square brackets", function()
            assert.are.same("a\\[0\\]", files._escape_fd_regex "a[0]")
        end)

        it("escapes parentheses", function()
            assert.are.same("fn\\(x\\)", files._escape_fd_regex "fn(x)")
        end)

        it("escapes curly braces", function()
            assert.are.same("a\\{1\\}", files._escape_fd_regex "a{1}")
        end)

        it("escapes pipe", function()
            assert.are.same("a\\|b", files._escape_fd_regex "a|b")
        end)

        it("escapes caret and dollar", function()
            assert.are.same("\\^start", files._escape_fd_regex "^start")
            assert.are.same("end\\$", files._escape_fd_regex "end$")
        end)

        it("escapes backslash", function()
            assert.are.same("path\\\\to", files._escape_fd_regex "path\\to")
        end)

        it("escapes multiple special chars in one string", function()
            assert.are.same("foo\\.bar\\+baz\\*", files._escape_fd_regex "foo.bar+baz*")
        end)

        it("returns empty string for empty input", function()
            assert.are.same("", files._escape_fd_regex "")
        end)
    end)

    describe("_build_path_regex", function()
        it("builds regex for two segments", function()
            assert.are.same("prov[^/]*/.*files", files._build_path_regex "prov/files")
        end)

        it("builds regex for three segments", function()
            assert.are.same("lua[^/]*/.*ref[^/]*/.*init", files._build_path_regex "lua/ref/init")
        end)

        it("handles trailing slash", function()
            assert.are.same("providers", files._build_path_regex "providers/")
        end)

        it("handles leading slash", function()
            assert.are.same("providers[^/]*/.*files", files._build_path_regex "/providers/files")
        end)

        it("handles double slashes", function()
            assert.are.same("foo[^/]*/.*[^/]*/.*bar", files._build_path_regex "foo//bar")
        end)

        it("escapes dots in segments", function()
            assert.are.same("ref[^/]*/.*init\\.lua", files._build_path_regex "ref/init.lua")
        end)

        it("escapes special chars in each segment independently", function()
            assert.are.same("src\\.main[^/]*/.*test\\+spec\\.lua", files._build_path_regex "src.main/test+spec.lua")
        end)

        it("handles single segment (no joining)", function()
            assert.are.same("foo", files._build_path_regex "foo")
        end)

        it("handles many segments", function()
            assert.are.same("a[^/]*/.*b[^/]*/.*c[^/]*/.*d", files._build_path_regex "a/b/c/d")
        end)
    end)
end)

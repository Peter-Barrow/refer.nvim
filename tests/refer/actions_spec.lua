local refer = require "refer"
local Picker = require "refer.picker"
local stub = require "luassert.stub"

local util = require "refer.util"

describe("refer.actions", function()
    local picker

    before_each(function()
        picker = refer.pick({}, function() end)
    end)

    after_each(function()
        if picker then
            picker:close()
        end
    end)

    it("toggle_mark marks the current item and advances", function()
        picker.current_matches = { "item1", "item2" }
        picker.selected_index = 1

        picker.actions.toggle_mark()

        assert.is_true(picker.marked["item1"])
        assert.are.same(2, picker.selected_index)

        picker.selected_index = 1
        picker.actions.toggle_mark()
        assert.is_false(picker.marked["item1"])
    end)

    describe("reversed results navigation", function()
        before_each(function()
            picker.opts.ui = { reverse_result = true }
            picker.current_matches = { "A", "B", "C" }
        end)

        it("prev_item (Up) increments index (moves visually up)", function()
            picker.selected_index = 1

            picker.actions.prev_item()

            assert.are.equal(2, picker.selected_index)

            picker.actions.prev_item()

            assert.are.equal(3, picker.selected_index)
        end)

        it("next_item (Down) decrements index (moves visually down)", function()
            picker.selected_index = 3

            picker.actions.next_item()

            assert.are.equal(2, picker.selected_index)

            picker.actions.next_item()

            assert.are.equal(1, picker.selected_index)
        end)

        it("handles wrapping correctly in reverse", function()
            picker.selected_index = 3
            picker.actions.prev_item()
            assert.are.equal(1, picker.selected_index)

            picker.selected_index = 1
            picker.actions.next_item()
            assert.are.equal(3, picker.selected_index)
        end)
    end)

    describe("send_to_qf", function()
        before_each(function()
            stub(vim.fn, "setqflist")
            stub(vim.cmd, "copen")
        end)

        after_each(function()
            vim.fn.setqflist:revert()
            vim.cmd.copen:revert()
        end)

        it("sends marked items to quickfix", function()
            picker.marked = { ["file1:1:1"] = true, ["file2:2:2"] = true }
            picker.current_matches = { "file1:1:1", "file2:2:2", "file3:3:3" }

            picker.actions.send_to_qf()

            assert.stub(vim.fn.setqflist).was_called()
            local call = vim.fn.setqflist.calls[1]
            local what = call.refs[3]

            assert.are.same("Refer Selection", what.title)
            assert.are.same(2, #what.items)
        end)

        it("sends current selection if nothing marked", function()
            picker.marked = {}
            picker.current_matches = { "file1" }
            picker.selected_index = 1

            picker.actions.send_to_qf()

            local call = vim.fn.setqflist.calls[1]
            local what = call.refs[3]
            assert.are.same(1, #what.items)
            assert.are.same("file1", what.items[1].text)
        end)
        it("sends parsed items correctly (LSP format)", function()
            picker.marked = {}
            picker.current_matches = { "src/main.lua:10:5: content" }
            picker.selected_index = 1
            picker.parser = util.parsers.lsp

            picker.actions.send_to_qf()

            local call = vim.fn.setqflist.calls[1]
            local what = call.refs[3]
            local item = what.items[1]

            assert.are.same("src/main.lua", item.filename)
            assert.are.same(10, item.lnum)
            assert.are.same(5, item.col)
            assert.are.same(" content", item.text)
        end)

        it("sends parsed items correctly (grep format no space)", function()
            picker.marked = {}
            picker.current_matches = { "src/main.lua:10:5:content" }
            picker.selected_index = 1
            picker.parser = util.parsers.grep

            picker.actions.send_to_qf()

            local call = vim.fn.setqflist.calls[1]
            local what = call.refs[3]
            local item = what.items[1]

            assert.are.same("src/main.lua", item.filename)
            assert.are.same(10, item.lnum)
            assert.are.same(5, item.col)
            assert.are.same("content", item.text)
        end)

        it("sends parsed items correctly (LSP format no space)", function()
            picker.marked = {}
            picker.current_matches = { "src/main.lua:10:5:content" }
            picker.selected_index = 1
            picker.parser = util.parsers.lsp

            picker.actions.send_to_qf()

            local call = vim.fn.setqflist.calls[1]
            local what = call.refs[3]
            local item = what.items[1]

            assert.are.same("src/main.lua", item.filename)
            assert.are.same(10, item.lnum)
            assert.are.same(5, item.col)
            assert.are.same("content", item.text)
        end)
    end)

    describe("select_input", function()
        it("calls on_select with raw input", function()
            local selected
            picker.on_select = function(sel)
                selected = sel
            end

            vim.api.nvim_buf_set_lines(picker.input_buf, 0, -1, false, { "custom input" })

            picker.actions.select_input()

            assert.are.same("custom input", selected)
        end)
    end)

    describe("complete_selection", function()
        it("completes input with the selected match", function()
            picker.current_matches = { "apple", "apricot" }
            picker.selected_index = 1

            vim.api.nvim_buf_set_lines(picker.input_buf, 0, -1, false, { "ap" })
            vim.api.nvim_set_current_win(picker.ui.input_win)

            picker.actions.complete_selection()

            local line = vim.api.nvim_buf_get_lines(picker.input_buf, 0, 1, false)[1]
            assert.are.same("apple", line)
        end)

        it("does nothing when no matches exist", function()
            picker.current_matches = {}
            picker.selected_index = 1

            vim.api.nvim_buf_set_lines(picker.input_buf, 0, -1, false, { "test" })
            vim.api.nvim_set_current_win(picker.ui.input_win)

            picker.actions.complete_selection()

            local line = vim.api.nvim_buf_get_lines(picker.input_buf, 0, 1, false)[1]
            assert.are.same("test", line)
        end)
    end)

    describe("select_entry", function()
        it("calls on_select with selection and parsed data", function()
            local selected_val, selected_data
            picker.on_select = function(sel, data)
                selected_val = sel
                selected_data = data
            end
            picker.parser = util.parsers.file
            picker.current_matches = { "src/main.lua" }
            picker.selected_index = 1

            picker.actions.select_entry()

            assert.are.same("src/main.lua", selected_val)
            assert.are.same("src/main.lua", selected_data.filename)
        end)

        it("does nothing when no matches exist", function()
            local called = false
            picker.on_select = function()
                called = true
            end
            picker.current_matches = {}
            picker.selected_index = 1

            picker.actions.select_entry()
            assert.is_false(called)
        end)
    end)

    describe("close", function()
        it("closes the picker", function()
            assert.is_true(vim.api.nvim_win_is_valid(picker.ui.input_win))

            picker.actions.close()

            assert.is_false(vim.api.nvim_win_is_valid(picker.ui.input_win))
            picker = nil
        end)
    end)

    describe("cycle_sorter", function()
        it("cycles through available sorters", function()
            picker.available_sorters = { "lua", "native" }
            picker.sorter_idx = 1

            picker.actions.cycle_sorter()

            assert.are.same(2, picker.sorter_idx)
            assert.is_not_nil(picker.custom_sorter)
        end)

        it("wraps around to the first sorter", function()
            picker.available_sorters = { "lua", "native" }
            picker.sorter_idx = 2

            picker.actions.cycle_sorter()

            assert.are.same(1, picker.sorter_idx)
        end)
    end)

    describe("send_to_qf edge cases", function()
        before_each(function()
            stub(vim.fn, "setqflist")
            stub(vim.cmd, "copen")
        end)

        after_each(function()
            vim.fn.setqflist:revert()
            vim.cmd.copen:revert()
        end)

        it("does nothing when no matches and no marks", function()
            picker.marked = {}
            picker.current_matches = {}
            picker.selected_index = 1

            picker.actions.send_to_qf()

            assert.stub(vim.fn.setqflist).was_not_called()
        end)
    end)
end)

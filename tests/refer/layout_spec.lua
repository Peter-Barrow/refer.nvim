local refer = require "refer"
local api = vim.api

describe("refer layout", function()
    local picker

    after_each(function()
        if picker then
            picker:close()
            picker = nil
        end
    end)

    it("places input above results by default (top)", function()
        picker = refer.pick({ "item" }, function() end, {
            ui = { input_position = "top" },
        })

        vim.wait(500, function()
            return picker.ui.input_win and picker.ui.results_win
        end)

        local input_pos = api.nvim_win_get_position(picker.ui.input_win)
        local results_pos = api.nvim_win_get_position(picker.ui.results_win)

        assert.is_true(input_pos[1] < results_pos[1], "Expected input above results (top)")

        assert.are.equal(picker.ui.input_win, api.nvim_get_current_win(), "Input window should be focused")
    end)

    it("places input below results when configured (bottom)", function()
        picker = refer.pick({ "item" }, function() end, {
            ui = { input_position = "bottom" },
        })

        vim.wait(500, function()
            return picker.ui.input_win and picker.ui.results_win
        end)

        local input_pos = api.nvim_win_get_position(picker.ui.input_win)
        local results_pos = api.nvim_win_get_position(picker.ui.results_win)

        assert.is_true(input_pos[1] > results_pos[1], "Expected input below results (bottom)")

        assert.are.equal(picker.ui.input_win, api.nvim_get_current_win(), "Input window should be focused")
    end)

    it("reverses results when configured", function()
        local items = { "A", "B", "C" }
        picker = refer.pick(items, function() end, {
            ui = { reverse_result = true },
            max_height = 10,
        })

        vim.wait(1000, function()
            if not picker.ui.results_buf then
                return false
            end
            local lines = api.nvim_buf_get_lines(picker.ui.results_buf, 0, -1, false)
            return #lines == 3
        end)

        local lines = api.nvim_buf_get_lines(picker.ui.results_buf, 0, -1, false)
        assert.are.same({ "C", "B", "A" }, lines, "Expected results to be reversed in buffer")

        -- Check initial cursor position (Item 'A' is index 1)
        -- In reversed view:
        -- 1: C (Index 3)
        -- 2: B (Index 2)
        -- 3: A (Index 1) <- Cursor should be here
        local cursor = api.nvim_win_get_cursor(picker.ui.results_win)
        assert.are.equal(3, cursor[1], "Cursor should be on the last line for the first item")

        picker.actions.prev_item()

        cursor = api.nvim_win_get_cursor(picker.ui.results_win)
        assert.are.equal(2, cursor[1], "Cursor should move up to the second line for the second item")
    end)

    it("partial redraw keeps unchanged head lines when count shrinks", function()
        local items = { "line1", "line2", "line3", "line4", "line5" }
        picker = refer.pick(items, function() end, { max_height = 10 })

        vim.wait(1000, function()
            if not picker.ui.results_buf then
                return false
            end
            local lines = api.nvim_buf_get_lines(picker.ui.results_buf, 0, -1, false)
            return #lines == 5
        end)

        picker.ui:render({ "line1", "line2", "CHANGED" }, 1, nil)

        local lines = api.nvim_buf_get_lines(picker.ui.results_buf, 0, -1, false)
        assert.are.equal(3, #lines, "Buffer should have 3 lines after shrink")
        assert.are.equal("line1", lines[1], "First unchanged line preserved")
        assert.are.equal("line2", lines[2], "Second unchanged line preserved")
        assert.are.equal("CHANGED", lines[3], "Changed tail line correct")
    end)

    it("partial redraw appends new lines when count grows", function()
        local items = { "alpha", "beta", "gamma" }
        picker = refer.pick(items, function() end, { max_height = 10 })

        vim.wait(1000, function()
            if not picker.ui.results_buf then
                return false
            end
            local lines = api.nvim_buf_get_lines(picker.ui.results_buf, 0, -1, false)
            return #lines == 3
        end)

        picker.ui:render({ "alpha", "beta", "gamma", "delta", "epsilon" }, 1, nil)

        local lines = api.nvim_buf_get_lines(picker.ui.results_buf, 0, -1, false)
        assert.are.equal(5, #lines, "Buffer should have 5 lines after grow")
        assert.are.equal("alpha", lines[1], "First line unchanged")
        assert.are.equal("beta", lines[2], "Second line unchanged")
        assert.are.equal("gamma", lines[3], "Third line unchanged")
        assert.are.equal("delta", lines[4], "New fourth line appended")
        assert.are.equal("epsilon", lines[5], "New fifth line appended")
    end)

    it("full rewrite occurs when first line changes (count same)", function()
        local items = { "A", "B", "C" }
        picker = refer.pick(items, function() end, { max_height = 10 })

        vim.wait(1000, function()
            if not picker.ui.results_buf then
                return false
            end
            local lines = api.nvim_buf_get_lines(picker.ui.results_buf, 0, -1, false)
            return #lines == 3
        end)

        picker.ui:render({ "X", "B", "C" }, 1, nil)

        local lines = api.nvim_buf_get_lines(picker.ui.results_buf, 0, -1, false)
        assert.are.equal(3, #lines, "Line count unchanged")
        assert.are.equal("X", lines[1], "First line updated")
        assert.are.equal("B", lines[2], "Second line unchanged")
        assert.are.equal("C", lines[3], "Third line unchanged")
    end)
end)

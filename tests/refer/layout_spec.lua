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
end)

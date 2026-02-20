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
end)

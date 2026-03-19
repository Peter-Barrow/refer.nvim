local refer = require "refer"

describe("refer UI input cursor preservation", function()
    local picker

    after_each(function()
        if picker then
            picker:close()
            picker = nil
        end
        vim.cmd "stopinsert"
    end)

    local function enter_insert_with_text(p, text, col)
        vim.api.nvim_set_current_win(p.ui.input_win)
        vim.api.nvim_buf_set_lines(p.input_buf, 0, -1, false, { text })
        vim.cmd "startinsert"
        vim.api.nvim_win_set_cursor(p.ui.input_win, { 1, col })
    end

    it("render() does not move input cursor while in insert mode", function()
        picker = refer.pick({ "alpha", "beta", "gamma" }, {})
        picker.current_matches = { "alpha", "beta", "gamma" }
        picker.selected_index = 1

        enter_insert_with_text(picker, "foo", 3)

        picker.ui:render(picker.current_matches, picker.selected_index, picker.marked)

        local col = vim.api.nvim_win_get_cursor(picker.ui.input_win)[2]
        assert.are.same(3, col)
    end)

    it("navigate(1) does not move input cursor while in insert mode", function()
        picker = refer.pick({ "alpha", "beta", "gamma" }, {})
        picker.current_matches = { "alpha", "beta", "gamma" }
        picker.selected_index = 1
        picker.ui:render(picker.current_matches, picker.selected_index, picker.marked)

        enter_insert_with_text(picker, "foo", 3)

        picker:navigate(1)

        local col = vim.api.nvim_win_get_cursor(picker.ui.input_win)[2]
        assert.are.same(3, col)
    end)

    it("navigate(-1) does not move input cursor while in insert mode", function()
        picker = refer.pick({ "alpha", "beta", "gamma" }, {})
        picker.current_matches = { "alpha", "beta", "gamma" }
        picker.selected_index = 2
        picker.ui:render(picker.current_matches, picker.selected_index, picker.marked)

        enter_insert_with_text(picker, "bar", 3)

        picker:navigate(-1)

        local col = vim.api.nvim_win_get_cursor(picker.ui.input_win)[2]
        assert.are.same(3, col)
    end)

    it("repeated render() calls do not drift input cursor", function()
        picker = refer.pick({ "alpha", "beta", "gamma" }, {})
        picker.current_matches = { "alpha", "beta", "gamma" }
        picker.selected_index = 1

        enter_insert_with_text(picker, "hello", 5)

        for _ = 1, 5 do
            picker.ui:render(picker.current_matches, picker.selected_index, picker.marked)
        end

        local col = vim.api.nvim_win_get_cursor(picker.ui.input_win)[2]
        assert.are.same(5, col)
    end)

    it("render() with count change does not move input cursor", function()
        picker = refer.pick({ "alpha", "beta", "gamma" }, {})
        picker.current_matches = { "alpha", "beta", "gamma" }
        picker.selected_index = 1
        picker.ui:render(picker.current_matches, picker.selected_index, picker.marked)

        enter_insert_with_text(picker, "foo", 3)

        picker.ui:render({ "alpha", "beta" }, 1, nil)

        local col = vim.api.nvim_win_get_cursor(picker.ui.input_win)[2]
        assert.are.same(3, col, "Input cursor col should be preserved through count-change render")
    end)

    it("render() with count change places results cursor on selected row", function()
        picker = refer.pick({ "alpha", "beta", "gamma", "delta", "epsilon" }, {})

        vim.wait(1000, function()
            if not picker.ui.results_buf then
                return false
            end
            local lines = vim.api.nvim_buf_get_lines(picker.ui.results_buf, 0, -1, false)
            return #lines == 5
        end)

        picker.ui:render({ "alpha", "beta", "gamma" }, 2, nil)

        local cursor = vim.api.nvim_win_get_cursor(picker.ui.results_win)
        assert.are.equal(2, cursor[1], "Results cursor should be on row 2 after count-change render")
    end)
end)

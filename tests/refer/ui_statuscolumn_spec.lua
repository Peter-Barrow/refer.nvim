local refer = require "refer"

describe("refer UI mark visibility under custom statuscolumn", function()
    local picker
    local saved_statuscolumn

    before_each(function()
        saved_statuscolumn = vim.wo.statuscolumn
    end)

    after_each(function()
        if picker then
            picker:close()
            picker = nil
        end
        vim.cmd "stopinsert"
        if saved_statuscolumn ~= nil then
            vim.wo.statuscolumn = saved_statuscolumn
        end
    end)

    it("results window clears inherited custom statuscolumn", function()
        vim.wo.statuscolumn = "%l "

        picker = refer.pick({ "alpha", "beta", "gamma" }, {})

        local sc = vim.wo[picker.ui.results_win].statuscolumn
        assert.are.same("", sc, "results window should have empty statuscolumn")

        local input_sc = vim.wo[picker.ui.input_win].statuscolumn
        assert.are.same("", input_sc, "input window should have empty statuscolumn")
    end)

    it("mark sign is placed after toggle_mark even when global statuscolumn is custom", function()
        vim.wo.statuscolumn = "%l "

        picker = refer.pick({ "alpha", "beta", "gamma" }, {})
        picker.current_matches = { "alpha", "beta", "gamma" }
        picker.selected_index = 1

        picker.ui:render(picker.current_matches, picker.selected_index, picker.marked)

        picker.actions.toggle_mark(picker)

        local marks =
            vim.api.nvim_buf_get_extmarks(picker.ui.results_buf, picker.ui.ns_marks, 0, -1, { details = true })

        assert.is_true(#marks > 0, "at least one mark extmark should exist after toggle_mark")
        local extmark = marks[1]
        assert.is_not_nil(extmark[4].sign_text, "mark extmark should have sign_text")
    end)

    it("signcolumn remains yes on results window", function()
        vim.wo.statuscolumn = "%l "

        picker = refer.pick({ "alpha", "beta", "gamma" }, {})

        local sc = vim.wo[picker.ui.results_win].signcolumn
        assert.are.same("yes", sc, "results window should have signcolumn=yes")
    end)
end)

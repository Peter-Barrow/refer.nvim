local builtin = require "refer.providers.builtin"
local refer = require "refer"
local stub = require "luassert.stub"

describe("builtin.commands completion", function()
    it("does NOT prepend range prefix when there's a space after it", function()
        -- Mock getcompletion to return subcommands
        local s_getcompletion = stub(vim.fn, "getcompletion")
        s_getcompletion.on_call_with("'<,'>Refer ", "cmdline").returns({"Files", "Selection"})

        local picker = builtin.commands { range = 2, line1 = 1, line2 = 10 }
        
        -- Get the provider function (the first argument to refer.pick)
        local s_pick = stub(refer, "pick")
        builtin.commands({ range = 2, line1 = 1, line2 = 10 })
        
        local provider = s_pick.calls[1].refs[1]
        
        -- Call the provider with an input that has a space after the range
        local matches = provider("'<,'>Refer ")
        
        -- It should NOT contain the prefix prepended to items
        assert.are.same({"Files", "Selection"}, matches)
        
        s_getcompletion:revert()
        s_pick:revert()
    end)

    it("DOES prepend range prefix when there's NO space after it", function()
        -- Mock getcompletion
        local s_getcompletion = stub(vim.fn, "getcompletion")
        s_getcompletion.on_call_with("'<,'>Ref", "cmdline").returns({"Refer"})

        local s_pick = stub(refer, "pick")
        builtin.commands({ range = 2, line1 = 1, line2 = 10 })
        
        local provider = s_pick.calls[1].refs[1]
        
        local matches = provider("'<,'>Ref")
        
        -- It SHOULD contain the prefix prepended to items
        assert.are.same({"'<,'>Refer"}, matches)
        
        s_getcompletion:revert()
        s_pick:revert()
    end)
end)

---@class LSPProvider
local M = {}

local refer = require "refer"
local util = require "refer.util"

---Generic handler for LSP location requests
---@param method string LSP method name (e.g. "textDocument/definition")
---@param label string Label for messages (e.g. "definitions")
---@param title string Picker title (e.g. "LSP Definitions")
---@param opts table User options
---@param param_modifier fun(params: table)|nil Optional function to modify request params
local function lsp_request(method, label, title, opts, param_modifier)
    local clients = vim.lsp.get_clients { bufnr = 0 }
    local client = clients[1]

    if not client then
        vim.notify("Refer: No LSP client attached", vim.log.levels.WARN)
        return
    end

    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    if param_modifier then
        param_modifier(params)
    end

    vim.lsp.buf_request(0, method, params, function(err, result, _, _)
        if err then
            vim.notify("LSP Error: " .. tostring(err), vim.log.levels.ERROR)
            return
        end
        if not result or vim.tbl_isempty(result) then
            vim.notify("Refer: No " .. label .. " found", vim.log.levels.INFO)
            return
        end

        if not vim.islist(result) then
            result = { result }
        end

        local items = {}
        local seen = {}

        for _, loc in ipairs(result) do
            local uri = loc.uri or loc.targetUri
            local range = loc.range or loc.targetSelectionRange or loc.targetRange

            if uri and range then
                local filename = vim.uri_to_fname(uri)
                filename = vim.uv.fs_realpath(filename) or filename
                local lnum = range.start.line + 1
                local col = range.start.character + 1

                local relative_path = util.get_relative_path(filename)
                local line_content = util.get_line_content(filename, lnum)

                local entry = string.format("%s:%d:%d:%s", relative_path, lnum, col, line_content)
                if not seen[entry] then
                    table.insert(items, entry)
                    seen[entry] = true
                end
            end
        end

        if #items == 0 then
            vim.notify("Refer: No " .. label .. " found (after filtering)", vim.log.levels.INFO)
            return
        end

        if #items == 1 then
            util.jump_to_location(items[1], "lsp")
            return
        end

        refer.pick(
            items,
            util.jump_to_location,
            vim.tbl_deep_extend("force", {
                prompt = title .. " > ",
                keymaps = {
                    ["<Tab>"] = "toggle_mark",
                    ["<CR>"] = "select_entry",
                },
                parser = util.parsers.lsp,
            }, opts or {})
        )
    end)
end

---Find references to symbol under cursor using LSP
---Shows filename, line, column, and content for each reference
function M.references(opts)
    lsp_request("textDocument/references", "references", "LSP References", opts, function(params)
        params.context = { includeDeclaration = true }
    end)
end

---Find definitions of symbol under cursor using LSP
---Shows filename, line, column, and content for each definition
function M.definitions(opts)
    lsp_request("textDocument/definition", "definitions", "LSP Definitions", opts)
end

---Find implementations of symbol under cursor using LSP
---Shows filename, line, column, and content for each implementation
function M.implementations(opts)
    lsp_request("textDocument/implementation", "implementations", "LSP Implementations", opts)
end

---Find declarations of symbol under cursor using LSP
---Shows filename, line, column, and content for each declaration
function M.declarations(opts)
    lsp_request("textDocument/declaration", "declarations", "LSP Declarations", opts)
end

---@class LspServerItem
---@field name string
---@field file string|nil
---@field active boolean
---@field config table|nil
---@field registered_config table|nil

---Get all LSP server configurations from active clients, registry, and runtime files
---@return LspServerItem[]
local function get_lsp_configs()
    local config_map = {}

    for _, client in ipairs(vim.lsp.get_clients()) do
        config_map[client.name] = {
            name = client.name,
            active = true,
            config = client.config,
        }
    end

    if vim.lsp.config and vim.lsp._enabled_configs then
        for name, config in pairs(vim.lsp._enabled_configs) do
            if not config_map[name] and name ~= "*" then
                config_map[name] = {
                    name = name,
                    active = false,
                    config = config,
                }
            else
                config_map[name].registered_config = config
            end
        end
    end

    local files = vim.api.nvim_get_runtime_file("after/lsp/*.lua", true)
    vim.list_extend(files, vim.api.nvim_get_runtime_file("lsp/*.lua", true))

    for _, file in ipairs(files) do
        local name = vim.fn.fnamemodify(file, ":t:r")
        if not config_map[name] then
            config_map[name] = {
                name = name,
                active = false,
                file = file,
            }
        else
            config_map[name].file = file
        end
    end

    local configs = {}
    for _, conf in pairs(config_map) do
        table.insert(configs, conf)
    end
    table.sort(configs, function(a, b)
        return a.name < b.name
    end)

    return configs
end

---Show picker for LSP servers with ability to start/stop
---Lists all configured LSP servers and shows which are active
function M.lsp_servers(opts)
    local configs = get_lsp_configs()
    local items = {}
    local lookup = {}

    for _, config in ipairs(configs) do
        local is_active = config.active

        local display_text = (is_active and "● " or "○ ") .. config.name
        table.insert(items, display_text)
        lookup[display_text] = config
    end

    if #items == 0 then
        vim.notify("Refer: No LSP configurations found", vim.log.levels.WARN)
        return
    end

    refer.pick(
        items,
        function(selection, _)
            local item = lookup[selection]
            if not item then
                return
            end

            if item.active then
                local clients = vim.lsp.get_clients { name = item.name }
                for _, client in ipairs(clients) do
                    vim.lsp.stop_client(client.id)
                end
                vim.notify("Stopped LSP: " .. item.name, vim.log.levels.INFO)
            else
                local config = {}

                if item.file then
                    local ok, loaded_config = pcall(dofile, item.file)
                    if ok and type(loaded_config) == "table" then
                        config = loaded_config
                    end
                elseif item.registered_config then
                    config = item.registered_config
                elseif item.config then
                    config = item.config
                end

                config.name = config.name or item.name

                if not config.root_dir then
                    if config.root_markers then
                        config.root_dir = vim.fs.root(0, config.root_markers)
                    end
                    if not config.root_dir then
                        config.root_dir = vim.fn.getcwd()
                    end
                end

                local client_id = vim.lsp.start(config)
                if client_id then
                    vim.notify("Started LSP: " .. item.name, vim.log.levels.INFO)
                else
                    vim.notify("Failed to start LSP: " .. item.name, vim.log.levels.ERROR)
                end
            end
        end,
        vim.tbl_deep_extend("force", {
            prompt = "LSP Servers > ",
            keymaps = {
                ["<S-Tab>"] = "prev_item",
                ["<Tab>"] = "next_item",
                ["<CR>"] = "select_entry",
            },
        }, opts or {})
    )
end

return M

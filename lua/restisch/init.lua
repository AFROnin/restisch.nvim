-- RESTisch - A form-based REST client for Neovim
-- Provides a structured, interactive UI using nui.nvim

local M = {}

-- Plugin version
M.version = "0.1.0"

-- Setup function
function M.setup(opts)
  -- Initialize configuration
  require("restisch.config").setup(opts)

  -- Create user commands
  vim.api.nvim_create_user_command("Restisch", function()
    require("restisch.ui.main").open()
  end, { desc = "Open RESTisch REST client" })

  vim.api.nvim_create_user_command("RestischToggle", function()
    require("restisch.ui.main").toggle()
  end, { desc = "Toggle RESTisch window" })

  vim.api.nvim_create_user_command("RestischClose", function()
    require("restisch.ui.main").close()
  end, { desc = "Close RESTisch window" })

  -- Set default keymaps (can be disabled via config)
  local config = require("restisch.config").get()
  if config.keymaps ~= false then
    vim.keymap.set("n", "<leader>rr", ":Restisch<CR>", {
      desc = "Open RESTisch",
      silent = true,
    })
    vim.keymap.set("n", "<leader>rt", ":RestischToggle<CR>", {
      desc = "Toggle RESTisch",
      silent = true,
    })
  end
end

-- Expose submodules
M.config = require("restisch.config")
M.http = require("restisch.http")
M.storage = require("restisch.storage")
M.ui = {
  main = require("restisch.ui.main"),
  request = require("restisch.ui.request"),
  response = require("restisch.ui.response"),
  dialogs = require("restisch.ui.dialogs"),
}

-- Convenience functions
function M.open()
  require("restisch.ui.main").open()
end

function M.close()
  require("restisch.ui.main").close()
end

function M.toggle()
  require("restisch.ui.main").toggle()
end

-- Quick request function (for scripting)
function M.request(opts, callback)
  require("restisch.http").request(opts, callback or function(response)
    if response.error then
      vim.notify("RESTisch Error: " .. response.error, vim.log.levels.ERROR)
    else
      vim.notify(string.format("RESTisch: %d %s (%.0fms)",
        response.status,
        response.status_text or "",
        response.time_ms or 0
      ), vim.log.levels.INFO)
    end
  end)
end

return M

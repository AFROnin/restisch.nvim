-- RESTisch dialogs module (save/load modals)
local Input = require("nui.input")
local Menu = require("nui.menu")

local M = {}

-- Track open dialogs for cleanup
M.open_dialogs = {}

-- Remove a dialog from tracking
function M.remove_dialog(dialog)
  for i, d in ipairs(M.open_dialogs) do
    if d == dialog then
      table.remove(M.open_dialogs, i)
      break
    end
  end
end

-- Close all open dialogs
function M.close_all()
  for _, dialog in ipairs(M.open_dialogs) do
    pcall(function()
      dialog:unmount()
    end)
  end
  M.open_dialogs = {}
end

-- Show a brief toast notification
local function show_toast(text, hl_group)
  hl_group = hl_group or "RestischSuccess"
  local width = #text + 2
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { " " .. text .. " " })
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = 1,
    row = math.floor(vim.o.lines / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    zindex = 200,
  })
  vim.api.nvim_buf_add_highlight(buf, -1, hl_group, 0, 0, -1)
  vim.api.nvim_set_option_value("winhighlight", "FloatBorder:" .. hl_group, { win = win })
  vim.defer_fn(function()
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end, 1500)
end

-- Show save dialog
function M.save_dialog(request_data, callback)
  local input = Input({
    position = "50%",
    size = {
      width = 50,
    },
    border = {
      style = "rounded",
      text = {
        top = " Save Request ",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:RestischDialogNormal,FloatBorder:RestischDialogBorder",
    },
  }, {
    prompt = "Name: ",
    default_value = "",
    on_submit = function(name)
      if name and name ~= "" then
        local storage = require("restisch.storage")
        local ok, result = storage.save(name, request_data)
        if ok then
          show_toast("Request saved!")
          if callback then
            callback(name)
          end
        else
          show_toast("Failed to save: " .. result, "RestischError")
        end
      end
    end,
  })

  input:mount()
  table.insert(M.open_dialogs, input)

  -- Focus the input
  vim.cmd("startinsert!")

  local function close()
    input:unmount()
    M.remove_dialog(input)
  end

  input:map("n", "<Esc>", close, { noremap = true })
  input:map("i", "<Esc>", function()
    vim.cmd("stopinsert")
    close()
  end, { noremap = true })
  input:map("n", "q", close, { noremap = true })
end

-- Show load dialog
function M.load_dialog(callback)
  local storage = require("restisch.storage")
  local requests = storage.list()

  if #requests == 0 then
    vim.notify("No saved requests found", vim.log.levels.INFO)
    return
  end

  local items = vim.tbl_map(function(req)
    local display = string.format("[%s] %s", req.method, req.name)
    return Menu.item(display, { data = req })
  end, requests)

  local menu = Menu({
    position = "50%",
    size = {
      width = 60,
      height = math.min(#requests + 2, 15),
    },
    border = {
      style = "rounded",
      text = {
        top = " Load Request (d=delete) ",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:RestischDialogNormal,FloatBorder:RestischDialogBorder,CursorLine:Visual",
    },
  }, {
    lines = items,
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "q" },
      submit = { "<CR>" },
    },
    on_submit = function(item)
      if item and item.data then
        local data = storage.load(item.data.name)
        if data then
          show_toast("Loaded: " .. item.data.name)
          if callback then
            callback(data)
          end
        else
          show_toast("Failed to load request", "RestischError")
        end
      end
    end,
  })

  menu:mount()
  table.insert(M.open_dialogs, menu)

  -- Add delete keymap
  menu:map("n", "d", function()
    local tree = menu.tree
    local node = tree:get_node()
    if node and node.data then
      local name = node.data.name
      local confirmed = vim.fn.confirm("Delete '" .. name .. "'?", "&Yes\n&No", 2)
      if confirmed == 1 then
        storage.delete(name)
        show_toast("Deleted: " .. name)
        menu:unmount()
        M.remove_dialog(menu)
        -- Reopen the dialog to refresh
        vim.schedule(function()
          M.load_dialog(callback)
        end)
      end
    end
  end, { noremap = true })

  -- Close with q
  menu:map("n", "q", function()
    menu:unmount()
    M.remove_dialog(menu)
  end, { noremap = true })
end

-- Confirm dialog
function M.confirm(message, on_yes, on_no)
  local items = {
    Menu.item("Yes"),
    Menu.item("No"),
  }

  local menu = Menu({
    position = "50%",
    size = {
      width = math.max(#message + 4, 20),
      height = 4,
    },
    border = {
      style = "rounded",
      text = {
        top = " " .. message .. " ",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:RestischDialogNormal,FloatBorder:RestischBorder,CursorLine:Visual",
    },
  }, {
    lines = items,
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "q" },
      submit = { "<CR>" },
    },
    on_submit = function(item)
      if item.text == "Yes" and on_yes then
        on_yes()
      elseif item.text == "No" and on_no then
        on_no()
      end
    end,
  })

  menu:mount()
end

return M

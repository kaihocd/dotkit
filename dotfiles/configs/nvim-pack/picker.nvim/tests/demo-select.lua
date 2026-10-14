-- Interactive demo; no personal Neovim configuration is loaded.
vim.opt.runtimepath:prepend(vim.env.POPUP_NVIM_PATH)
vim.opt.runtimepath:prepend(vim.fn.getcwd())

vim.opt.mouse = 'a'

local items = {
  'Apple',
  'Apricot',
  'Avocado',
  'Banana',
  'Blackberry',
  'Blueberry',
  'Cherry',
  'Coconut',
  'Cranberry',
  'Dragon fruit Dragon fruitDragon fruit Dragon fruitDragon fruitDragon fruit',
  'Fig',
  'Grape',
  'Grapefruit',
  'Guava',
  'Kiwi',
  'Lemon',
  'Lime',
  'Lychee',
  'Mango',
  'Melon',
  'Nectarine',
  'Orange',
  'Papaya',
  'Passion fruit',
  'Peach',
  'Pear',
  'Pineapple',
  'Plum',
  'Pomegranate',
  'Raspberry',
  'Strawberry',
  'Watermelon',
}

local function open_demo()
  require('picker').setup()
  require('picker').select(items, {
    prompt = 'Choose a fruit (C-l: clipped text only)',
    view = {
      layout = function(panes, context)
        -- Full text replaces the list region, without moving input or widening root.
        return require('popup').col({
          children = {
            panes.input,
            panes.prompt,
            context.detail and panes.detail or panes.list,
          },
        })
      end,
    },
  }, function(item, index)
    print(vim.inspect({ item = item, index = index, cancelled = index == nil }))
  end)
end

vim.api.nvim_create_user_command('SelectDemo', open_demo, {})
open_demo()

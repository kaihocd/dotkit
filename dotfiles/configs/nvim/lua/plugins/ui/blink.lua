local M = {}

M.opts = {
  appearance = {
    nerd_font_variant = 'mono',
    kind_icons = {
      Copilot = '',

      String = '',
      Number = '',
      Boolean = '',
      Array = '󰅨',
      Object = '󱃖',
      Package = '󰏖',
      Null = '󰟢',
      Unknown = '',
      Identifier = '',

      -- keys from lspkind
      Text = '󰉿',
      Method = '󰡱',
      Function = '󰡱',
      Constructor = '',

      Field = '',
      Variable = '',
      Property = '󰜢',

      Class = '󰙅',
      Interface = '',
      Struct = '󱡠',
      Namespace = '󰦮',
      Module = '',

      Unit = '󰑭',
      Value = '󱀍',
      Enum = '',
      EnumMember = '',

      Keyword = '󰌆',
      Constant = '󰐀',

      Snippet = '󱄽',
      Color = '󰏘',
      File = '󰈙',
      Reference = '󰬲',
      Folder = '󰝰',
      Event = '',
      Operator = '',
      TypeParameter = '󰬛',
    },
  },
  completion = {
    -- Leave borders unset: Blink v2 inherits the current global winborder.
    menu = {
      border = 'none',
      draw = {
        columns = { { 'kind_icon' }, { 'label', 'source_name', gap = 2 } },
        components = {
          label = {
            text = function(ctx)
              return require('colorful-menu').blink_components_text(ctx)
            end,
            highlight = function(ctx)
              return require('colorful-menu').blink_components_highlight(ctx)
            end,
          },
        },
      },
    },
  },
}

return M

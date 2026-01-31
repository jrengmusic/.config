-- Snippets configuration
return {
  priority = 1000,
  lazy = false,
  dependencies = {
    'saadparwaiz1/cmp_luasnip',
    'L3MON4D3/LuaSnip',
  },
  deps = 'snippets',
  setup = function()
    local luasnip = require('luasnip')
    
    -- Debug: Check luasnip availability
    vim.defer_fn(function()
      if luasnip then
        vim.cmd('echomsg "LuaSnip available: ' .. tostring(luasnip) .. '"')
      else
        vim.cmd('echomsg "LuaSnip not available"')
      end
    end, 100)
    
    -- Load friendly-snippets collection with delay
    vim.defer_fn(function()
      local ok, err = pcall(function()
        return require('luasnip.loaders.from_vscode').lazy_load()
      end)
    end, 200)
    
    -- Add custom snippets after friendly ones are loaded
    luasnip.add_snippets('cpp', {
      -- Class definition with separator and leak detector
      luasnip.snippet('cls', {
        luasnip.text_node('//=============================================================================='),
        luasnip.text_node({'', ''}),
        luasnip.text_node('JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR ('),
        luasnip.insert_node(2, 'ClassName'),
        luasnip.text_node(')'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('class '),
        luasnip.insert_node(3, 'ClassName'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'public:', '\t'}),
        luasnip.insert_node(4, '// public members'),
        luasnip.text_node({'', '\t'}),
        luasnip.insert_node(5, 'ClassName'),
        luasnip.text_node('() = default;'),
        luasnip.text_node({'', '\t~'}),
        luasnip.insert_node(5, 'ClassName'),
        luasnip.text_node('() = default;'),
        luasnip.text_node({'', '', 'private:', '\t'}),
        luasnip.insert_node(6, '// private members'),
        luasnip.text_node({'', '};'}),
      }),

      -- Separator
      luasnip.snippet('sep', {
        luasnip.text_node({'', '//=============================================================================='}),
      }),

      -- JUCE leak detector with separator
      luasnip.snippet('leak', {
        luasnip.text_node('//=============================================================================='),
        luasnip.text_node({'', ''}),
        luasnip.text_node('JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR ('),
        luasnip.insert_node(1, 'ClassName'),
        luasnip.text_node(')'),
      }),

      -- Simple JUCE Component
      luasnip.snippet('juce', {
        luasnip.text_node('class '),
        luasnip.insert_node(1, 'ComponentName'),
        luasnip.text_node(' : public juce::Component'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'public:', '\t'}),
        luasnip.insert_node(2, 'ComponentName'),
        luasnip.text_node('() noexcept'),
        luasnip.text_node({'', '\tvoid paint (juce::Graphics& g) override', '\t{', '\t\tg.fillAll (juce::Colours::white);', '\t}', '', '\tvoid resized() override', '\t{', '\t\t// Component resizing', '\t}', '', 'private:', '\t// Private members', '\t};'}),
      }),

      -- Function definition (explicit, noexcept where applicable)
      luasnip.snippet('fn', {
        luasnip.insert_node(1, 'returnType'),
        luasnip.text_node(' '),
        luasnip.insert_node(2, 'functionName'),
        luasnip.text_node(' ('),
        luasnip.insert_node(3, 'parameters'),
        luasnip.text_node(') noexcept'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(4, '// function body'),
        luasnip.text_node({'', '}'}),
      }),

      -- Traditional for loop (int, pre-increment)
      luasnip.snippet('loop', {
        luasnip.text_node('for (int '),
        luasnip.insert_node(1, 'i'),
        luasnip.text_node(' { 0 }; '),
        luasnip.insert_node(1, 'i'),
        luasnip.text_node(' < '),
        luasnip.insert_node(2, 'N'),
        luasnip.text_node('; ++'),
        luasnip.insert_node(1, 'i'),
        luasnip.text_node(')'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(3, '// loop body'),
        luasnip.text_node({'', '}'}),
      }),

      -- Range-based for loop (auto, &)
      luasnip.snippet('forr', {
        luasnip.text_node('for (auto& '),
        luasnip.insert_node(1, 'item'),
        luasnip.text_node(' : '),
        luasnip.insert_node(2, 'container'),
        luasnip.text_node(')'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(3, '// loop body'),
        luasnip.text_node({'', '}'}),
      }),

      -- If statement (explicit nullptr check)
      luasnip.snippet('if', {
        luasnip.text_node('if ('),
        luasnip.insert_node(1, 'condition'),
        luasnip.text_node(')'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(2, '// if body'),
        luasnip.text_node({'', '}'}),
      }),

      -- If-else statement
      luasnip.snippet('ife', {
        luasnip.text_node('if ('),
        luasnip.insert_node(1, 'condition'),
        luasnip.text_node(')'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(2, '// if body'),
        luasnip.text_node({'', '}'}),
        luasnip.text_node({'else', '\t{', '\t'}),
        luasnip.insert_node(3, '// else body'),
        luasnip.text_node({'\t}', '}'}),
      }),

      -- While loop
      luasnip.snippet('while', {
        luasnip.text_node('while ('),
        luasnip.insert_node(1, 'condition'),
        luasnip.text_node(')'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(2, '// loop body'),
        luasnip.text_node({'', '}'}),
      }),

      -- Switch statement
      luasnip.snippet('switch', {
        luasnip.text_node('switch ('),
        luasnip.insert_node(1, 'variable'),
        luasnip.text_node(')'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'case ', '\t'}),
        luasnip.insert_node(2, 'value'),
        luasnip.text_node(':'),
        luasnip.text_node({'\t\t'}),
        luasnip.insert_node(3, '// case body'),
        luasnip.text_node({'\t\tbreak;', '', 'default:', '\t\t'}),
        luasnip.insert_node(4, '// default case'),
        luasnip.text_node({'\t\tbreak;', '', '}'}),
      }),

      -- Template function (typename, descriptive names)
      luasnip.snippet('template', {
        luasnip.text_node('template <typename '),
        luasnip.insert_node(1, 'InputType'),
        luasnip.text_node('>'),
        luasnip.insert_node(2, 'returnType'),
        luasnip.text_node(' '),
        luasnip.insert_node(3, 'functionName'),
        luasnip.text_node(' ('),
        luasnip.insert_node(4, 'parameters'),
        luasnip.text_node(') noexcept'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(5, '// function body'),
        luasnip.text_node({'', '}'}),
      }),

      -- Namespace with proper format
      luasnip.snippet('nam', {
        luasnip.text_node('namespace '),
        luasnip.insert_node(1, 'name'),
        luasnip.text_node({'', ''}),
        luasnip.text_node('{'),
        luasnip.text_node({'/*____________________________________________________________________________*/', ''}),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(2, '// namespace content'),
        luasnip.text_node({'', '/**____________________________END OF NAMESPACE______________________________*/'}),
        luasnip.text_node('}  // namespace '),
        luasnip.insert_node(1, 'name'),
      }),

      -- Include guard (uppercase, no spaces)
      luasnip.snippet('guard', {
        luasnip.text_node('#ifndef '),
        luasnip.insert_node(1, 'FILENAME_H'),
        luasnip.text_node({'', '#define '}),
        luasnip.insert_node(1, 'FILENAME_H'),
        luasnip.text_node({'', '', '// Header content', '', '#endif // '}),
        luasnip.insert_node(1, 'FILENAME_H'),
      }),

      -- Test snippet
      luasnip.snippet('test', {
        luasnip.text_node('TEST SNIPPET WORKING!'),
      }),
    })
    
    vim.keymap.set('i', '<C-l>', function() luasnip.jump(1) end, { silent = true })
    vim.keymap.set('i', '<C-h>', function() luasnip.jump(-1) end, { silent = true })
    vim.keymap.set('i', '<C-e>', function()
      if luasnip.choice_active() then
        luasnip.change_choice(1)
      end
    end, { silent = true })

    vim.keymap.set('n', '<leader>fs', function()
      require('snacks').picker.snippets()
    end, { desc = 'Snippet picker' })
  end,
}
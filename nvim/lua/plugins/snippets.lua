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
    local cpp_snippets = {
      -- Class definition with separator and leak detector
      luasnip.snippet('cls', {
        luasnip.text_node('class '),
        luasnip.insert_node(1, 'ClassName'),
        luasnip.text_node({'', '{'}),
        luasnip.text_node({'', 'public:', ''}),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(1, 'ClassName'),
        luasnip.text_node('() = default;'),
        luasnip.text_node({'', '\t~'}),
        luasnip.insert_node(1, 'ClassName'),
        luasnip.text_node('() = default;'),
        luasnip.text_node({'', '', 'private:', ''}),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(2, '// members'),
        luasnip.text_node({'', '', '//==============================================================================', ''}),
        luasnip.text_node({'\tJUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR ('}),
        luasnip.insert_node(1, 'ClassName'),
        luasnip.text_node(')'),
        luasnip.text_node({'', '};'}),
      }),

      -- Separator
      luasnip.snippet('sep', {
        luasnip.text_node({'', '//=============================================================================='}),
      }, {
        callbacks = {
          [-1] = {
            post_expand = function()
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
            end,
          },
        },
      }),

      -- JUCE Component header declaration
      luasnip.snippet('comp', {
        luasnip.text_node('class '),
        luasnip.insert_node(1, 'ComponentName'),
        luasnip.text_node(' : public juce::Component'),
        luasnip.text_node({'', '{'}),
        luasnip.text_node({'', 'public:', ''}),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(1, 'ComponentName'),
        luasnip.text_node('() noexcept;'),
        luasnip.text_node({'', '\t~'}),
        luasnip.insert_node(1, 'ComponentName'),
        luasnip.text_node('() override;'),
        luasnip.text_node({'', '', '\tvoid paint (juce::Graphics&) override;', ''}),
        luasnip.text_node({'\tvoid resized() override;', ''}),
        luasnip.text_node({'private:', ''}),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(2, '// members'),
        luasnip.text_node({'', '', '//==============================================================================', ''}),
        luasnip.text_node({'\tJUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR ('}),
        luasnip.insert_node(1, 'ComponentName'),
        luasnip.text_node(')'),
        luasnip.text_node({'', '};'}),
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
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node(' < '),
        luasnip.insert_node(2, 'N'),
        luasnip.text_node('; ++'),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node(')'),
        luasnip.text_node({ '', '' }),
        luasnip.text_node('{'),
        luasnip.text_node({ '\t' }),
        luasnip.insert_node(3, '// loop body'),
        luasnip.text_node({ '', '}' }),
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
        luasnip.text_node({ '', '' }),
        luasnip.text_node('{'),
        luasnip.text_node({ '\t' }),
        luasnip.insert_node(2, '// if body'),
        luasnip.text_node({ '', '}', '' }),
        luasnip.text_node({ 'else', '' }),
        luasnip.text_node({ '{', '\t' }),
        luasnip.insert_node(3, '// else body'),
        luasnip.text_node({ '', '}' }),
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
        luasnip.text_node({ '', '' }),
        luasnip.text_node({ '{', '' }),
        luasnip.text_node({ '\tcase ' }),
        luasnip.insert_node(2, 'value'),
        luasnip.text_node(':'),
        luasnip.text_node({ '', '\t\t' }),
        luasnip.insert_node(3, '// case body'),
        luasnip.text_node({ '', '\t\tbreak;', '', '\tdefault:', '' }),
        luasnip.text_node({ '\t\t' }),
        luasnip.insert_node(4, '// default case'),
        luasnip.text_node({ '', '\t\tbreak;', '', '}' }),
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
        luasnip.text_node({'', '{'}),
        luasnip.text_node({'/*____________________________________________________________________________*/', ''}),
        luasnip.text_node({'\t'}),
        luasnip.insert_node(2, '// namespace content'),
        luasnip.text_node({'', '/**______________________________END OF NAMESPACE______________________________*/', '}  // namespace '}),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
      }),



      -- std::unique_ptr
      luasnip.snippet('unp', {
        luasnip.text_node('std::unique_ptr<'),
        luasnip.insert_node(1, 'type'),
        luasnip.text_node('> '),
        luasnip.insert_node(2, 'name'),
      }),

      -- std::make_unique
      luasnip.snippet('mku', {
        luasnip.text_node('std::make_unique<'),
        luasnip.insert_node(1, 'type'),
        luasnip.text_node('>('),
        luasnip.insert_node(2, 'args'),
        luasnip.text_node(')'),
      }),

      -- std::make_shared
      luasnip.snippet('mks', {
        luasnip.text_node('std::make_shared<'),
        luasnip.insert_node(1, 'type'),
        luasnip.text_node('>('),
        luasnip.insert_node(2, 'args'),
        luasnip.text_node(')'),
      }),

      -- Debug paint (magenta border)
      luasnip.snippet('dbp', {
        luasnip.text_node('void paint (juce::Graphics& g) override'),
        luasnip.text_node({'', '{'}),
        luasnip.text_node({'', '\tg.setColour (juce::Colours::magenta);'}),
        luasnip.text_node({'', '\tg.drawRect (getLocalBounds(), 2.0f);'}),
        luasnip.text_node({'', '}'}),
      }),

      -- Meyer singleton
      luasnip.snippet('sing', {
        luasnip.text_node('class '),
        luasnip.insert_node(1, 'MeyersSingleton'),
        luasnip.text_node({'', '{'}),
        luasnip.text_node({'', 'public:', ''}),
        luasnip.text_node({'', '\tstatic '}),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('& instance()'),
        luasnip.text_node({'', '\t{'}),
        luasnip.text_node({'', '\t\tstatic '}),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node(' single;'),
        luasnip.text_node({'', '\t\treturn single;'}),
        luasnip.text_node({'', '\t}', ''}),
        luasnip.text_node({'', '//==============================================================================', ''}),
        luasnip.text_node({'', 'private:', ''}),
        luasnip.text_node({'', '\t'}),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('() = default;'),
        luasnip.text_node({'', '\t'}),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('(const '),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('&) = delete;'),
        luasnip.text_node({'', '\t'}),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('('),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('&&) = delete;'),
        luasnip.text_node({'', '\t'}),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('& operator=('),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('&&) = delete;'),
        luasnip.text_node({'', '\t'}),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('& operator=(const '),
        luasnip.function_node(function(args) return args[1][1] end, { 1 }),
        luasnip.text_node('&) = delete;'),
        luasnip.text_node({'', '};'}),
      }),

      -- JUCE macOS
      luasnip.snippet('mac', {
        luasnip.text_node('#if JUCE_MAC'),
        luasnip.text_node({'', '\t'}),
        luasnip.insert_node(1, 'something'),
        luasnip.text_node({'', '#endif // JUCE_MAC'}),
      }),

      -- JUCE Windows
      luasnip.snippet('win', {
        luasnip.text_node('#if JUCE_WINDOWS'),
        luasnip.text_node({'', '\t'}),
        luasnip.insert_node(1, 'something'),
        luasnip.text_node({'', '#endif // JUCE_WINDOWS'}),
      }),

      -- Test snippet
      luasnip.snippet('test', {
        luasnip.text_node('TEST SNIPPET WORKING!'),
      }),
    }

    -- Override friendly-snippets namespace with custom nam
    vim.defer_fn(function()
      luasnip.add_snippets('cpp', cpp_snippets)
      luasnip.add_snippets('objcpp', cpp_snippets)
      luasnip.add_snippets('objc', cpp_snippets)
      
      -- Remove friendly-snippets namespace
      local all_snippets = luasnip.get_snippets('cpp')
      if all_snippets then
        for i, snip in ipairs(all_snippets) do
          if snip.trigger == 'namespace' then
            table.remove(all_snippets, i)
            break
          end
        end
      end
    end, 300)
    
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

    vim.keymap.set('i', '<C-v>', function()
      require('snacks').picker.snippets()
    end, { desc = 'Snippet picker (insert mode)' })
  end,
}
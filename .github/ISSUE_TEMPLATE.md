### Environment

* Elixir & Erlang versions (elixir --version): 
* Operating system: 
* Editor or IDE name (e.g. Emacs/VSCode): 
* Editor Plugin/LSP Client name:

### Troubleshooting

- [ ] Restart your editor (which will restart ElixirLS) sometimes fixes issues
- [ ] Stop your editor, remove the entire `.elixir_ls` directory, then restart your editor
  * NOTE: This will cause you to have to re-run the dialyzer build for your project

If you're experiencing high CPU usage, it is most likely Dialyzer building the PLTs; after it's done the CPU usage should go back to normal. You could also disable Dialyzer in the settings.

### Logs

1.  If using a client other than VS Code, please try VSCode's "ElixirLS: Elixir support and debugger" extension. Does it reproduce your failure?
2.  Create a new Mix project with `mix new empty`, then open that project with VS Code and open an Elixir file. Is your issue reproducible on the empty project? If not, please publish a repo on Github that does reproduce it.
3.  Check the output log by opening `View > Output` and selecting "ElixirLS" in the dropdown. Please include any output that looks relevant. (If ElixirLS isn't in the dropdown, the server failed to launch.)
4.  Check the developer console by opening `Help > Toggle Developer Tools` and include any errors that look relevant.

-- The download worker as its own program, used only on macOS, where a forked child cannot use the network.
local plugin_dir, list_path, progress_path, ca_file, user_agent = arg[1], arg[2], arg[3], arg[4], arg[5]
require("setupkoenv")
package.path = plugin_dir .. "/?.lua;" .. package.path
require("catchink/net/worker").run(list_path, progress_path, ca_file, user_agent)

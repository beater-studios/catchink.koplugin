-- Cases of tools/koreader/check_rotation.lua for this plugin.
return {
    ["catchink/ui/surface"] = "base class, opened only through catchink/ui/screen",
    ["catchink/ui/screen"] = function(plugin_dir)
        return { plugin_dir = plugin_dir }
    end,
}

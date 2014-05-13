

static string? config_file = null;
static bool debug = false;

static const OptionEntry[] options = {
    { "config-file", 'c', 0, OptionArg.FILENAME, ref config_file,
        "The server config file. See config/config.json for an example.",
        "[file]" },
    { "debug", 'd', 0, OptionArg.NONE, ref debug,
        "Print debug messages to the console", null },
    { null }
};

static int main(string[] args) {
    string? root_device_xml;
    string? service_directory;
    RemoteUI[] remoteUIs = {};
    try {
        var opt_context = new OptionContext("UPnP RemoteUIServer");
        opt_context.set_help_enabled (true);
        opt_context.add_main_entries (options, null);
        opt_context.parse (ref args);
        if (config_file == null) {
            throw new OptionError.BAD_VALUE("Missing --config-file");
        }
    } catch (OptionError e) {
        stderr.printf ("%s\n", e.message);
        stderr.printf ("Run '%s --help' to see a full list of available command line options.\n",
            args[0]);
        return 2;
    }
    try {
        var parser = new Json.Parser();
        parser.load_from_file(config_file);

        var root = parser.get_root();
        var object = root.get_object();
        if (object == null) {
            stderr.printf("Config file has no root object.\n");
            return 4;
        }
        root_device_xml = object.get_string_member("root-device-xml");
        if (root_device_xml == null) {
            throw new RUIError.BAD_CONFIG("Missing \"root-device-xml\"");
        }
        service_directory = object.get_string_member("service-directory");
        if (service_directory == null) {
            throw new RUIError.BAD_CONFIG("Missing \"service-directory\"");
        }
        if (!Path.is_absolute(service_directory)) {
            service_directory = Path.build_filename(Path.get_dirname(config_file), service_directory);
        }
        var uis = object.get_array_member("uis");
        for (var i = 0; i < uis.get_length(); ++i) {
            var ui_node = uis.get_element(i).get_object();
            if (ui_node == null) {
                stderr.printf("Ignoring non-object member of uis array.\n");
                continue;
            }
            string[] required_members = {"id", "name", "url"};
            var missing_required = false;
            foreach (string member in required_members) {
                if (!ui_node.has_member(member)) {
                    stderr.printf("Ignoring UI with missing required attribute \"%s\".\n",
                        member);
                    missing_required = true;
                    break;
                }
            }
            if (missing_required) {
                continue;
            }
            var id = ui_node.get_string_member("id");
            var name = ui_node.get_string_member("name");
            var url = ui_node.get_string_member("url");
            string? description = null;
            if (ui_node.has_member("description")) {
                description = ui_node.get_string_member("description");
            }
            Icon[]? icons = null;
            if (ui_node.has_member("icons")) {
                icons = {};
                Json.Array icons_node = ui_node.get_array_member("icons");
                for (var j = 0; j < icons_node.get_length(); ++j) {
                    Json.Object icon_node = icons_node.get_element(j).get_object();
                    if (!icon_node.has_member("url")) {
                        stderr.printf("Ignoring icon with missing require attribute \"url\" for UI %s.\n", name);
                        continue;
                    }
                    Icon icon = {};
                    icon.url = icon_node.get_string_member("url");
                    if (icon_node.has_member("width")) {
                        var width = icon_node.get_int_member("width");
                        if (width > 0) {
                            icon.width = width;
                        } else {
                            stderr.printf("Ignoring invalid width %" + int64.FORMAT + " for URL %s.\n",
                                width, icon.url);
                        }
                    }
                    if (icon_node.has_member("height")) {
                        var height = icon_node.get_int_member("height");
                        if (height > 0) {
                            icon.height = height;
                        } else {
                            stderr.printf("Ignoring invalid height %" + int64.FORMAT + " for URL %s.\n",
                                height, icon.url);
                        }
                    }
                    icons += icon;
                }
                if (icons.length == 0) {
                    stderr.printf("Ignoring invalid 0-length icons list for UI %s.\n",
                        name);
                    icons = null;
                }
            }
            remoteUIs += RemoteUI(id, name, description, url, icons);
        }
    } catch (Error e) {
        stderr.printf("Error reading config file %s.\n", config_file);
        return 3;
    }
    try {
        RemoteUIServer server = new RemoteUIServer(root_device_xml,
            service_directory, remoteUIs);
        server.start();
        return 0;
    } catch (Error e) {
        stderr.printf("Error running RemoteUIServer: %s\n", e.message);
        return 1;
    }
}

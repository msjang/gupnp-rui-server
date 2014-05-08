errordomain RUIError {
    BAD_CONFIG
}

struct Icon {
    uint64? width;
    uint64? height;
    string url;
}

struct RemoteUI {
    public RemoteUI(string id, string name, string? description, string url,
            Icon[]? icons) {
        this.id = id;
        this.name = name;
        this.description = description;
        this.url = url;
        this.icons = icons;
    }
    string id;
    string name;
    string? description;
    string url;
    Icon[]? icons;
}

class XMLBuilder {
    StringBuilder builder;

    public XMLBuilder() {
        builder = new StringBuilder();
    }

    public void open_tag(string tag, string? attributes = null) {
        builder.append_c('<');
        builder.append(tag);
        if (attributes != null) {
            builder.append_c(' ');
            builder.append(attributes);
        }
        builder.append_c('>');
    }

    public void close_tag(string tag) {
        builder.append("</");
        builder.append(tag);
        builder.append_c('>');
    }

    public void append_node(string tag, string content,
            string? attributes = null) {
        open_tag(tag);
        builder.append(content);
        close_tag(tag);
    }

    public string to_string() {
        return builder.str;
    }
}

class RemoteUIServer {
    static const string REMOTE_UI_SERVICE_TYPE = "urn:schemas-upnp-org:service:RemoteUIServer:1";

    string root_device_xml;
    string service_directory;

    GUPnP.Context context;
    GUPnP.RootDevice root_device;
    RemoteUI[] remoteUIs;

    public RemoteUIServer(string root_device_xml, string service_directory,
        RemoteUI[] remoteUIs) {
        this.root_device_xml = root_device_xml;
        this.service_directory = service_directory;
        this.remoteUIs = remoteUIs;
    }

    public void start() throws Error {
        context = new GUPnP.Context(null, null, 0);
        root_device = new GUPnP.RootDevice(context, root_device_xml,
            service_directory);
        root_device.set_available(true);
        stdout.printf("Running UPnP service on http://%s:%u/%s\n", context.host_ip, context.port, root_device.description_path);

        var service = (GUPnP.Service)root_device.get_service(REMOTE_UI_SERVICE_TYPE);
        if (service == null) {
            throw new RUIError.BAD_CONFIG(
                "Unable to get %s.".printf(REMOTE_UI_SERVICE_TYPE));
        }
        service.action_invoked["GetCompatibleUIs"].connect(on_get_compatible_uis);
        
        MainLoop loop = new MainLoop();
        Unix.signal_add(Posix.SIGINT, () => {
            loop.quit();
            return true;
        });
        loop.run();
        root_device.set_available(false);
    }
    
    void on_get_compatible_uis(GUPnP.ServiceAction action) {
        XMLBuilder builder = new XMLBuilder();
        builder.open_tag("uilist");
        foreach (RemoteUI ui in remoteUIs) {
            builder.open_tag("ui");
            builder.append_node("uiID", ui.id);
            builder.append_node("name", ui.name);
            if (ui.description != null) {
                builder.append_node("description", ui.description);
            }
            if (ui.icons != null && ui.icons.length > 0) {
                builder.open_tag("iconList");
                foreach (Icon icon in ui.icons) {
                    builder.open_tag("icon");
                    builder.append_node("url", icon.url);
                    if (icon.width != null) {
                        builder.append_node("width", icon.width.to_string());
                    }
                    if (icon.height != null) {
                        builder.append_node("height", icon.height.to_string());
                    }
                    builder.close_tag("icon");
                }
                builder.close_tag("iconList");
            }
            builder.open_tag("protocol", "shortName=\"DLNA-HTML5-1.0\"");
            builder.append_node("uri", ui.url);
            builder.close_tag("protocol");
            builder.close_tag("ui");
        }
        builder.close_tag("uilist");
        action.set_value("UIListing", builder.to_string());
        action.return();
    }
}

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

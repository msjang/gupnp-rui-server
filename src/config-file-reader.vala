public class RUI.ConfigFileReader {
    public string root_device_xml { get; private set; }
    public string service_directory { get; private set; }
    public RemoteUI[] remoteUIs { get; private set; }

    private string config_file;
    private FileMonitor? file_monitor = null;

    public signal void remote_uis_changed();

    public ConfigFileReader(string config_file) {
        this.config_file = config_file;
    }

    private bool check_required_members(string type, Json.Object obj,
            string[] required_members) {
        var missing_required = false;
        foreach (string member in required_members) {
            if (!obj.has_member(member)) {
                stderr.printf("Ignoring %s with missing required attribute \"%s\".\n",
                    type, member);
                missing_required = true;
            }
        }
        return !missing_required;
    }

    public void parse_config_file() throws Error {
        var parser = new Json.Parser();
        parser.load_from_file(config_file);

        var root = parser.get_root();
        var object = root.get_object();
        if (object == null) {
            throw new RUIError.BAD_CONFIG("Config file has no root object.\n");
        }
        string[] required_members = {"root-device-xml", "service-directory"};
        if (!check_required_members("config file", object, required_members)) {
            throw new RUIError.BAD_CONFIG("Missing \"root-device-xml\" or \"service-directory\"");
        }
        root_device_xml = object.get_string_member("root-device-xml");
        service_directory = object.get_string_member("service-directory");
        if (!Path.is_absolute(service_directory)) {
            service_directory = Path.build_filename(Path.get_dirname(config_file), service_directory);
        }
        var uis = object.get_array_member("uis");
        RemoteUI[] remoteUIs = {};
        for (var i = 0; i < uis.get_length(); ++i) {
            var ui_node = uis.get_element(i).get_object();
            if (ui_node == null) {
                stderr.printf("Ignoring non-object member of uis array.\n");
                continue;
            }
            required_members = {"id", "name", "protocols"};
            if (!check_required_members("UI", ui_node, required_members)) {
                continue;
            }
            RUI.RemoteUI remoteUI = RUI.RemoteUI() {
                id = ui_node.get_string_member("id"),
                name = ui_node.get_string_member("name")
            };
            if (ui_node.has_member("description")) {
                remoteUI.description = ui_node.get_string_member("description");
            }
            RUI.Protocol[] protocols = {};
            Json.Array protocols_node = ui_node.get_array_member("protocols");
            for (var j = 0; j < protocols_node.get_length(); ++j) {
                Json.Object protocol_node = protocols_node.get_element(j).get_object();
                required_members = {"urls", "shortName"};
                if (!check_required_members("protocol", protocol_node, required_members)) {
                    continue;
                }
                RUI.Protocol protocol = RUI.Protocol() {
                    shortName = protocol_node.get_string_member("shortName")
                };
                string[] urls = {};
                Json.Array urls_node = protocol_node.get_array_member("urls");
                for (var k = 0; k < urls_node.get_length(); ++k) {
                    urls += urls_node.get_element(k).get_string();
                }
                if (urls.length == 0) {
                    stderr.printf("Ignoring invalid protocols attribute with no urls.\n");
                    continue;
                }
                protocol.urls = urls;
                protocols += protocol;
            }
            if (protocols.length == 0) {
                stderr.printf("Ignoring invalid RemoteUI with 0-length protocol list.\n");
                continue;
            }
            remoteUI.protocols = protocols;
            if (ui_node.has_member("icons")) {
                RUI.Icon[] icons = {};
                Json.Array icons_node = ui_node.get_array_member("icons");
                for (var j = 0; j < icons_node.get_length(); ++j) {
                    Json.Object icon_node = icons_node.get_element(j).get_object();
                    required_members = {"url"};
                    if (!check_required_members("icon", icon_node, required_members)) {
                        continue;
                    }
                    RUI.Icon icon = RUI.Icon() {
                        url = icon_node.get_string_member("url")
                    };
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
                        remoteUI.name);
                    remoteUI.icons = null;
                } else {
                    remoteUI.icons = icons;
                }
            }
            remoteUIs += remoteUI;
        }
        this.remoteUIs = remoteUIs;
        remote_uis_changed();
    }

    public void watch_config_file() throws Error {
        if (file_monitor != null) {
            file_monitor.cancel();
        }
        var file = File.new_for_path(config_file);
        stdout.printf("Watching %s\n", file.get_path());
        file_monitor = file.monitor(FileMonitorFlags.NONE);
        file_monitor.changed.connect(on_config_file_changed);
        parse_config_file();
    }

    private void on_config_file_changed(File file, File? other_file,
            FileMonitorEvent event) {
        if (event != FileMonitorEvent.CHANGED && event != FileMonitorEvent.CREATED) {
            return;
        }
        try {
            parse_config_file();
        } catch (Error e) {
            stderr.printf(
                "Error parsing changed config file: %s. Continuing to use the old config file.\n",
                e.message);
        }
    }
}

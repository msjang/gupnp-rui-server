/* Copyright (c) 2014, CableLabs, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
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

internal static bool check_required_members(string type, Json.Object obj,
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

internal static int main(string[] args) {
    string? root_device_xml;
    string? service_directory;
    RUI.RemoteUI[] remoteUIs = {};
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
            string[] required_members = {"id", "name", "protocols"};
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
    } catch (Error e) {
        stderr.printf("Error reading config file %s.\n", config_file);
        return 3;
    }
    try {
        RUI.RemoteUIServer server = new RUI.RemoteUIServer(root_device_xml,
            service_directory, remoteUIs);
        server.start();
        return 0;
    } catch (Error e) {
        stderr.printf("Error running RemoteUIServer: %s\n", e.message);
        return 1;
    }
}

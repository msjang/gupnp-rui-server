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
errordomain RUIError {
    BAD_CONFIG
}

public class RUI.RemoteUIServer {
    static const string REMOTE_UI_SERVICE_TYPE = "urn:schemas-upnp-org:service:RemoteUIServer:1";

    string root_device_xml;
    string service_directory;

    GUPnP.Context context;
    GUPnP.RootDevice root_device;
    RemoteUI[] remoteUIs;

    public RemoteUIServer(ConfigFileReader config) {
        this.root_device_xml = config.root_device_xml;
        this.service_directory = config.service_directory;
        this.remoteUIs = config.remoteUIs;
        config.remote_uis_changed.connect(on_remote_uis_changed);
    }

    private void on_remote_uis_changed(ConfigFileReader config) {
        this.remoteUIs = config.remoteUIs;
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
            foreach (Protocol protocol in ui.protocols) {
                builder.open_tag("protocol",
                    "shortName=\"%s\"".printf(protocol.shortName));
                foreach (string url in protocol.urls) {
                    builder.append_node("uri", url);
                }
                builder.close_tag("protocol");
            }
            builder.close_tag("ui");
        }
        builder.close_tag("uilist");
        action.set_value("UIListing", builder.to_string());
        action.return();
    }
}

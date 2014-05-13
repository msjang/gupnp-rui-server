errordomain RUIError {
    BAD_CONFIG
}

public class RemoteUIServer {
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

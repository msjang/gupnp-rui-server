errordomain RUIError {
    BAD_CONFIG
}

class RemoteUIServer {
    static const string REMOTE_UI_SERVICE_TYPE = "urn:schemas-upnp-org:service:RemoteUIServer:1";

    string root_device_xml;
    string service_directory;

    GUPnP.Context context;
    GUPnP.RootDevice root_device;
    
    public RemoteUIServer(string root_device_xml, string service_directory) {
        this.root_device_xml = root_device_xml;
        this.service_directory = service_directory;
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
        loop.run();
    }
    
    void on_get_compatible_uis(GUPnP.ServiceAction action) {
        action.set_value("UIListing", "<uilist></uilist>");
        action.return();
    }
}

static string? root_device_xml = null;
static string? service_directory = null;
static bool debug = false;

static const OptionEntry[] options = {
    { "root-device-xml", 0, 0, OptionArg.FILENAME, ref root_device_xml,
        "The root device XML file.", "[file]" },
    { "service-directory", 0, 0, OptionArg.FILENAME, ref service_directory,
        "The directory with service XML files.", "[file]" },
    { "debug", 'd', 0, OptionArg.NONE, ref debug,
        "Print debug messages to the console", null },
    { null }
};

static int main(string[] args) {
    try {
        var opt_context = new OptionContext("UPnP RemoteUIServer");
        opt_context.set_help_enabled (true);
        opt_context.add_main_entries (options, null);
        opt_context.parse (ref args);
        if (root_device_xml == null) {
            throw new OptionError.BAD_VALUE("Missing --root-device-xml");
        }
        if (service_directory == null) {
            throw new OptionError.BAD_VALUE("Missing --service-directory");
        }
    } catch (OptionError e) {
        stderr.printf ("%s\n", e.message);
        stderr.printf ("Run '%s --help' to see a full list of available command line options.\n",
            args[0]);
        return 2;
    }
    try {
        RemoteUIServer server = new RemoteUIServer(root_device_xml,
            service_directory);
        server.start();
        return 0;
    } catch (Error e) {
        stderr.printf("Error running RemoteUIServer: %s\n", e.message);
        return 1;
    }
}

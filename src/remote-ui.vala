public struct Icon {
    uint64? width;
    uint64? height;
    string url;
}

public struct RemoteUI {
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

public class XMLBuilder {
    StringBuilder builder;

    public XMLBuilder() {
        builder = new StringBuilder();
    }

    public void open_tag(string tag, string? attributes = null) {
        builder.append_printf("<%s", tag);
        if (attributes != null) {
            builder.append_c(' ');
            builder.append(attributes);
        }
        builder.append_c('>');
    }

    public void close_tag(string tag) {
        builder.append_printf("</%s>", tag);
    }

    public void append_node(string tag, string content,
            string? attributes = null) {
        open_tag(tag, attributes);
        builder.append(Markup.escape_text(content));
        close_tag(tag);
    }

    public string to_string() {
        return builder.str;
    }
}

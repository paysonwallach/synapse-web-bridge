namespace Synapse {

    // public void log_to_file (string message) {
    //     var file = File.new_for_path ("/home/paysonwallach/Projects/synapse-firefox/plugin.log");
    //     try {
    //         FileOutputStream os = file.append_to (FileCreateFlags.NONE);
    //
    //         os.write (@"$message\n".data);
    //     } catch (Error err) {
    //         warning (err.message);
    //     }
    // }

    [DBus (name = "com.paysonwallach.synapse_firefox.connector")]
    public interface DBusClient : Object {
        public abstract int query (string body, out UnixInputStream stream, out int results_count) throws DBusError, IOError;
        public abstract void open_url (string url) throws DBusError, IOError;

    }

    public struct Page {
        public string name;
        public string? description;
        public string url;

        public Page (string name, string? description, string url) {
            this.name = name;
            this.description = description;
            this.url = url;
        }

    }

    public class PageMatch : ActionMatch {
        public string url { get; set; }

        public PageMatch (string name, string? description, string url) {
            Object (
                title: name,
                description: description != null ? description : url,
                has_thumbnail: false, icon_name: "firefox");

            this.url = url;
        }

        public override void do_action () {
            try {
                FirefoxPlugin.browser_extension_proxy.open_url (url);

                Wnck.Screen? screen = Wnck.Screen.get_default ();
                screen.force_update ();
                screen.get_windows ().@foreach ((window) => {
                    if (window.get_state () == Wnck.WindowState.DEMANDS_ATTENTION)
                        window.activate_transient (Gdk.x11_get_server_time (Gdk.get_default_root_window ()));
                });
            } catch (DBusError err) {
                error (@"DBusError: $(err.message)");
            } catch (IOError err) {
                error (@"IOError: $(err.message)");
            }
        }

    }

    public class FirefoxPlugin : Object, Activatable, ItemProvider {

        public static DBusClient browser_extension_proxy;

        public bool enabled { get; set; default = true; }

        public void activate () {
            try {
                browser_extension_proxy = Bus.get_proxy_sync (
                    BusType.SESSION,
                    "com.paysonwallach.synapse_firefox.connector",
                    "/com/paysonwallach/synapse_firefox/connector"
                    );
            } catch (IOError err) {
                warning (err.message);
            }
        }

        public void deactivate () {
            browser_extension_proxy = null;
        }

        public bool handles_query (Query query) {
            return (QueryFlags.ACTIONS in query.query_type);
        }

        public async ResultSet? search (Query query) throws SearchError {
            var result_set = new ResultSet ();

            if (query.query_string.length < 2)
                return result_set;

            try {
                UnixInputStream fd;
                int results_count;

                browser_extension_proxy.query (query.query_string, out fd, out results_count);

                var parser = new Json.Parser ();

                for (int i = 0 ; i < results_count ; i++) {
                    var result_bytes = read (fd);

                    try {
                        parser.load_from_data ((string) result_bytes.get_data (), (ssize_t) result_bytes.get_size ());
                    } catch (Error err) {
                        warning (err.message);
                    }

                    unowned Json.Node node = parser.get_root ();

                    if (node.get_node_type () != Json.NodeType.OBJECT) {
                        warning (@"message root is of type $(node.type_name ())");
                    } else {
                        unowned Json.Object object = node.get_object ();
                        var title = object.get_string_member ("title");
                        var url = object.get_string_member ("url");

                        result_set.add (
                            new PageMatch (title, null, url),
                            MatchScore.AVERAGE
                            );
                    }
                }
            } catch (DBusError err) {
                warning (@"DBusError: $(err.message)");
            } catch (IOError err) {
                warning (@"IOError: $(err.message)");
            }

            query.check_cancellable ();

            return result_set;
        }

        private Bytes read (InputStream stream) {
            Bytes message_bytes = null;
            Bytes message_length_bytes = null;

            try {
                message_length_bytes = stream.read_bytes (4);
            } catch (Error err) {
                warning (@"Error: $(err.message)");
            }

            if (message_length_bytes.get_size () == 0)
                return message_length_bytes;

            var message_length_buffer = message_length_bytes.get_data ();

            if (message_length_bytes.get_size () == 4) {
                size_t message_content_length = (
                    (message_length_buffer[3] << 24)
                    + (message_length_buffer[2] << 16)
                    + (message_length_buffer[1] << 8)
                    + (message_length_buffer[0])
                    );

                if (message_content_length > 0) {
                    try {
                        message_bytes = stream.read_bytes (message_content_length, null);
                    } catch (Error err) {
                        warning (@"Error: $(err.message)");
                    }
                }
            }

            return message_bytes;
        }

    }
}

Synapse.PluginInfo register_plugin () {
    return new Synapse.PluginInfo (
        typeof (Synapse.FirefoxPlugin),
        "Firefox",
        "",
        "firefox",
        null,
        Environment.find_program_in_path ("firefox") != null,
        "Firefox is not install"
        );
}

/*
 * Copyright (c) 2020 Payson Wallach
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Synapse.Plugins.Web.Bridge {
    public enum MessageType {
        COMMAND,
        QUERY;

        public string to_string () {
            switch (this) {
            case COMMAND:
                return "command";
            case QUERY:
                return "query";
            default:
                assert_not_reached ();
            }
        }

    }

    [DBus (name = "com.paysonwallach.synapse.plugins.web.bridge")]
    public class WebBridgeBusServer : Object {
        private uint owner_id = 0U;

        [DBus (visible = false)]
        public signal void results_ready (DataOutputStream stream);

        private static Once<WebBridgeBusServer> instance;

        public static unowned WebBridgeBusServer get_default () {
            return instance.once (() => {
                return new WebBridgeBusServer ();
            });
        }

        construct {
            /* *INDENT-OFF* */
            owner_id = Bus.own_name (
                BusType.SESSION,
                "com.paysonwallach.synapse.plugins.web.bridge",
                BusNameOwnerFlags.ALLOW_REPLACEMENT | BusNameOwnerFlags.REPLACE,
                (connection) => {
                    try {
                        debug ("acquiring bus name...");
                        connection.register_object (
                            "/com/paysonwallach/synapse/plugins/web/bridge",
                            get_default ());
                    } catch (IOError err) {
                        error (err.message);
                    }
                },
                () => {},
                () => { error ("could not acquire bus name"); });
            /* *INDENT-ON* */
        }

        ~WebBridgeBusServer () {
            if (owner_id != 0U)
                Bus.unown_name (owner_id);
        }

        public int query (string body, out UnixInputStream stream) throws DBusError, IOError {
            post_message (MessageType.QUERY.to_string (), body);

            var fd = new int[2];
            var ret = Posix.pipe (fd);

            if (ret == -1)
                return ret;

            var output_base_stream = new UnixOutputStream (fd[1], false);
            var output_stream = new DataOutputStream (output_base_stream);

            output_stream.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);

            results_ready (output_stream);

            stream = new UnixInputStream (fd[0], false);

            return ret;
        }

        public void open_url (string url) throws DBusError, IOError {
            post_message (MessageType.COMMAND.to_string (), url);
        }

        private void post_message (string message_type, string body) throws DBusError, IOError {
            var builder = new Json.Builder ();

            builder.begin_object ();
            builder.set_member_name ("type");
            builder.add_string_value (message_type);

            builder.set_member_name ("body");
            builder.add_string_value (body);
            builder.end_object ();

            var generator = new Json.Generator ();
            var root = builder.get_root ();

            generator.set_root (root);

            var message = generator.to_data (null);
            var message_length_buffer = new uint8[4];

            message_length_buffer[3] = (uint8) ((message.length >> 24) & 0xFF);
            message_length_buffer[2] = (uint8) ((message.length >> 16) & 0xFF);
            message_length_buffer[1] = (uint8) ((message.length >> 8) & 0xFF);
            message_length_buffer[0] = (uint8) (message.length & 0xFF);

            stdout.write (message_length_buffer);
            stdout.write (message.data);
            stdout.flush ();
        }

    }

    private size_t get_message_content_length (Bytes message_length_bytes) {
        size_t message_content_length = 0;
        uint8[] message_length_buffer = message_length_bytes.get_data ();

        if (message_length_bytes.get_size () == 4)
            message_content_length = (
                (message_length_buffer[3] << 24)
                + (message_length_buffer[2] << 16)
                + (message_length_buffer[1] << 8)
                + (message_length_buffer[0])
                );

        return message_content_length;
    }

    public static int main (string[] args) {
        var loop = new MainLoop (null, false);
        var host_connector_bus_server = WebBridgeBusServer.get_default ();

        Unix.signal_add (Posix.Signal.TERM, () => {
            loop.quit ();

            return Source.REMOVE;
        });

        host_connector_bus_server.results_ready.connect ((stream) => {
            var base_input_stream = new UnixInputStream (0, false);
            var input_stream = new DataInputStream (base_input_stream);

            input_stream.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);

            var results_count = -1;

            do {
                uint32 results_count_message_length = 0U;

                try {
                    results_count_message_length = input_stream.read_uint32 ();
                    debug (@"results_count_message_length: $results_count_message_length");
                } catch (Error err) {
                    warning (@"Error: $(err.message)");
                }

                if (results_count_message_length <= 0)
                    continue;

                Bytes results_count_message_bytes = null;

                try {
                    results_count_message_bytes = input_stream.read_bytes (results_count_message_length);
                } catch (Error err) {
                    warning (@"Error: $(err.message)");
                }

                results_count = int.parse (
                    (string) results_count_message_bytes.get_data ());
                debug (@"results_count: $results_count");

                try {
                    stream.put_uint32 (results_count_message_length);
                    stream.write_bytes (results_count_message_bytes);
                } catch (Error err) {
                    warning (@"unable to write to stream: $(err.message)");
                }
            } while (results_count == -1);

            for (int i = 0 ; i < results_count ; i++) {
                try {
                    var message_content_length = input_stream.read_uint32 ();
                    debug (@"message_content_length: $message_content_length");

                    stream.put_uint32 (message_content_length);

                    var message_content = input_stream.read_bytes (message_content_length);
                    debug (@"message_content: $((string) message_content.get_data ())");
                    ssize_t written = 0L;

                    while (written < message_content.length) {
                        var end = message_content.length - written > 4096 ? written + 4096 : message_content.length;

                        written += stream.write_bytes (message_content.slice (written, end));
                        debug (@"written: $written");
                    }

                    stream.flush ();
                } catch (Error err) {
                    debug (@"unable to write to stream: $(err.message)");
                }
            }
        });

        loop.run ();

        return 0;
    }

}

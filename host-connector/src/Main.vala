namespace Synapse.HostConnector {
    public void log_to_file (string message) {
        var file = File.new_for_path ("/home/paysonwallach/out.txt");
        try {
            FileOutputStream os = file.append_to (FileCreateFlags.NONE);

            os.write (@"$message\n".data);
        } catch (Error err) {
            warning (err.message);
        }
    }

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

    [DBus (name = "com.paysonwallach.synapse_firefox.connector")]
    public class DBusServer : Object {
        public int query (string body, out UnixInputStream stream, out int results_count) throws DBusError, IOError {
            try {
                post_message (MessageType.QUERY.to_string (), body);
            } catch (DBusError err) {
                error (@"DBusError: $(err.message)");
            } catch (IOError err) {
                error (@"IOError: $(err.message)");
            }

            var base_input_stream = new UnixInputStream (0, false);
            var input_stream = new DataInputStream (base_input_stream);

            input_stream.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);

            results_count = -1;

            do {
                Bytes results_count_message_length_bytes = null;

                try {
                    results_count_message_length_bytes = input_stream.read_bytes (4);
                } catch (Error err) {
                    warning (@"unable to read results count: $(err.message)");
                }

                var results_count_message_length = get_message_content_length (results_count_message_length_bytes);

                debug (@"$results_count_message_length");

                if (results_count_message_length <= 0)
                    continue;

                Bytes results_count_message_bytes = null;

                try {
                    results_count_message_bytes = input_stream.read_bytes (results_count_message_length);
                } catch (Error err) {
                    warning (@"Error: $(err.message)");
                }

                var message_string = (string) results_count_message_bytes.get_data ();

                debug (@"$message_string");

                results_count = int.parse (message_string);
            } while (results_count == -1);

            if (results_count == 0)
                return 0;

            var fd = new int[2];
            var ret = Posix.pipe (fd);

            if (ret == -1)
                return ret;

            var output_base_stream = new UnixOutputStream (fd[1], false);
            var output_stream = new DataOutputStream (output_base_stream);

            output_stream.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);

            for (int i = 0 ; i < results_count ; i++) {
                Bytes message_length_bytes = null;

                try {
                    do {
                        message_length_bytes = input_stream.read_bytes (4);
                    } while (message_length_bytes.get_size () != 4);
                } catch (Error err) {
                    log_to_file (@"unable to read result length: $(err.message)");
                }

                var message_content_length = get_message_content_length (message_length_bytes);
                log_to_file (@"message length: $message_content_length");

                try {
                    output_stream.write_bytes (message_length_bytes);
                    output_stream.write_bytes (input_stream.read_bytes (message_content_length));
                    output_stream.flush ();
                } catch (Error err) {
                    log_to_file (@"unable to write to stream: $(err.message)");
                }
            }

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

    }

    public static int main (string[] args) {
        Log.set_writer_func (Log.writer_journald);

        Intl.setlocale ();

        var owner_id = 0U;
        var loop = new MainLoop (null, false);
        var sigterm_source = new Unix.SignalSource (Posix.Signal.TERM);

        sigterm_source.set_callback (() => {
            if (owner_id != 0U)
                Bus.unown_name (owner_id);

            loop.quit ();

            return Source.CONTINUE;
        });
        sigterm_source.attach ();

        Bus.own_name (BusType.SESSION, "com.paysonwallach.synapse_firefox.connector", BusNameOwnerFlags.NONE,
            (connection) => {
                try {
                    debug ("acquiring name");
                    connection.register_object ("/com/paysonwallach/synapse_firefox/connector", new DBusServer ());
                } catch (IOError err) {
                    error (err.message);
                }
            },
            () => {},
            () => { error ("could not acquire name"); });

        loop.run ();

        return 0;
    }
}

-type socket_type() :: [ssh | tcp].

%-record(socket, {type :: socket_type(), socket :: [inet:socket() | ssh_connection:ssh_connection_ref()], channel=undefined ::ssh_connection:ssh_channel_id()}).

-record(emqtt_socket, {type, connection, channel=undefined}).

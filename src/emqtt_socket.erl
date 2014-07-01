-module(emqtt_socket).

-export([send/2, recv/2, recv/3, close/1, controlling_process/2]).

-include("emqtt_net.hrl").

send(#emqtt_socket{type=tcp, connection = Conn} = Socket, Packet) ->
    gen_tcp:send(Conn, Packet);

send(#emqtt_socket{type=ssh, connection = Conn, channel = Channel} = Socket, Packet) ->
    emqtt_ssh_socket:send(Conn, Channel, Packet).

recv(#emqtt_socket{type=tcp, connection = Conn} = Socket, Length) -> 
    recv(Socket, Length, 0);

recv(#emqtt_socket{type=ssh, connection = Conn, channel = Channel} = Socket, Length) ->
    recv(Socket, Length, 0).
 
recv(#emqtt_socket{type=tcp, connection = Conn} = Socket, Length, Timeout) -> 
    gen_tcp:recv(Conn, Length, Timeout);

recv(#emqtt_socket{type=ssh, connection = Conn, channel = Channel} = Socket, Length, Timeout) ->
    %will call the receive from the emqtt_ssh_socket
    emqtt_ssh_socket:recv(Conn, Channel, Length, Timeout).

close(#emqtt_socket{type=tcp, connection = Conn} = Socket) ->
    gen_tcp:close(Conn);

close(#emqtt_socket{type=ssh, connection = Conn, channel = Channel} = Socket) ->
    emqtt_ssh_socket:close(Conn, Channel).
    %ssh_connection:close(Conn, Channel).

controlling_process(#emqtt_socket{type=tcp, connection = Conn} = Socket, Pid) ->
    gen_tcp:controlling_process(Conn, Pid);

% There is no reason to do this for the 
controlling_process(#emqtt_socket{type=ssh} = Socket, Pid) ->
    ok.

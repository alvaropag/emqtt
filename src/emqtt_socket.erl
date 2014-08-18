%%%-------------------------------------------------------------------
%%% @author Alvaro Pagliari <alvaro@alvaro-vaio>
%%% @copyright (C) 2014, Alvaro Pagliari
%%% @doc
%%%
%%% @end
%%% Created :  8 Jul 2014 by Alvaro Pagliari <alvaro@alvaro-vaio>
%%%-------------------------------------------------------------------
-module(emqtt_socket).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).


-export([send/2, close/1]).

-export([forward_data_to_client/3, forward_error_to_client/3, forward_closed_to_client/2, forward_socket_to_client/2]).

-export([create_ssh_socket/2, create_tcp_socket/1]).


-include("emqtt_net.hrl").


-record(state, {cb_module, emqtt_socket}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link(?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([CBModule, Socket]) ->
    {ok, #state{cb_module = CBModule, emqtt_socket = Socket}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


send(#emqtt_socket{type=tcp, connection = Conn}, Packet) ->
    gen_tcp:send(Conn, Packet);

send(#emqtt_socket{type=ssh, connection = Conn, channel = Channel}, Packet) ->
    io:fwrite("Sending SSH Data to Connection ~p, Channel ~p~n", [Conn, Channel]),
    Ret = ssh_connection:send(Conn, Channel, 0, Packet, 10000),
    io:fwrite("Return of SSH Send Data ~p~n", [Ret]),
    Ret.

%recv(#emqtt_socket{type=tcp, connection = Conn} = Socket, Length) -> 
%    recv(Socket, Length, 0);

%recv(#emqtt_socket{type=ssh, connection = Conn, channel = Channel} = Socket, Length) ->
%    recv(Socket, Length, 0).
 
%recv(#emqtt_socket{type=tcp, connection = Conn} = Socket, Length, Timeout) -> 
%    gen_tcp:recv(Conn, Length, Timeout);

%recv(#emqtt_socket{type=ssh, connection = Conn, channel = Channel} = Socket, Length, Timeout) ->
    %will call the receive from the emqtt_ssh_socket
%    emqtt_ssh_socket:recv(Conn, Channel, Length, Timeout).

close(#emqtt_socket{type=tcp, connection = Conn}) ->
    io:fwrite("emqtt_socket:close(tcp, ~p) closed", [Conn]),
    gen_tcp:close(Conn);

close(#emqtt_socket{type=ssh, connection = Conn, channel = Channel}) ->
    %emqtt_ssh_socket:close(Conn, Channel).
    ssh_connection:close(Conn, Channel).

%setopts(#emqtt_socket{type = tcp, connection = Conn} = Socket, Options) ->
%    inet:setopts(Conn, Options);

%setopts(#emqtt_socket{type = ssh} = Socket, Options) -> 
%    ok. 

forward_data_to_client(ClientPid, Data,  EmqttSocket) ->
    gen_server:cast(ClientPid, {data, Data, EmqttSocket}).

forward_error_to_client(ClientPid, Reason, EmqttSocket) ->
    gen_server:cast(ClientPid, {error, Reason, EmqttSocket}).

forward_closed_to_client(ClientPid, EmqttSocket) ->
    gen_server:cast(ClientPid, {closed, EmqttSocket}).

forward_socket_to_client(ClientPid, EmqttSocket) ->
    gen_server:cast(ClientPid, {emqtt_socket, EmqttSocket}).

create_ssh_socket(ConnectionManager, ChannelId) ->
    #emqtt_socket{type = shh, connection = ConnectionManager, channel = ChannelId}.

create_tcp_socket(Socket) ->
    #emqtt_socket{type = tcp, connection = Socket}.

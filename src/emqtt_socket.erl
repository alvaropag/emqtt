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

%% removed from the export 
%% -export([send/2, close/1, recv/2, recv/3, controlling_process/2]).

-include("emqtt_net.hrl").


%% -record(state, {}).

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
init([]) ->
    {ok, #emqtt_socket{}}.

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

% There is no reason to do this for the SSH... we never use the socket, always the channel
controlling_process(#emqtt_socket{type=ssh} = Socket, Pid) ->
    ok.

setopts(#emqtt_socket{type = tcp, connection = Conn} = Socket, Options) ->
    inet:setopts(Conn, Options);

setopts(#emqtt_socket{type = ssh} = Socket, Options) -> 
    ok. 


%%%-------------------------------------------------------------------
%%% @author Alvaro Pagliari <alvaro@alvaro-vaio>
%%% @copyright (C) 2014, Alvaro Pagliari
%%% @doc
%%%
%%% @end
%%% Created : 10 Jul 2014 by Alvaro Pagliari <alvaro@alvaro-vaio>
%%%-------------------------------------------------------------------
-module(emqtt_tcp_socket).

-behaviour(gen_server).

%% API
-export([start_link/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-export([go/1]).

-define(SERVER, ?MODULE).

-include("emqtt_net.hrl").

-record(state, {emqtt_client_pid = undefined, emqtt_socket}).

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
start_link(EmqttClientPid, Socket) ->
    gen_server:start_link(?MODULE, [EmqttClientPid, Socket], []).

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
init([EmqttClientPid, Socket]) ->
    gen_server:cast(EmqttClientPid, {emqtt_socket, Socket}),
    {ok, #state{emqtt_client_pid = EmqttClientPid, emqtt_socket = Socket}}.


go(Pid) ->
    gen_server:cast(Pid, activate_socket).
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
%handle_cast(loop, State) ->
%    loop_receive(State);

handle_cast(activate_socket, #state{emqtt_socket = EmqttSocket} = State) ->
    Socket = EmqttSocket#emqtt_socket.connection,
    inet:setopts(Socket, [{active, once}]),
    {noreply, State};

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
%handle_info(

handle_info({tcp, S, Data}, #state{emqtt_socket = EmqttSocket, emqtt_client_pid = EClientPid} = State) ->
    %verify if the socket from the callback is the same socket that is in the State, just for safety
    #emqtt_socket{type = tcp, connection = S} = EmqttSocket,
    emqtt_socket:forward_data_to_client(EClientPid, Data, EmqttSocket),
    inet:setopts(S, [{active, once}]),
    {noreply, State};

handle_info({tcp_closed, S}, #state{emqtt_socket = EmqttSocket, emqtt_client_pid = EClientPid} = State) ->
    io:fwrite("emqtt_tcp_socket:handle_info({tcp_closed, ~p}) ~n", [S]),
    #emqtt_socket{type = tcp, connection = S} = EmqttSocket,
    emqtt_socket:forward_closed_to_client(EClientPid, EmqttSocket),
    {stop, shutdown, State};

handle_info({tcp_error, S, Reason}, #state{emqtt_socket = EmqttSocket, emqtt_client_pid = EClientPid} = State) ->
    io:fwrite("emqtt_tcp_socket:handle_info({tcp_error, ~p, ~p}) ~n", [S, Reason]),
    #emqtt_socket{type = tcp, connection = S} = EmqttSocket,
    emqtt_socket:forward_error_to_client(EClientPid, Reason, EmqttSocket),
    {stop, {tcp_error, Reason}, State};

handle_info(_Info, State) ->
    io:fwrite("emqtt_tcp_socket:handle_info(_Info, State) = (~p, ~p)~n", [_Info, State]),
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

%loop_receive(#state{emqtt_client_pid = EClientPid, emqtt_socket = EmqttSocket} = State) ->
    %recover tcp socket from emqtt_socket record
%    #emqtt_socket{type = tcp, connection = Socket} = EmqttSocket,

    %ask for one packet of data from the socket...
%    ok = inet:setopts(Socket, [{active, once}]),

%    io:fwrite("Inside loop_receive on emqtt_tcp_socket, waiting for data~n"),

    %forward the data/error/status to the emqtt_client process
%    receive
%        {tcp, S, Data} ->
%            emqtt_socket:forward_data_to_client(EClientPid, Data, EmqttSocket),
%	    gen_server:cast(self(), loop),
%            {noreply, State};
%        {tcp_closed, S} -> 
%            emqtt_socket:forward_closed_to_client(EClientPid, EmqttSocket),
%	    io:fwrite("Connection closed on socket = ~p ~n", [S]),
%            {stop, normal, State};
%	{tcp_error, S, Reason} -> 
%            emqtt_socket:forward_error_to_client(EClientPid, Reason, EmqttSocket),
%            {stop, Reason, State}
%    end.

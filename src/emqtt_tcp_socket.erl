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
    %inet:setopts(Socket, {active, once}),
    %gen_server:cast(self(), loop),
    gen_server:cast(EmqttClientPid, {emqtt_socket, Socket}),
    {ok, #state{emqtt_client_pid = EmqttClientPid, emqtt_socket = Socket}}.


go(Pid) ->
    gen_server:cast(Pid, loop).
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
handle_cast(loop, State) ->
    loop_receive(State);

%handle_cast({emqtt_client_pid, Pid}, State) ->
%    {noreply, State#state{emqtt_client_pid = Pid});

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

loop_receive(#state{emqtt_client_pid = EQPid, emqtt_socket = EmqttSocket} = State) ->
    %recover tcp socket from emqtt_socket record
    #emqtt_socket{type = tcp, connection = Socket} = EmqttSocket,

    %ask for one packet of data from the socket...
    inet:setopts(Socket, {active, once}),

    %forward the data/error/status to the emqtt_client process
    receive
        {tcp, S, Data} ->
	    gen_server:cast(EQPid, {data, Data, EmqttSocket}),
	    gen_server:cast(self(), loop);
        {tcp_closed, S} -> 
	    gen_server:cast(EQPid, {closed, EmqttSocket}),
            ok;
	{tcp_error, S, Reason} -> 
	    gen_server:cast(EQPid, {error, Reason, EmqttSocket}),
	    ok
    end,
    {noreply, State}.

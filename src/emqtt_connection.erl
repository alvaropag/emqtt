%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License at
%% http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%% License for the specific language governing rights and limitations
%% under the License.
%%
%% The Original Code is eMQTT
%%
%% The Initial Developer of the Original Code is <ery.lee at gmail dot com>
%% Copyright (C) 2012 Ery Lee All Rights Reserved.

-module(emqtt_connection).

-behaviour(gen_server2).

-export([start_link/0, info/1]). %go/2

-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
        code_change/3,
	terminate/2]).

-include("emqtt.hrl").

-include("emqtt_frame.hrl").

-include("emqtt_internal.hrl").

-include("emqtt_net.hrl").

-include("emqtt_connection.hrl").

-include_lib("elog/include/elog.hrl").


start_link() ->
    gen_server2:start_link(?MODULE, [], []).

go(Pid, Sock) ->
	gen_server2:call(Pid, {go, Sock}).

info(Pid) ->
	gen_server2:call(Pid, info).

init([]) ->
    io:fwrite("emqtt_connection:init([]) function~n"),
    process_flag(trap_exit, true),
    {ok, 
     #emqtt_connection_state{parse_state = emqtt_frame:initial_state(), 
	    message_id = 1, 
	    subtopics = [], 
	    awaiting_ack = gb_trees:empty(), 
	    awaiting_rel = gb_trees:empty()}, 
     hibernate, {backoff, 1000, 1000, 10000}}.

handle_call(info, _From, #emqtt_connection_state{conn_name=ConnName, 
	message_id=MsgId, client_id=ClientId} = State) ->
	Info = [{conn_name, ConnName},
			{message_id, MsgId},
			{client_id, ClientId}],
	{reply, Info, State}.

handle_cast({emqtt_socket, Socket}, State)->
    emqtt_connection_monitor:mon(self()),
    {ok, ConnStr} = emqtt_net:conn_string(Socket, inbound),
    ?INFO("accepting connection (~p) from emqtt_socket ~n", [ConnStr]),
    {noreply, State#emqtt_connection_state{emqtt_socket = Socket, conn_name = ConnStr}};


handle_cast({data, Data, Socket}, State) ->
    process_received_bytes(Data, State);

handle_cast({error, Reason, Socket}, State) ->
    network_error(Reason, State);

handle_cast({closed, Socket}, State) ->

    {stop, closed, State};

handle_cast(Msg, State) ->
    {stop, {badmsg, Msg}, State}.

handle_info({route, Msg}, State) ->
    emqtt_protocol:process_route(Msg, State);

handle_info(keep_alive_timeout, #emqtt_connection_state{keep_alive=KeepAlive}=State) ->
    case emqtt_keep_alive:state(KeepAlive) of
        idle ->
            ?INFO("keep alive timeout: ~p", [State#emqtt_connection_state.conn_name]),
            {stop, normal, State};
	active ->
            KeepAlive1 = emqtt_keep_alive:reset(KeepAlive),
            {noreply, State#emqtt_connection_state{keep_alive=KeepAlive1}}
    end;


handle_info(Info, State) ->
	{stop, {badinfo, Info}, State}.

terminate(_Reason, #emqtt_connection_state{client_id=ClientId, keep_alive=KeepAlive}) ->
    ok = emqtt_registry:unregister(ClientId),
	emqtt_keep_alive:cancel(KeepAlive),
	ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%----------------------------------------------------------------------------
	
throw_on_error(E, Thunk) ->
    case Thunk() of
	{error, Reason} -> throw({E, Reason});
	{ok, Res}       -> Res;
	Res             -> Res
    end.

network_error(Reason,
              State = #emqtt_connection_state{ conn_name  = ConnStr}) ->
    ?INFO("MQTT detected network error '~p' for ~p", [Reason, ConnStr]),
    send_will_msg(State),
    % todo: flush channel after publish
    stop({shutdown, conn_closed}, State).

stop(Reason, State ) ->
    {stop, Reason, State}.

process_received_bytes(<<>>, State) ->
    {noreply, State};

process_received_bytes(Bytes,
                       State = #emqtt_connection_state{ parse_state = ParseState,
                                       conn_name   = ConnStr }) ->
	?INFO("~p~n", [Bytes]),
    case emqtt_frame:parse(Bytes, ParseState) of
	{more, ParseState1} ->
		{noreply,
		 State#emqtt_connection_state{ parse_state = ParseState1},
		 hibernate};
	{ok, Frame, Rest} ->
		case emqtt_protocol:process_frame(Frame, State) of
		{ok, State1} ->
			PS = emqtt_frame:initial_state(),
			process_received_bytes(
			  Rest,
			  State1#emqtt_connection_state{ parse_state = PS});
		{err, Reason, State1} ->
			?ERROR("MQTT protocol error ~p for connection ~p~n", [Reason, ConnStr]),
			stop({shutdown, Reason}, State1);
		{stop, State1} ->
			stop(normal, State1)
		end;
	{error, Error} ->
		?ERROR("MQTT detected framing error ~p for connection ~p~n", [ConnStr, Error]),
		stop({shutdown, Error}, State)
    end.


send_will_msg(#emqtt_connection_state{will_msg = undefined}) ->
	ignore;
send_will_msg(#emqtt_connection_state{will_msg = WillMsg }) ->
	emqtt_router:publish(WillMsg).

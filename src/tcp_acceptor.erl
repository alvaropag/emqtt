%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is VMware, Inc.
%% Copyright (c) 2007-2012 VMware, Inc.  All rights reserved.
%%

-module(tcp_acceptor).

-behaviour(gen_server).

-include_lib("emqtt_net.hrl").

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {callback, sock}).

%%--------------------------------------------------------------------

start_link(Callback, LSock) ->
    gen_server:start_link(?MODULE, {Callback, LSock}, []).

%%--------------------------------------------------------------------

init({Callback, LSock}) ->
    gen_server:cast(self(), accept),
    {ok, #state{callback=Callback, sock=LSock}}.

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_cast(accept, State) ->
    %ok = file_handle_cache:obtain(),
    accept(State);

handle_cast(_Msg, State) ->
    {noreply, State}.

%handle_info({inet_async, LSock, Ref, {ok, Sock}},
%            State = #state{callback={M,F,A}, sock=LSock}) ->

    %% patch up the socket so it looks like one we got from
    %% gen_tcp:accept/1
%    {ok, Mod} = inet_db:lookup_socket(LSock),
%    inet_db:register_socket(Sock, Mod),

   
    %% handle
%    file_handle_cache:transfer(apply(M, F, A ++ [Sock])),
%    ok = file_handle_cache:obtain(),

    %% accept more
%    accept(State);

%handle_info({inet_async, LSock, Ref, {error, closed}},
%            State=#state{sock=LSock, ref=Ref}) ->
    %% It would be wrong to attempt to restart the acceptor when we
    %% know this will fail.
%    {stop, normal, State};

%handle_info({inet_async, LSock, Ref, {error, Reason}},
%            State=#state{sock=LSock, ref=Ref}) ->
%    {stop, {accept_failed, Reason}, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------

accept(State = #state{callback={M,F,A}, sock=LSock}) ->
    case gen_tcp:accept(LSock, infinity) of
        {ok, Socket} -> 
	   %%Start the emqtt_tcp_socket, this has to be put in another function....
	   io:fwrite("Creating a new socket on tcp_acceptor:accept/1~n"),

	   %%Start the emqtt_client
           io:fwrite("tcp_acceptor:callback={~p, ~p, ~p)~n", [M, F, A]),
	   EmqttClientPid = apply(M, F, A), %emqtt_client_sup, start_client, []),
	   io:fwrite("Creating emqtt_client with pid = ~p~n", [EmqttClientPid]),

	   EmqttSocketRecord = emqtt_socket:create_tcp_socket(Socket),
	   io:fwrite("Definig record emqtt_socket~n"),

	   {ok, {Address, Port}} = inet:peername(Socket),

	   ChildSpec = emqtt_socket_sup:child_spec(tcp, emqtt_net:tcp_name(tcp, Address, Port), EmqttClientPid, EmqttSocketRecord),

            {ok, SocketPid} = supervisor:start_child(emqtt_socket_sup, ChildSpec),
	    io:fwrite("Creating emqtt_tcp_socket with Pid = ~p ~n", [SocketPid]),

	    ok = gen_tcp:controlling_process(Socket, SocketPid),
	    io:fwrite("Passing socket controller to SocketPid = ~p~n", [SocketPid]),

	    emqtt_tcp_socket:go(SocketPid),
	    io:fwrite("Starting emqtt_tcp_socket~n"),

            %loop to this function
	    gen_server:cast(self(), accept),

	    {noreply, State};  %%Return for the cast function
        Error     -> {stop, {cannot_accept, Error}, State}
    end.

%%%-------------------------------------------------------------------
%%% @author Alvaro Pagliari <alvaro@alvaro-vaio>
%%% @copyright (C) 2014, Alvaro Pagliari
%%% @doc
%%%
%%% @end
%%% Created : 18 Jul 2014 by Alvaro Pagliari <alvaro@alvaro-vaio>
%%%-------------------------------------------------------------------
-module(emqtt_ssh_daemon_sup).

-behaviour(supervisor).

%% API
-export([start_link/3]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(IPAddress, Port, DaemonOptions) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, [IPAddress, Port, DaemonOptions]).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @spec init(Args) -> {ok, {SupFlags, [ChildSpec]}} |
%%                     ignore |
%%                     {error, Reason}
%% @end
%%--------------------------------------------------------------------
init([IPAddress, Port, DaemonOptions]) ->
    RestartStrategy = one_for_one,
    MaxRestarts = 10,
    MaxSecondsBetweenRestarts = 10,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    {ok, {SupFlags, [child_spec(IPAddress, Port, DaemonOptions)]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

child_spec(IPAddress, Port, DaemonOpts) ->
    {ssh_id_child(IPAddress, Port), {emqtt_ssh_daemon, start_link, [IPAddress, Port, DaemonOpts]}, transient, 5000, worker, [emqtt_ssh_daemon]}.

ssh_id_child(IPAddress, Port) ->
    list_to_atom(lists:flatten(io_lib:format("ssh_daemon_~s:~w",[inet_parse:ntoa(IPAddress), Port]))).

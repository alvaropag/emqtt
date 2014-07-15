-module(emqtt_socket_sup).

-behaviour(supervisor).

-export([init/1]).

-export([start_link/0]).%, start_child/3, start_child/4]).

-include("emqtt_net.hrl").



start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%start_child_spec(Type = tcp, EmqttClientPid, Socket) ->
%    {ok, {emqtt_net:tcp_name,
 %  supervisor:start_child(?MODULE, {EmqttClientPid, #emqtt_socket{type = Type, connection = Socket}});

%start_child_spec(Type = ssh, EmqttClientPid, ConnectionRef, ChannelId) ->
%    ok.
    %supervisor:start_link(?MODULE, {EmqttClientPid, #emqtt_socket{type = Type, connection = ConnectionRef, channel_id = ChannelId}).

init([]) ->
    {ok, {{one_for_one, 1, 3600}, []}}.

    


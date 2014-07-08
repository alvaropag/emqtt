-module(emqtt_ssh_socket_subsystem).

-behaviour(ssh_daemon_channel).

-export([subsystem_spec/1]).
-export([init/1, handle_ssh_msg/2, handle_msg/2, terminate/2, handle_data/3]).

-include("emqtt_net.hrl").

-record(state, {cm,         %% Connection _ConnectionManager
		channel_id, %% Channel ID
		buffer}     %% Buffer for the received data... 
       ).


%%The subsystem spec is a name for your subsystem, it MUST have a '@' signal in the name
subsystem_spec(Options) ->
    {?SSH_SOCKET_SUBSYSTEM, {?MODULE, Options}}.
init(Options) ->
  State = #state{},
  {ok, State}.
  

%% Type = 1 ("stderr") | 0 ("normal") 
handle_ssh_msg({ssh_cm, _ConnectionManager,
		{data, _ChannelId, Type, Data}}, State) ->
    error_logger:info_msg("ssh_cm.data, ConnectionManager=~p, ChannelId=~p, Type=~p, Data=~s, State=~p~n", [_ConnectionManager, _ChannelId, Type, Data, State]),
    State1 = handle_data(Type, Data, State),
    {ok, State1};

handle_ssh_msg({ssh_cm, _, {eof, ChannelId}}, State) ->
    error_logger:info_msg("ssh_cm.eof, ChannelId=~p, State=~p~n", [ChannelId, State]),
    {stop, ChannelId, State};

handle_ssh_msg({ssh_cm, _, {signal, _, _}}, State) ->
    %% Ignore signals according to RFC 4254 section 6.9.
    error_logger:info_msg("ssh_cm.signal, State=~p~n", [State]),
    {ok, State};
 
handle_ssh_msg({ssh_cm, _, {exit_signal, ChannelId, _, Error, _}}, State) ->
    Report = io_lib:format("Connection closed by peer ~n Error ~p~n",
			   [Error]),
    error_logger:error_report(Report),
    {stop, ChannelId,  State};

handle_ssh_msg({ssh_cm, _, {exit_status, ChannelId, 0}}, State) ->
    error_logger:info_msg("ssh_cm.exit, ChannelId=~p, State=~p~n", [ChannelId, State]),
    {stop, ChannelId, State};

handle_ssh_msg({ssh_cm, _, {exit_status, ChannelId, Status}}, State) ->
    
    Report = io_lib:format("Connection closed by peer ~n Status ~p~n",
			   [Status]),
    error_logger:error_report(Report),
    {stop, ChannelId, State}.

handle_msg({ssh_channel_up, ChannelId, ConnectionManager}, State) ->
    error_logger:info_msg("ssh_channel_up, ChannelId=~p, ConnectioManager=~p, State=~p~n", [ChannelId, ConnectionManager, State]),
    {ok, #state{channel_id = ChannelId,
		     cm = ConnectionManager}}.    
		     
handle_data(Type, Data, #state{cm=CM, channel_id=ChId, buffer=Buffer} = State) ->
    State#state{buffer = <<Buffer/binary, Data/binary>>}.

terminate(Reason, State) ->
    error_logger:info_msg("terminate, Reason=~p, State=~p~n", [Reason, State]),
    ok. 

recv(State) ->  
    Data = State#state.buffer,
    #state{cm = State#state.cm, channel_id = State#state.channel_id, buffer = <<>>}.



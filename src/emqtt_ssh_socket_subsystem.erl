-module(emqtt_ssh_socket_subsystem).

-behaviour(ssh_daemon_channel).

-export([subsystem_spec/1]).
-export([init/1, handle_ssh_msg/2, handle_msg/2, terminate/2]).

-include("emqtt_net.hrl").

-record(state, {cm,         %% Connection _ConnectionManager
		channel_id, %% Channel ID
                emqtt_client_pid, %% Pid of the process to send data to
                emqtt_socket      %% Socket for the emqtt_client
               } 
       ).


%%The subsystem spec is a name for your subsystem, it MUST have a '@' signal in the name
subsystem_spec(Options) ->
    {?SSH_SOCKET_SUBSYSTEM, {?MODULE, Options}}.

init(Options) ->
  State = #state{},
  {ok, State}.
  

%% Type = 1 ("stderr") | 0 ("normal") 
handle_ssh_msg({ssh_cm, _ConnectionManager,
		{data, _ChannelId, Type, Data}}, #state{emqtt_client_pid = EClientPid, emqtt_socket = EmqttSocket} = State) ->
    error_logger:info_msg("ssh_cm.data, ConnectionManager=~p, ChannelId=~p, Type=~p, Data=~s, State=~p~n", [_ConnectionManager, _ChannelId, Type, Data, State]),
    emqtt_socket:forward_data_to_client(EClientPid, Data, EmqttSocket),
    {ok, State};

handle_ssh_msg({ssh_cm, _, {eof, ChannelId}}, State) ->
    error_logger:info_msg("ssh_cm.eof, ChannelId=~p, State=~p~n", [ChannelId, State]),
    {stop, ChannelId, State};

handle_ssh_msg({ssh_cm, _, {signal, _, _}}, State) ->
    %% Ignore signals according to RFC 4254 section 6.9.
    error_logger:info_msg("ssh_cm.signal, State=~p~n", [State]),
    {ok, State};
 
handle_ssh_msg({ssh_cm, _, {exit_signal, ChannelId, _, Error, _}}, #state{emqtt_client_pid = EClientPid, emqtt_socket = EmqttSocket} = State) ->
    Report = io_lib:format("Connection closed by peer ~n Error ~p~n",
			   [Error]),
    error_logger:error_report(Report),
    emqtt_socket:forward_error_to_client(EClientPid, Error, EmqttSocket),
    {stop, ChannelId,  State};

% Return the exit status of a given command execution, not used 
handle_ssh_msg({ssh_cm, _, {exit_status, ChannelId, 0}}, State) ->
    error_logger:info_msg("ssh_cm.exit, ChannelId=~p, State=~p~n", [ChannelId, State]),
    {stop, ChannelId, State};

handle_ssh_msg({ssh_cm, _, {exit_status, ChannelId, Status}}, #state{emqtt_client_pid = EClientPid, emqtt_socket = EmqttSocket} = State) ->
    
    Report = io_lib:format("Connection closed by peer ~n Status ~p~n",
			   [Status]),
    error_logger:error_report(Report),
    emqtt_socket:forward_closed_to_client(EClientPid, EmqttSocket),
    {stop, ChannelId, State};

handle_ssh_msg({ssh_cm, _, {closed, ChannelId}}, #state{emqtt_client_pid = EClientPid, emqtt_socket = EmqttSocket} = State) ->
    emqtt_socket:forward_closed_to_client(EClientPid, EmqttSocket),
    {stop, ChannelId, State}.


% Starts the EmqttClient so that it can begin sending data...
handle_msg({ssh_channel_up, ChannelId, ConnectionManager}, State) ->
    error_logger:info_msg("ssh_channel_up, ChannelId=~p, ConnectioManager=~p, State=~p~n", [ChannelId, ConnectionManager, State]),
    %% Create the socket for emqtt client
    EmqttSocket = #emqtt_socket{type = ssh, connection = ConnectionManager, channel = ChannelId},
    
    %% Start the emqtt client
    {ok, EClientPid} = emqtt_client_sup:start_client(),

    %% Send the socket to the emqtt_client
    emqtt_socket:forward_socket_to_client(EClientPid, EmqttSocket),

    %% Return the state
    {ok, #state{channel_id = ChannelId,
		cm = ConnectionManager, 
                emqtt_client_pid = EClientPid, 
                emqtt_socket = EmqttSocket}}.    
		     
terminate(Reason, State) ->
    error_logger:info_msg("terminate, Reason=~p, State=~p~n", [Reason, State]),
    ok. 


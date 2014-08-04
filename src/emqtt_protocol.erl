-module(emqtt_protocol).

-include("emqtt.hrl").
-include("emqtt_connection.hrl").
-include("emqtt_frame.hrl").

-include_lib("elog/include/elog.hrl").

-export([process_frame/2, process_route/2]).


process_frame(Frame = #mqtt_frame{fixed = #mqtt_frame_fixed{type = Type}},
              State=#emqtt_connection_state{client_id=ClientId, keep_alive=KeepAlive}) ->
    KeepAlive1 = emqtt_keep_alive:activate(KeepAlive),
    case validate_frame(Type, Frame) of	
	ok ->
            ?INFO("frame from ~s: ~p", [ClientId, Frame]),
            handle_retained(Type, Frame),
            process_request(Type, Frame, State#emqtt_connection_state{keep_alive=KeepAlive1});
	{error, Reason} ->
            {err, Reason, State}
    end.


process_route(Msg, #emqtt_connection_state{emqtt_socket = Sock, message_id=MsgId} = State) ->
    #mqtt_msg{retain     = Retain,
              qos        = Qos,
              topic      = Topic,
              dup        = Dup,
              payload    = Payload,
              encoder 	 = Encoder} = Msg,

    Payload1 = 
        if 
            Encoder == undefined -> Payload;
            true -> Encoder(Payload)
	end,

    Frame = #mqtt_frame{
               fixed = #mqtt_frame_fixed{type 	 = ?PUBLISH,
                                         qos    = Qos,
                                         retain = Retain,
                                         dup    = Dup},
               variable = #mqtt_frame_publish{topic_name = Topic,
                                              message_id = if
                                                               Qos == ?QOS_0 -> undefined;
                                                               true -> MsgId
                                                           end},
               payload = Payload1},
    send_frame(Sock, Frame),

    if
        Qos == ?QOS_0 -> {noreply, State};
        true          -> {noreply, next_msg_id(State)}
    end.


process_request(?CONNECT,
                #mqtt_frame{variable = #mqtt_frame_connect{
                     username   = Username,
                     password   = Password,
                     proto_ver  = ProtoVersion,
                     clean_sess = CleanSess,
                     keep_alive = AlivePeriod,
                     client_id  = ClientId } = Var}, 
                #emqtt_connection_state{emqtt_socket = Sock} = State) ->

    {ReturnCode, State1} =
        case {ProtoVersion =:= ?MQTT_PROTO_MAJOR,
              valid_client_id(ClientId)} of
            {false, _} ->
                {?CONNACK_PROTO_VER, State};
            {_, false} ->
                {?CONNACK_INVALID_ID, State};
            _ ->
                case emqtt_auth:check(Username, Password) of
                    false ->
                        ?ERROR_MSG("MQTT login failed - no credentials"),
                        {?CONNACK_CREDENTIALS, State};
                    true ->
			?INFO("connect from clientid: ~s, ~p", [ClientId, AlivePeriod]),
			ok = emqtt_registry:register(ClientId, self()),
			KeepAlive = emqtt_keep_alive:new(AlivePeriod*1500, keep_alive_timeout),
			{?CONNACK_ACCEPT,
                         State#emqtt_connection_state{ will_msg   = make_will_msg(Var),
                                                   client_id  = ClientId,
                                                   keep_alive = KeepAlive}}
                end
        end,
    %If there is need for a queue (client is authenticated and not want a CleanSess) 
    %then create one, register in gproc and saves in the State Variable
   SessionState = verifyNeedOfSession(ClientId, ReturnCode =:= ?CONNACK_ACCEPT, CleanSess),
        
    send_frame(Sock, #mqtt_frame{ fixed    = #mqtt_frame_fixed{ type = ?CONNACK},
                                  variable = #mqtt_frame_connack{
                                                return_code = ReturnCode }}),
    {ok, State1#emqtt_connection_state{emqtt_session_state = SessionState}};

process_request(?PUBLISH, Frame=#mqtt_frame{fixed = #mqtt_frame_fixed{qos = ?QOS_0}}, State) ->
	emqtt_router:publish(make_msg(Frame)),
	{ok, State};

process_request(?PUBLISH,
                Frame=#mqtt_frame{
                  fixed = #mqtt_frame_fixed{qos    = ?QOS_1},
                  variable = #mqtt_frame_publish{message_id = MsgId}}, 
				State=#emqtt_connection_state{emqtt_socket=Sock}) ->
	emqtt_router:publish(make_msg(Frame)),
	send_frame(Sock, #mqtt_frame{fixed = #mqtt_frame_fixed{ type = ?PUBACK },
							  variable = #mqtt_frame_publish{ message_id = MsgId}}),
	{ok, State};

process_request(?PUBLISH,
                Frame=#mqtt_frame{
                  fixed = #mqtt_frame_fixed{qos    = ?QOS_2},
                  variable = #mqtt_frame_publish{message_id = MsgId}}, 
				State=#emqtt_connection_state{emqtt_socket=Sock}) ->
	emqtt_router:publish(make_msg(Frame)),
	put({msg, MsgId}, pubrec),
	send_frame(Sock, #mqtt_frame{fixed = #mqtt_frame_fixed{type = ?PUBREC},
			  variable = #mqtt_frame_publish{ message_id = MsgId}}),

	{ok, State};

process_request(?PUBACK, #mqtt_frame{}, State) ->
	%TODO: fixme later
	{ok, State};

process_request(?PUBREC, #mqtt_frame{
	variable = #mqtt_frame_publish{message_id = MsgId}}, 
	State=#emqtt_connection_state{emqtt_socket=Sock}) ->
	%TODO: fixme later
	send_frame(Sock,
	  #mqtt_frame{fixed    = #mqtt_frame_fixed{ type = ?PUBREL},
				  variable = #mqtt_frame_publish{ message_id = MsgId}}),
	{ok, State};

process_request(?PUBREL,
                #mqtt_frame{
                  variable = #mqtt_frame_publish{message_id = MsgId}},
				  State=#emqtt_connection_state{emqtt_socket=Sock}) ->
	erase({msg, MsgId}),
	send_frame(Sock,
	  #mqtt_frame{fixed    = #mqtt_frame_fixed{ type = ?PUBCOMP},
				  variable = #mqtt_frame_publish{ message_id = MsgId}}),
	{ok, State};

process_request(?PUBCOMP, #mqtt_frame{
	variable = #mqtt_frame_publish{message_id = _MsgId}}, State) ->
	%TODO: fixme later
	{ok, State};

process_request(?SUBSCRIBE,
    #mqtt_frame{
       variable = #mqtt_frame_subscribe{message_id  = MessageId, topic_table = Topics},
           payload = undefined},
        #emqtt_connection_state{emqtt_socket=Sock} = State) ->

	[emqtt_router:subscribe({Name, Qos}, self()) || 
			#mqtt_topic{name=Name, qos=Qos} <- Topics],

    GrantedQos = [Qos || #mqtt_topic{qos=Qos} <- Topics],

    send_frame(Sock, #mqtt_frame{fixed = #mqtt_frame_fixed{type = ?SUBACK},
								 variable = #mqtt_frame_suback{
											 message_id = MessageId,
											 qos_table  = GrantedQos}}),

    {ok, State};

process_request(?UNSUBSCRIBE,
                #mqtt_frame{
                  variable = #mqtt_frame_subscribe{message_id  = MessageId,
                                                   topic_table = Topics },
                  payload = undefined}, #emqtt_connection_state{emqtt_socket = Sock, client_id = ClientId} = State) ->

	
	[emqtt_router:unsubscribe(Name, self()) || #mqtt_topic{name=Name} <- Topics], 

    send_frame(Sock, #mqtt_frame{fixed = #mqtt_frame_fixed{type = ?UNSUBACK },
                             	 variable = #mqtt_frame_suback{message_id = MessageId }}),

    {ok, State};

process_request(?PINGREQ, #mqtt_frame{}, #emqtt_connection_state{emqtt_socket=Sock, keep_alive=KeepAlive}=State) ->
	%Keep alive timer
	KeepAlive1 = emqtt_keep_alive:reset(KeepAlive),
    send_frame(Sock, #mqtt_frame{fixed = #mqtt_frame_fixed{ type = ?PINGRESP }}),
    {ok, State#emqtt_connection_state{keep_alive=KeepAlive1}};

process_request(?DISCONNECT, #mqtt_frame{}, State=#emqtt_connection_state{emqtt_socket = EmqttSocket, client_id=ClientId}) ->
    ?INFO("~s disconnected", [ClientId]),
    %release the Queue if there is one...
    State1 = release_session(State),
    {stop, State1}.

next_msg_id(State = #emqtt_connection_state{ message_id = 16#ffff }) ->
    State #emqtt_connection_state{ message_id = 1 };
next_msg_id(State = #emqtt_connection_state{ message_id = MsgId }) ->
    State #emqtt_connection_state{ message_id = MsgId + 1 }.

maybe_clean_sess(false, _Conn, _ClientId) ->
    % todo: establish subscription to deliver old unacknowledged messages
    ok.

%%----------------------------------------------------------------------------


handle_retained(?PUBLISH, #mqtt_frame{fixed = #mqtt_frame_fixed{retain = false}}) ->
	ignore;

handle_retained(?PUBLISH, #mqtt_frame{
                  fixed = #mqtt_frame_fixed{retain = true},
                  variable = #mqtt_frame_publish{topic_name = Topic},
				  payload= <<>> }) ->
	emqtt_retained:delete(Topic);

handle_retained(?PUBLISH, Frame=#mqtt_frame{
                  fixed = #mqtt_frame_fixed{retain = true},
                  variable = #mqtt_frame_publish{topic_name = Topic}}) ->
	emqtt_retained:insert(Topic, make_msg(Frame));

handle_retained(_, _) -> 
	ignore.

validate_frame(?PUBLISH, #mqtt_frame{variable = #mqtt_frame_publish{topic_name = Topic}}) ->
	case emqtt_topic:validate({publish, Topic}) of
	true -> ok;
	false -> {error, badtopic}
	end;

validate_frame(?UNSUBSCRIBE, #mqtt_frame{variable = #mqtt_frame_subscribe{topic_table = Topics}}) ->
	ErrTopics = [Topic || #mqtt_topic{name=Topic, qos=Qos} <- Topics,
						not emqtt_topic:validate({subscribe, Topic})],
	case ErrTopics of
	[] -> ok;
	_ -> ?ERROR("error topics: ~p", [ErrTopics]), {error, badtopic}
	end;

validate_frame(?SUBSCRIBE, #mqtt_frame{variable = #mqtt_frame_subscribe{topic_table = Topics}}) ->
	ErrTopics = [Topic || #mqtt_topic{name=Topic, qos=Qos} <- Topics,
						not (emqtt_topic:validate({subscribe, Topic}) and (Qos < 3))],
	case ErrTopics of
	[] -> ok;
	_ -> ?ERROR("error topics: ~p", [ErrTopics]), {error, badtopic}
	end;

validate_frame(_Type, _Frame) ->
	ok.

make_msg(#mqtt_frame{
			  fixed = #mqtt_frame_fixed{qos    = Qos,
										retain = Retain,
										dup    = Dup},
			  variable = #mqtt_frame_publish{topic_name = Topic,
											 message_id = MessageId},
			  payload = Payload}) ->
	#mqtt_msg{retain     = Retain,
			  qos        = Qos,
			  topic      = Topic,
			  dup        = Dup,
			  message_id = MessageId,
			  payload    = Payload}.

send_frame(Sock, Frame) ->
    emqtt_socket:send(Sock, emqtt_frame:serialise(Frame)).

valid_client_id(ClientId) ->
    ClientIdLen = length(ClientId),
    1 =< ClientIdLen andalso ClientIdLen =< ?CLIENT_ID_MAXLEN.


make_will_msg(#mqtt_frame_connect{ will_flag   = false }) ->
    undefined;
make_will_msg(#mqtt_frame_connect{ will_retain = Retain,
                                   will_qos    = Qos,
                                   will_topic  = Topic,
                                   will_msg    = Msg }) ->
    #mqtt_msg{retain  = Retain,
              qos     = Qos,
              topic   = Topic,
              dup     = false,
              payload = Msg }.

                            %ClientAuthorized, CleanSess
verifyNeedOfSession(ClientId, true, false) ->
    Session = emqtt_session_state:new(application:get_env(emqtt, session_cb, emqtt_session_state_memory)),
    true = gproc:reg({n,l, ClientId}, Session),
    Session;

verifyNeedOfSession(_, _, _) ->
    undefined.
    
release_session(#emqtt_connection_state{client_id = ClientID, emqtt_session_state = Session} = State) ->
    case Session of
        undefined -> State;
        _ -> 
            emqtt_session_state:drop(Session),
            gproc:unreg(ClientID),
            State#emqtt_connection_state{emqtt_session_state = undefined}
    end.

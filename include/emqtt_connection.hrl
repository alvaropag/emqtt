-record(emqtt_connection_state, {
          emqtt_socket = undefined,
          conn_name,
          parse_state,
          message_id,
          client_id,
          clean_sess,
          will_msg,
          keep_alive, 
	  awaiting_ack,
          subtopics,
	  awaiting_rel,
          emqtt_session_state = undefined}).

-define(CLIENT_ID_MAXLEN, 23).

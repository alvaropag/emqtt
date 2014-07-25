-record(emqtt_client_state, {
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
	  awaiting_rel}).

-define(CLIENT_ID_MAXLEN, 23).

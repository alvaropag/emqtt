-record(emqtt_session_state, 
        {user_id, 
         msg_queue_ref = undefined, 
         session_cb = undefined, 
         subscriptions = [],
         size = 0}).

-module(emqtt_session_state_memory).

-include("emqtt_session_state.hrl").

-export([
         new/1,
         id/1,
         in/2,
         out/1,
         peek/2,
         member_of/2,
         drop/1,
         subscribe/2,
         unsubscribe/2,
         subscriptions/1
         ]).
         

new(UserId) when is_binary(UserId) ->
    Queue = queue:new(),
    {ok, #emqtt_session_state{user_id = UserId, msg_queue_ref = Queue, size = 0}};

new(_) ->
    {error, "UserId must be binary"}.


id(#emqtt_session_state{user_id = UserId}) ->
    UserId;
id(_) ->
    {error, "Invalid UserId"}.


in(#emqtt_session_state{msg_queue_ref = QueueRef, size = Size} = State, Item) ->
    QueueRef2 = queue:in(Item, QueueRef),
    {ok, State#emqtt_session_state{msg_queue_ref = QueueRef2, size = Size + 1}};

in(_, _) ->
    {error, "Invalid queue handler"}.


out(#emqtt_session_state{size = 0} = State) ->
    {ok, {empty}, State};

out(#emqtt_session_state{msg_queue_ref = QueueRef, size = Size} = State) ->
    {{value, Item}, QueueRef2}  = queue:out(QueueRef),
    {ok, {value, Item}, State#emqtt_session_state{msg_queue_ref = QueueRef2, size = Size -1}};

out(_) ->
    {error, "Invalid queue handler"}.


peek(#emqtt_session_state{size = Size} = State, _) when Size == 0 ->
    {ok, {empty}, State};

peek(#emqtt_session_state{size = Size}, N) when Size < 0; is_integer(N); N =< 0 ->
    {error, "Invalid parameters"};

peek(#emqtt_session_state{msg_queue_ref = QueueRef, size = Size} = State, N) when Size > 0, is_integer(N), N > 0, N =< Size ->
    {Queue2, _} = queue:split(N, QueueRef),
    {ok, {value, queue:to_list(Queue2)}, State};

peek(_, _) ->
    {error, "Invalid queue handler"}.


member_of(#emqtt_session_state{size = 0} = State, _) ->
    {ok, {empty}, State};

member_of(#emqtt_session_state{msg_queue_ref = QueueRef} = State, Item) ->
    {ok, {queue:member(Item, QueueRef)}, State};

member_of(_, _) ->
    {error, "Invalid queue handler"}.

drop(_) ->
    ok.

subscribe(#emqtt_session_state{subscriptions = Subscriptions} = State, Path) when is_binary(Path) ->
    {ok, State#emqtt_session_state{subscriptions = Subscriptions ++ [Path]}};

subscribe(_, _) ->
    {error, "Path must be binary"}.

unsubscribe(#emqtt_session_state{subscriptions = Subscriptions} = State, Path) when is_binary(Path) ->
    {ok, State#emqtt_session_state{subscriptions = [Path] -- Subscriptions}};

unsubscribe(_, _) ->
    {error, "Path must be binary"}.

subscriptions(#emqtt_session_state{subscriptions = Subscriptions} = State) when Subscriptions == [] ->
    {ok, {empty}, State};

subscriptions(#emqtt_session_state{subscriptions = Subscriptions} = State) ->
    {ok, {Subscriptions}, State}.

    

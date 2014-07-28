-module(emqtt_queue_memory).

-include("emqtt_queue.hrl").

-export([
         new/1,
         id/1,
         in/2,
         out/1,
         peek/2,
         member_of/2,
         drop/1
         ]).
         

new(Queue_id) when is_binary(Queue_id) ->
    Queue = queue:new(),
    {ok, #emqtt_queue{queue_id = Queue_id, queue_ref = Queue, size = 0}};

new(_) ->
    {error, "Queue_id must be binary"}.


id(#emqtt_queue{queue_id = QueueId}) ->
    QueueId;
id(_) ->
    {error, "Invalid queue handler"}.


in(#emqtt_queue{queue_ref = QueueRef, size = Size} = Queue, Item) ->
    QueueRef2 = queue:in(Item, QueueRef),
    {ok, Queue#emqtt_queue{queue_ref = QueueRef2, size = Size + 1}};

in(_, _) ->
    {error, "Invalid queue handler"}.


out(#emqtt_queue{size = 0} = Queue) ->
    {ok, {empty}, Queue};

out(#emqtt_queue{queue_ref = QueueRef, size = Size} = Queue) ->
    {{value, Item}, QueueRef2}  = queue:out(QueueRef),
    {ok, {value, Item}, Queue#emqtt_queue{queue_ref = QueueRef2, size = Size -1}};

out(_) ->
    {error, "Invalid queue handler"}.


peek(#emqtt_queue{size = Size} = Queue, _) when Size == 0 ->
    {ok, {empty}, Queue};

peek(#emqtt_queue{size = Size}, N) when Size < 0; is_integer(N); N =< 0 ->
    {error, "Invalid parameters"};

peek(#emqtt_queue{queue_ref = QueueRef, size = Size} = Queue, N) when Size > 0, is_integer(N), N > 0, N =< Size ->
    {Queue2, _} = queue:split(N, QueueRef),
    {ok, {value, queue:to_list(Queue2)}, Queue};

peek(_, _) ->
    {error, "Invalid queue handler"}.


member_of(#emqtt_queue{size = 0} = Queue, _) ->
    {ok, {empty}, Queue};

member_of(#emqtt_queue{queue_ref = QueueRef} = Queue, Item) ->
    {ok, {queue:member(Item, QueueRef)}, Queue};

member_of(_, _) ->
    {error, "Invalid queue handler"}.

drop(_) ->
    ok.

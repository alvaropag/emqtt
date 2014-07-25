-module(emqtt_queue_memory).

-include("emqtt_queue.hrl").

%% new(id :: binary()) - {ok, queue_record} | {error, Reason}
%% size(queue_record) - {ok, ::integer()} | {error, Reason} 
%% id() - {ok, binary()} - returns the client_id associated
%% in(queue_item, Item) - ok | {error, Reason}
%% out(queue_record) - {ok, Item} | {error, Reason}
%% peek(queue_record, N) - {ok, [Item]} | {error, Reason} - return the first element of the list without removing it
%% drop_queue(queue_record) - ok | {error, Reason}
%% member_of(queue_record, Item) - ok | {error, Reason}

-export([
         new/1,
         id/1,
         in/2,
         out/2,
         peek/2,
         member_of/2
         ]}.
         

new(Queue_id) when is_binary(Queue_id) ->
    Queue = queue:new(),
    {ok, #emqtt_queue{queue_id = Queue_id, queue_ref = Queue, queue_cb = emqtt_queue_memory}};

new(_) ->
    {error, "Queue_id must be binary"}.


id(#emqtt_queue{queue_id = QueueId} = Queue) ->
    QueueId;
id(_) ->
    {error, "Invalid queue handler"}.


in(#emqtt_queue{queue_ref = QueueRef, size = Size} = Queue, Item) when is_queue(QueueRef)->
    QueueRef2 = queue:in(Item, QueueRef),
    {ok, Queue#emqtt_queue{queue_ref = QueueRef2, size = Size + 1}};

in(_, _) ->
    {error, "Invalid queue handler"}.


out(#emqtt_queue{queue_ref = QueueRef, size = 0} = Queue) when is_queue(QueueRef)  ->
    {ok, {empty}, Queue};

out(#emqtt_queue{queue_ref = QueueRef, size = Size} = Queue) when is_queue(QueueRef)  ->
    {{value, Item}, QueueRef2}  = queue:out(QueueRef),
    {ok, {value, Item}, Queue#emqtt_queue{queue_ref = QueueRef2, size = Size -1}};

out(_) ->
    {error, "Invalid queue handler"}.


peek(#emqtt_queue{queue_ref = QueueRef, size = Size} = Queue, N) when is_queue(QueueRef), Size = 0 ->
    {ok, {empty}, Queue};

peek(#emqtt_queue{queue_ref = QueueRef, size = Size} = Queue, N) when is_queue(QueueRef); Size <= 0 ; N <= 0 ->
    {error, "Invalid parameters"};

peek(#emqtt_queue{queue_ref = QueueRef, size = Size} = Queue, N) when is_queue(QueueRef), Size > 0, N > 0, N <= Size ->
    {Queue2, Queue3} = queue:split(N, QueueRef),
    {ok, {value, queue:to_list(Queue2)}, Queue};

peek(_, _) ->
    {error, "Invalid queue handler"}.


member_of(#emqtt_queue(queue = QueueRef) = Queue, Item) when is_queue(QueueRef), is_empty(QueueRef) ->
    {ok, {empty}, Queue};

member_of(#emqtt_queue(queue = QueueRef) = Queue, Item) when is_queue(QueueRef) ->
    {ok, {queue:member(Item, QueueRef)}, Queue};

member_of(_, _) ->
    {error, "Invalid queue handler"}.

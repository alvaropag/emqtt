-module(emqtt_queue).

-include("emqtt_queue.hrl").

-export([
         new/2,
         id/1,
         in/2,
         out/1,
         peek/2,
         member_of/2,
         drop/1
         ]).

new(Mod, QueueId) ->
    EQueue = Mod:new(QueueId),
    EQueue#emqtt_queue{queue_cb = Mod}.

id(#emqtt_queue{queue_cb = Mod} = Queue) ->
    Mod:id(Queue).

in(#emqtt_queue{queue_cb = Mod} = Queue, Item) ->
    Mod:in(Queue, Item).

out(#emqtt_queue{queue_cb = Mod} = Queue) ->
    Mod:out(Queue).

peek(#emqtt_queue{queue_cb = Mod} = Queue, N) ->
    Mod:peek(Queue, N).

member_of(#emqtt_queue{queue_cb = Mod} = Queue, Item) ->
    Mod:member_of(Queue, Item).

drop(#emqtt_queue{queue_cb = Mod} = Queue) ->
    Mod:drop(Queue).
    

    

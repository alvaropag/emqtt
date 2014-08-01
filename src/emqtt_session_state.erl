-module(emqtt_session_state).

-include("emqtt_session_state.hrl").

-export([
         new/2,
         id/1,
         msg_in/2,
         msg_out/1,
         msg_peek/2,
         msg_member_of/2,
         drop/1,
         subscribe/2,
         unsubscribe/2,
         subscriptions/1
         ]).

new(Mod, UserId) ->
    State = Mod:new(UserId),
    State#emqtt_session_state{session_cb = Mod}.

id(#emqtt_session_state{session_cb = Mod} = State) ->
    Mod:id(State).

msg_in(#emqtt_session_state{session_cb = Mod} = State, Item) ->
    Mod:in(State, Item).

msg_out(#emqtt_session_state{session_cb = Mod} = State) ->
    Mod:out(State).

msg_peek(#emqtt_session_state{session_cb = Mod} = State, N) ->
    Mod:peek(State, N).

msg_member_of(#emqtt_session_state{session_cb = Mod} = State, Item) ->
    Mod:member_of(State, Item).

drop(#emqtt_session_state{session_cb = Mod} = State) ->
    Mod:drop(State).

subscribe(#emqtt_session_state{session_cb = Mod} = State, Path) ->
    Mod:subscribe(State, Path).

unsubscribe(#emqtt_session_state{session_cb = Mod} = State, Path) ->
    Mod:unsubscribe(State, Path).

subscriptions(#emqtt_session_state{session_cb = Mod} = State) ->
    Mod:subscriptions(State).

    

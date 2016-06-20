%%%-------------------------------------------------------------------
%%% @author Russell-X-Shanso
%%% @copyright (C) 2016, Russell-X-Shanso
%%% @doc
%%%     A toolbox about date and time, include datetime calculate with timezone
%%% @end
%%% Created : 2016.06.20   18:28
%%%-------------------------------------------------------------------
-module(ecb_datetime).
-author("Russell-X-Shanso").

%% API
-export([ timestamp_to_datetime/2, timestamp_to_date/2 ]).
-export([ datetime_to_timestamp/2 ]).
-export([ get_last_zerotime/1 ]).
-export([ datetime_add/2 ]).



-define(SECONDS_PER_MINUTE, 60).
-define(SECONDS_PER_HOUR, 3600).
-define(SECONDS_PER_DAY, 86400).

-define(DAYS_FROM_0_TO_1970, 719528).
-define(SECONDS_FROM_0_TO_1970, 62167219200 ).

-type datetimediff() :: { binary(), integer() }.

%%% Timezone format: << Op:1/binary, Hour:2/binary, Colon:1/bianry, Minute:2/binary >>
%%% Just like : <<"+08:00">> | <<"-05:00">>

%%--------------------------------------------------------------------
%% Interface Functions
%%--------------------------------------------------------------------
%% Timestamp to datetime with timezone
-spec( timestamp_to_date( TimeStamp :: integer(), Timezone :: binary() )
        -> Datetime :: calendar:date() ).
%% ex : { 2016, 5, 4 } =:= timestamp_to_ymd( 1462316400, <<"+08:00">> )
timestamp_to_date(Timestamp, Timezone) ->
    {YMD, _} = timestamp_to_datetime(Timestamp, Timezone),
    YMD.

%% Timestamp to datetime with timezone
-spec( timestamp_to_datetime( TimeStamp :: integer(), Timezone :: binary() )
        -> Datetime :: calendar:datetime() ).
%% ex : { { 2016, 5, 4 }, { 7, 0, 0 } } =:= timestamp_to_datetime( 1462316400, <<"+08:00">> )
timestamp_to_datetime( Timestamp, Timezone ) ->
    TimezoneTimestamp = timestamp_to_offset_timestamp( Timestamp, Timezone ),
    calendar:gregorian_seconds_to_datetime(TimezoneTimestamp + ?SECONDS_FROM_0_TO_1970 ).

%% Datetime with timezone to timestamp
-spec( datetime_to_timestamp( Datetime :: calendar:datetime(), Timezone :: binary() )
        -> Timestamp :: integer() ).
%% ex : 1462316400 == datetime_to_timestamp( { { 2016, 5, 4 }, { 7, 0, 0 } }, <<"+08:00">> )
datetime_to_timestamp( Datetime , Timezone ) ->
    TimezoneTimestamp = calendar:datetime_to_gregorian_seconds( Datetime ) - ?SECONDS_FROM_0_TO_1970,
    offset_timestamp_to_timestamp( TimezoneTimestamp, Timezone ).


%% get last midnight timestamp of appointed timezone
-spec( get_last_zerotime( Timezone :: binary() )
        -> ZeroTimestamp ::integer() ).
%% ex : 1462291200 == get_last_zerotime( <<"+08:00">> )
get_last_zerotime( Timezone ) ->
    last_moment_of_interval( ?SECONDS_PER_DAY, Timezone).

%% calculate datetime
%%  datetimediff() :: { Type :: <<"year">> | <<"month">> | <<"day">> | <<"week">> | <<"hour">> | <<"minute">> | <<"second">>, Offset :: integer }
-spec( datetime_add( Datetime :: calendar:datetime(), Diff :: datetimediff() | [ datetimediff() ]  )
    -> calendar:datetime() ).
datetime_add( Datetime, { Type, Offset } ) ->
    datetime_add_1( Datetime, Type, Offset );
datetime_add( Datetime, Diff ) when is_list( Diff ) ->
    lists:foldl( fun( { Type, Offset }, Acc ) -> datetime_add_1( Acc, Type, Offset ) end, Datetime, Diff ).


datetime_add_1( { { Y, M, D }, { H, Mn, S } }, <<"year">>, Offset ) -> { { Y + Offset, M, D }, { H, Mn, S } };
datetime_add_1( { { Y, M, D }, { H, Mn, S } }, <<"month">>, Offset ) ->
    NewM = ( M + Offset - 1 ) rem 12 + 1,
    YOffset = ( M + Offset - 1 ) / 12,
    { { Y + YOffset , NewM, D }, { H, Mn, S } };
datetime_add_1( Datetime, <<"day">>, Offset ) ->
    calendar:gregorian_seconds_to_datetime( calendar:datetime_to_gregorian_seconds( Datetime ) + ?SECONDS_PER_DAY * Offset );
datetime_add_1( Datetime, <<"week">>, Offset ) ->
    calendar:gregorian_seconds_to_datetime( calendar:datetime_to_gregorian_seconds( Datetime ) + ?SECONDS_PER_DAY * Offset * 7 );
datetime_add_1( Datetime, <<"hour">>, Offset ) ->
    calendar:gregorian_seconds_to_datetime( calendar:datetime_to_gregorian_seconds( Datetime ) + ?SECONDS_PER_HOUR * Offset );
datetime_add_1( Datetime, <<"minute">>, Offset ) ->
    calendar:gregorian_seconds_to_datetime( calendar:datetime_to_gregorian_seconds( Datetime ) + ?SECONDS_PER_MINUTE * Offset );
datetime_add_1( Datetime, <<"second">>, Offset ) ->
    calendar:gregorian_seconds_to_datetime( calendar:datetime_to_gregorian_seconds( Datetime ) + Offset ).

%%--------------------------------------------------------------------
%% Internal Functions
%%--------------------------------------------------------------------
%%

%% timezone to seconds
-spec( calculate_timezone_to_seconds( binary() ) -> Sec :: integer() ).
calculate_timezone_to_seconds(  <<HourStr:2/binary, _:1/binary, MinStr:2/binary>> ) ->
    Hour = binary_to_integer( HourStr ),
    Minute = binary_to_integer( MinStr ),
    Hour * ?SECONDS_PER_HOUR + Minute * ?SECONDS_PER_MINUTE.


-spec( last_moment_of_interval( Interval::integer(), Timezone::binary() )
        -> integer() ).
last_moment_of_interval(Interval, Timezone) ->
    {X, Y, _} = now(),
    Time = X * 1000000 + Y,
    last_moment_of_interval(Time, Interval, Timezone).
last_moment_of_interval(Time, Interval, _Timezone) when Interval < ?SECONDS_PER_DAY ->
    Time - (Time rem Interval);
last_moment_of_interval(Time, Interval, <<HourStr:2/binary, _:1/binary, MinStr:2/binary>> = _Timezone) ->
    Hour = binary_to_integer( HourStr ),
    Minute = binary_to_integer( MinStr ),
    last_moment_of_interval_1( Time, Interval, <<"+">>, Hour, Minute );
last_moment_of_interval(Time, Interval, <<Op:1/binary, HourStr:2/binary, _:1/binary, MinStr:2/binary>> = _Timezone) ->
    Hour = binary_to_integer( HourStr ),
    Minute = binary_to_integer( MinStr ),
    last_moment_of_interval_1( Time, Interval, Op, Hour, Minute );
last_moment_of_interval( Time, _, _ ) ->
    Time.

last_moment_of_interval_1(Time, Interval, <<" ">>, Hour, Minute) ->
    last_moment_of_interval_1(Time, Interval, <<"+">>, Hour, Minute);
last_moment_of_interval_1(Time, Interval, <<"+">>, Hour, Minute) ->
    TimeDif = Hour * ?SECONDS_PER_HOUR + Minute * ?SECONDS_PER_MINUTE,
    Time - ((Time + TimeDif) rem Interval);
last_moment_of_interval_1(Time, Interval, <<"-">>, Hour, Minute) ->
    TimeDif = Hour * ?SECONDS_PER_HOUR + Minute * ?SECONDS_PER_MINUTE,
    Time - ((Time - TimeDif) rem Interval);
last_moment_of_interval_1(Time, _, _, _, _) -> Time.


%% timestamp of offset timestamp
-spec( timestamp_to_offset_timestamp( TimeStamp :: integer(),
    Timezone :: binary() )
        -> integer() ).
timestamp_to_offset_timestamp( Timestamp, << Op:8, Timezone:5/binary>> ) ->
    TimeDiff = calculate_timezone_to_seconds( Timezone ),
    timestamp_to_offset_timestamp_1( Timestamp, Op, TimeDiff ).

timestamp_to_offset_timestamp_1( TimeStamp, 32, TimeDiff ) -> TimeStamp + TimeDiff;    %% +
timestamp_to_offset_timestamp_1( TimeStamp, 45, TimeDiff ) -> TimeStamp - TimeDiff;    %% -
timestamp_to_offset_timestamp_1( TimeStamp, 43, TimeDiff ) -> TimeStamp + TimeDiff.    %% +

%% Offset timestamp to Greenwich timestamp
-spec( offset_timestamp_to_timestamp( TimeStamp :: integer(),
    Timezone :: binary() )
        -> integer() ).
offset_timestamp_to_timestamp( TimeStamp, << Op:8, Timezone:5/binary>> ) ->
    TimeDiff = calculate_timezone_to_seconds( Timezone ),
    offset_timestamp_to_timestamp_1( TimeStamp, Op, TimeDiff ).

offset_timestamp_to_timestamp_1( TimeStamp, 32, TimeDiff ) -> TimeStamp - TimeDiff;    %% +
offset_timestamp_to_timestamp_1( TimeStamp, 45, TimeDiff ) -> TimeStamp + TimeDiff;    %% -
offset_timestamp_to_timestamp_1( TimeStamp, 43, TimeDiff ) -> TimeStamp - TimeDiff.    %% +

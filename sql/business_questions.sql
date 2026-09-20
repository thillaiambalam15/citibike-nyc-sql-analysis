-- Q1 — What is the total number of rides per day of the week?
select dayname(started_at) as 'Day', count(*) as Rides
from trips
group by dayname(started_at);

-- Q2 — What is the average trip durtion (minutes) by rider type?
select member_casual as 'Rider type', avg(duration) as 'Avg trip duration'
from trips
group by member_casual
order by `Avg trip duration` desc;

-- Q3 — Which 10 stations have the most rides starting there?
select start_station_name, count(*) as Rides
from trips
group by start_station_name
order by Rides desc
limit 10;

-- Q4 — What's the breakdown of rides by bike type?
select rideable_type, count(*) as 'count'
from trips
group by rideable_type
order by 2 desc;

-- Q5 — What's the hourly distrbution of ride starts across the day?
select HOUR(started_at) as `hour`, count(*) as `ride_count`
from trips
group by `hour`
order by hour asc;

-- Q6 — What percentage of total rides are taken by members and casual riders?
select member_casual as member_type,
    count(*) as ride_count,
    round(count(*) * 100 / (select count(*) from trips), 2) as pct_of_total
from trips
group by member_casual
order by 3 desc;

-- Q7 — Which single day of the month had the highst total ride volume?
select dayofmonth(started_at) as `Day`, count(*) as ride_count
from trips
group by dayofmonth(started_at)
order by 2 desc;

-- Q8 — What is the average trip duration by bike type?
select rideable_type as bike_type, avg(duration) as avg_duration
from trips
group by rideable_type
order by 2 desc;

-- Q9 — How many rides start and end at the same station (round trips), and what is their pct?
select
    sum(start_station_id = end_station_id) as round_trips,
    count(*) as total_rides,
    round(sum(start_station_id = end_station_id) * 100.0 / count(*), 2) as pct_round_trips
from trips;

-- Q10 — What is the average numbr of rides per station overall ?
select round(avg(ride_count), 2) as avg_rides_per_station
from (
    select start_station_id, count(*) as ride_count
    from trips
    group by start_station_id
) station_totals;

-- Q11 — What combinations of rider type + bike type is most common, and what is the pct of these of all rides?
select member_casual, rideable_type, count(*) as ride_count,
    round(count(*) * 100 / (select count(*) from trips), 2) as pct_ride_count
from trips
group by member_casual, rideable_type
order by 3 desc;

-- Q12 — What is the busiest day of the week specifically for casual riders?
select dayname(started_at) as day_of_week, count(*) as ride_count
from trips
where member_casual = 'casual'
group by dayname(started_at)
order by 2 desc;

-- Q13 — Rank the top 5 busiest start stations separately for members and for casual riders
with cte1 as (
    select t.member_casual, s.station_id, s.station_name, count(*) as ride_count
    from trips t
    join stations s on t.start_station_id = s.station_id
    group by t.member_casual, s.station_id, s.station_name
),
cte2 as (
    select member_casual, station_id, station_name, ride_count,
        rank() over (partition by member_casual order by ride_count desc) as `rank`
    from cte1
)
select * from cte2
where `rank` <= 5
order by member_casual asc, `rank` asc;

-- Q14 — Compute each station's net flow (depatures minus arrivals)
with departures as (
    select start_station_id as station_id, count(*) as depart_count
    from trips
    where start_station_id is not null
    group by start_station_id
),
arrivals as (
    select end_station_id as station_id, count(*) as arrive_count
    from trips
    where end_station_id is not null
    group by end_station_id
)
select
    s.station_id, s.station_name,
    coalesce(d.depart_count, 0) as departures,
    coalesce(a.arrive_count, 0) as arrivals,
    coalesce(d.depart_count, 0) - coalesce(a.arrive_count, 0) as net_flow
from stations s
left join departures d on s.station_id = d.station_id
left join arrivals a on s.station_id = a.station_id
order by net_flow desc;

-- Q15 — Compute a 7-day rolling average of daily ride counts
with daily_rides as (
    select date(started_at) as ride_date, count(*) as ride_count
    from trips
    group by date(started_at)
)
select
    ride_date, ride_count,
    round(avg(ride_count) over (order by ride_date rows between 6 preceding and current row), 2) as rolling_7day_avg
from daily_rides
order by 1;

-- Q16 — Find the top 10 most common start to end station routes
select
    s1.station_name as start_station,
    s2.station_name as end_station,
    count(*) as trip_count
from trips t
join stations s1 on t.start_station_id = s1.station_id
join stations s2 on t.end_station_id = s2.station_id
group by s1.station_name, s2.station_name
order by trip_count desc
limit 10;

-- Q17 — Compute day over day change in ride volume, used lag
with daily_rides as (
    select date(started_at) as ride_date, count(*) as ride_count
    from trips
    group by date(started_at)
)
select
    ride_date, ride_count,
    ride_count - lag(ride_count) over (order by ride_date) as change_from_prev_day
from daily_rides
order by ride_date;

-- Q18 — Compute geographic distance (km) between start and end station using Haversine and average by rider type
select
    member_casual,
    round(avg(
        6371 * acos(
            least(1, greatest(-1,
                cos(radians(start_lat)) * cos(radians(end_lat)) * cos(radians(end_lng) - radians(start_lng))
                + sin(radians(start_lat)) * sin(radians(end_lat))
            ))
        )
    ), 3) as avg_distance_km
from trips
where start_lat is not null and end_lat is not null
group by member_casual;

-- Q19 — Find each station's single busiest hour of day
with cte as (
    select start_station_id as station_id, hour(started_at) as hour_of_day, count(*) as ride_count
    from trips
    group by start_station_id, hour(started_at)
)
select distinct station_id,
    first_value(hour_of_day) over (partition by station_id order by ride_count desc) as hour_of_day,
    first_value(ride_count) over (partition by station_id order by ride_count desc) as ride_count
from cte
order by 3 desc;

-- Q20 — Rank stations by round trip pct
with station_pct as (
    select
        start_station_id as station_id,
        count(*) as total_trips,
        sum(start_station_id = end_station_id) as round_trips,
        round(sum(start_station_id = end_station_id) * 100.0 / count(*), 2) as round_trip_pct
    from trips
    where start_station_id is not null
    group by start_station_id
)
select
    sp.station_id, s.station_name, sp.total_trips, sp.round_trips, sp.round_trip_pct,
    rank() over (order by sp.round_trip_pct desc) as pct_rank
from station_pct sp
join stations s on sp.station_id = s.station_id
order by pct_rank;

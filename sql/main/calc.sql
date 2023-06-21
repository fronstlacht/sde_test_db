set search_path = bookings, public;

drop table if exists results;

create table if not exists results (
                                       id smallint,
                                       response text
);

--1. Вывести максимальное количество человек в одном бронировании
insert into results
select 1, max(a.book_amt)
from (select book_ref, count(passenger_id) book_amt from tickets
      group by book_ref) a;

--2. Вывести количество бронирований с количеством людей больше среднего значения людей на одно бронирование
insert into results
select 2, count(b.book_ref) from
    (select a.book_ref, avg(a.book_amt) avg_amt
     from (select book_ref, count(passenger_id) as "book_amt" from tickets
           group by book_ref) a
     group by a.book_ref
     having avg(a.book_amt) > (select avg(a.book_amt) avg_amt
                               from (select book_ref, count(passenger_id) book_amt from tickets
                                     group by book_ref) a)) b;

--3. Вывести количество бронирований, у которых состав пассажиров повторялся два и более раза, среди бронирований с максимальным количеством людей
with table1 as (
    select book_ref, count(*) c
    from tickets
    group by book_ref),
     table2 as (
         select book_ref, passenger_id from tickets
         where book_ref in (select book_ref from table1
                            where c = (select max(c) from table1)))
insert into results
select 3, count(distinct book_ref)
from (select t1.book_ref,
             row_number() over(partition by t1.book_ref, t2.book_ref
                 order by t1.book_ref, t2.book_ref) pass_num
      from table2 t1
               join table2 t2 on t1.passenger_id = t2.passenger_id and t1.book_ref != t2.book_ref) t
where t.pass_num = (select max(c) from table1);

--4. Вывести номера брони и контактную информацию по пассажирам в брони (passenger_id, passenger_name, contact_data) с количеством людей в брони = 3
insert into results
select 4, concat(a.book_ref,'|',a.passenger_id,'|',a.contact_data) response_4 from tickets a
where a.book_ref in
      (select book_ref from tickets
       group by book_ref
       having count(passenger_id) = 3)
order by a.book_ref||a.passenger_id||a.contact_data asc;

--5. Вывести максимальное количество перелётов на бронь
insert into results
select 5, max(c.flight_amt) max_flight from
    (select a.book_ref, count(distinct b.flight_id) flight_amt from tickets a
                                                                        join ticket_flights b on a.ticket_no = b.ticket_no
     group by a.book_ref) c;

--6. Вывести максимальное количество перелётов на бронь
insert into results
select 6, max(c.flight_amt) from
    (select t.book_ref, t.passenger_id, t.ticket_no, count(b.flight_id) flight_amt from tickets t
                                                                                            join boarding_passes b on t.ticket_no = b.ticket_no
     group by t.book_ref, t.passenger_id, t.ticket_no) c;

--7. Вывести максимальное количество перелётов на пассажира
insert into results
select 7, max(c.flight_amt) from
    (select t.passenger_id, count(b.flight_id) flight_amt from tickets t
                                                                   join boarding_passes b on t.ticket_no = b.ticket_no
     group by t.passenger_id) c;

--8. Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общие траты на билеты, для пассажира потратившему минимальное количество денег на перелеты
insert into results
select 8, concat(a.passenger_id ,'|', a.passenger_name ,'|', a.contact_data ,'|', a.sum_amt) response_8 from
    (select t.passenger_id, t.passenger_name, t.contact_data, sum(tf.amount) as "sum_amt" from tickets t
                                                                                                   join ticket_flights tf on t.ticket_no = tf.ticket_no
     group by t.passenger_id, t.passenger_name, t.contact_data) a
where a.sum_amt = (select min(b.sum_amt) from (select t.passenger_id, t.passenger_name, t.contact_data, sum(tf.amount) as "sum_amt" from tickets t
                                                                                                                                             join ticket_flights tf on t.ticket_no = tf.ticket_no
                                               group by t.passenger_id, t.passenger_name, t.contact_data) b);

--9. Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общее время в полётах, для пассажира, который провёл максимальное время в полётах
insert into results
select 9, concat(passenger_id, '|', passenger_name, '|', contact_data, '|', sum_duration)
from (select passenger_id, passenger_name, contact_data, sum(actual_duration) sum_duration,
             rank() over(order by sum(actual_duration) desc) rank_sum_duration
      from tickets t1
               join ticket_flights using(ticket_no)
               join flights_v using(flight_id)
      where actual_duration is not null
      group by ticket_no) t2
where rank_sum_duration = 1
order by passenger_id, passenger_name, contact_data;

--10. Вывести город(а) с количеством аэропортов больше одного
insert into results
select 10, b.city from airports b
group by b.city
having count(*) > 1;

--11. Вывести город(а), у которого самое меньшее количество городов прямого сообщения
insert into results
select 11, a.departure_city from
    (select distinct departure_city, arrival_city from bookings.flights_v
     group by departure_city, arrival_city) a
group by a.departure_city
having count(a.departure_city) = 1;

--12. Вывести пары городов, у которых нет прямых сообщений исключив реверсные дубликаты
with table12 as(select distinct departure_city, arrival_city from routes)

insert into results
select 12, concat(dep_c, '|', arr_c)
from(select t1.departure_city dep_c, t2.arrival_city arr_c from table12 t1, table12 t2
     where t1.departure_city < t2.arrival_city
     except
     select * from table12) t
order by dep_c, arr_c;
--13. Вывести города, до которых нельзя добраться без пересадок из Москвы?
insert into results
select distinct 13, departure_city
from routes
where departure_city != 'Москва'
  and departure_city not in (
    select arrival_city from routes
    where departure_city = 'Москва');

--14. Вывести модель самолета, который выполнил больше всего рейсов
insert into results
select 14, b.model from
    (select a2.model, count(distinct a.flight_no) count_fli from flights a
                                                                     join aircrafts a2 on a.aircraft_code = a2.aircraft_code
     group by a2.model) b
where b.count_fli = (select max(c.count_fli) from (select count(distinct a.flight_no) count_fli from flights a
                                                                                                         join aircrafts a2 on a.aircraft_code = a2.aircraft_code
                                                   group by a2.model)c);

--15. Вывести модель самолета, который перевез больше всего пассажиров
insert into results
select 15, c.model from
    (select a2.model, count(b.ticket_no) pas_amt from flights a
                                                          join boarding_passes b on a.flight_id = b.flight_id
                                                          join aircrafts a2 on a.aircraft_code = a2.aircraft_code
     where a.actual_departure is not null
     group by a2.model) c
where c.pas_amt = (select max(x.pas_amt) from (select a2.model, count(b.ticket_no) pas_amt from flights a
                                                                                                    join boarding_passes b on a.flight_id = b.flight_id
                                                                                                    join aircrafts a2 on a.aircraft_code = a2.aircraft_code
                                               where a.actual_departure is not null
                                               group by a2.model) x);

--16. Вывести отклонение в минутах суммы запланированного времени перелета от фактического по всем перелётам
insert into results
select 16, sum(a.diff) from
    (select extract(EPOCH from scheduled_duration - actual_duration)/60 diff
     from flights_v
     where actual_duration is not null
     order by diff) a;

--17. Вывести города, в которые осуществлялся перелёт из Санкт-Петербурга 2016-09-13
insert into results
select 17, a.arrival_city from flights_v a
where a.departure_city = 'Санкт-Петербург' and a.actual_departure::date = '2016-09-13'
order by a.arrival_city;

--18. Вывести перелёт(ы) с максимальной стоимостью всех билетов
insert into results
select 18, t.flight_id
from (select flight_id, sum(amount) sum_amt
      from ticket_flights tf
      group by flight_id) t
where sum_amt = (select max(f.sum_amt) from (select flight_id, sum(amount) sum_amt
                                             from ticket_flights tf
                                             group by flight_id) f);

--19. Выбрать дни в которых было осуществлено минимальное количество перелётов
insert into results
select 19, date_departure
from (select actual_departure::date date_departure, count(flight_id) count_fli, min(count(flight_id)) over() min_count_fli
      from flights f
      where actual_departure is not null
      group by actual_departure::date) t
where count_fli = min_count_fli
order by date_departure;

--20. Вывести среднее количество вылетов в день из Москвы за 09 месяц 2016 года
insert into results
select 20, avg(count_flights) avg_departure
from (select count(flight_id) count_flights
      from flights
      where actual_departure is not null and date_trunc('month', actual_departure) = '2016-09-01'
      group by actual_departure::date) t;

--21. Вывести топ 5 городов у которых среднее время перелета до пункта назначения больше 3 часов
insert into results
select 21, departure_city from
    (select distinct departure_city, avg_duration_city, dense_rank() over(order by avg_duration_city desc) rn
     from
         (select distinct flight_id, departure_city, actual_duration
                        , avg(actual_duration) over(partition by departure_city) avg_duration_city
          from flights_v
          where actual_duration is not null) a
     Where extract(EPOCH from avg_duration_city)/3600>3) b
order by rn
limit 5;

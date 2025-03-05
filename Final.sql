-- 1. Выведите название самолетов, которые имеют менее 50 посадочных мест.

select a.model 
FROM aircrafts a 
join seats s using(aircraft_code)
group by a.aircraft_code 
having count(s.seat_no) < 50


-- 2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

select 
	date_part('month', b.book_date),
	sum(b.total_amount),
	round((sum(b.total_amount) - 
	lag(sum(b.total_amount)) over (order by date_part('month', b.book_date))) / 
	lag(sum(b.total_amount)) over (order by date_part('month', b.book_date)) * 100, 2)
from bookings b 
group by date_part('month', b.book_date)
order by 1


-- 3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.

select a.model
from aircrafts a 
join seats s using(aircraft_code)
group by a.aircraft_code 
having 'Business' != all(array_agg(distinct s.fare_conditions))


/*
4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день, учитывая только те самолеты, которые летали пустыми и только те дни, где из одного аэропорта таких самолетов вылетало более одного.
В результате должны быть код аэропорта, дата, количество пустых мест в самолете и накопительный итог.
*/


/*
5. Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
Выведите в результат названия аэропортов и процентное отношение.
Решение должно быть через оконную функцию.
*/
 
select distinct
	a.airport_name as departure_airport,
	a2.airport_name as arrival_airport,
	count(f.flight_id) over(partition by f.departure_airport, f.arrival_airport)::float / count(f.flight_id) over()::float * 100
from flights f 
join airports a on a.airport_code = f.departure_airport
join airports a2 on a2.airport_code = f.arrival_airport
order by a.airport_name

-- 6. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7

select count(t.passenger_id), substring(contact_data->>'phone' from 1 for 5)
from tickets t
group by substring(contact_data->>'phone' from 1 for 5)


/*
7. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
До 50 млн - low
От 50 млн включительно до 150 млн - middle
От 150 млн включительно - high
Выведите в результат количество маршрутов в каждом полученном классе
*/

select ca, count(*)
from (
	select distinct
	f.departure_airport, 
	f.arrival_airport,
		case
			when sum(tf.amount) over(partition by f.departure_airport, f.arrival_airport) < 50000000 then 'low'
			when sum(tf.amount) over(partition by f.departure_airport, f.arrival_airport) between 50000000 and 150000000 then 'middle'
			else 'high'
		end ca
	from flights f 
	join ticket_flights tf using(flight_id)) t
group by ca
 
 
/*
8. Вычислите медиану стоимости перелетов, медиану размера бронирования и отношение медианы бронирования к медиане стоимости перелетов, 
округленной до сотых
*/

with cte_1 as (
select percentile_disc(0.5) within group (order by tf.amount) as median_1
from ticket_flights tf 
),
cte_2 as (
select percentile_disc(0.5) within group (order by b.total_amount) as median_2
from bookings b
)
select 
	cte_1.median_1, 
	cte_2.median_2, 
	round(cte_2.median_2 / cte_1.median_1, 2)
from cte_1, cte_2


/*
9. Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть нужно найти расстояние между аэропортами и с учетом стоимости перелетов получить искомый результат
  Для поиска расстояния между двумя точками на поверхности Земли используется модуль earthdistance.
  Для работы модуля earthdistance необходимо предварительно установить модуль cube.
  Установка модулей происходит через команду: create extension название_модуля.
*/

with cte_ticket_flights as (
	select flight_id, min(amount) min_amount
	from ticket_flights
	group by flight_id
)

select min(ctf_min_amount / distance)
from (
	select distinct 
		f.flight_id,
		ctf.min_amount ctf_min_amount, 
		earth_distance(
	        ll_to_earth(a.latitude, a.longitude), 
	        ll_to_earth(a2.latitude, a2.longitude)
	    ) / 1000 as distance
	from flights f 
	join airports a on a.airport_code = f.departure_airport 
	join airports a2 on a2.airport_code = f.arrival_airport 
	join cte_ticket_flights ctf on ctf.flight_id = f.flight_id 
) as distances


-- 1. Вывести к каждому самолету класс обслуживания и количество мест этого класса
SELECT aircraft.aircraft_code,
       fare_conditions,
       count(seat_no) AS number_of_seats
FROM aircrafts_data AS aircraft
         JOIN seats ON aircraft.aircraft_code = seats.aircraft_code
GROUP BY aircraft.aircraft_code, fare_conditions;

-- 2. Найти 3 самых вместительных самолета (модель + кол-во мест)
SELECT model ->> 'ru' AS model,
       count(seat_no) AS number_of_seats
FROM aircrafts_data
         JOIN seats ON aircrafts_data.aircraft_code = seats.aircraft_code
GROUP BY aircrafts_data.aircraft_code
ORDER BY number_of_seats DESC
LIMIT 3;

-- 3. Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам
SELECT aircrafts_data.aircraft_code,
       model ->> 'ru' AS model,
       seat_no
FROM aircrafts_data
         JOIN seats ON aircrafts_data.aircraft_code = seats.aircraft_code
WHERE model ->> 'ru' = 'Аэробус A321-200'
  AND fare_conditions != 'Economy'
ORDER BY seat_no;

-- 4. Вывести города в которых больше 1 аэропорта (код аэропорта, аэропорт, город)
SELECT airport_code,
       airport_name ->> 'en' AS name,
       city ->> 'ru'         AS city
FROM airports_data
WHERE city IN (SELECT city
               FROM airports_data
               GROUP BY city
               HAVING count(*) > 1)
ORDER BY city;

-- 5. Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация
SELECT flight_id,
       dep.city ->> 'ru' AS departure,
       arr.city ->> 'ru' AS arrival,
       status
FROM flights
         JOIN airports_data AS dep ON flights.departure_airport = dep.airport_code
         JOIN airports_data AS arr ON flights.arrival_airport = arr.airport_code
WHERE dep.city ->> 'ru' = 'Екатеринбург'
  AND arr.city ->> 'ru' = 'Москва'
  AND flights.status NOT IN ('Departed', 'Arrived', 'Cancelled')
  AND scheduled_departure > bookings.now()
ORDER BY scheduled_departure
LIMIT 1;

-- 6. Вывести самый дешевый и дорогой билет и стоимость (в одном результирующем ответе)
WITH c_e AS (SELECT min(amount) AS cheapest,
                    max(amount) AS expensive
             FROM ticket_flights)
    (SELECT ticket_flights.*
     FROM ticket_flights
              JOIN c_e ON ticket_flights.amount = c_e.cheapest
     LIMIT 1)
UNION ALL
(SELECT ticket_flights.*
 FROM ticket_flights
          JOIN c_e ON ticket_flights.amount = c_e.expensive
 LIMIT 1);

-- 7. Вывести информацию о вылете с наибольшей суммарной стоимостью билетов
WITH sum_amount AS (SELECT flight_id,
                           sum(amount) AS highest_total_amount
                    FROM ticket_flights
                    GROUP BY flight_id)
SELECT flight.*,
       highest_total_amount
FROM flights flight
         JOIN sum_amount AS s_m ON s_m.flight_id = flight.flight_id
WHERE highest_total_amount = (SELECT max(highest_total_amount) FROM sum_amount);

-- 8. Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели,
-- информацию о модели и общую стоимость
WITH sum_amount AS (SELECT flights.aircraft_code,
                           sum(amount) AS highest_total_amount
                    FROM ticket_flights
                             JOIN flights ON ticket_flights.flight_id = flights.flight_id
                    GROUP BY flights.aircraft_code)
SELECT aircraft.aircraft_code,
       aircraft.model ->> 'ru' AS model,
       aircraft.range,
       highest_total_amount
FROM aircrafts_data AS aircraft
         JOIN sum_amount AS s_m ON s_m.aircraft_code = aircraft.aircraft_code
WHERE highest_total_amount = (SELECT max(highest_total_amount) FROM sum_amount);

-- 9. Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов,
-- информацию о модели самолета, аэропорт назначения, город
WITH ranked_flights AS (SELECT aircraft_code,
                               arrival_airport,
                               count(*)                                                              AS number_of_flights,
                               row_number() OVER (PARTITION BY aircraft_code ORDER BY count(*) DESC) AS rn
                        FROM flights
                        GROUP BY aircraft_code, arrival_airport)
SELECT number_of_flights,
       aircraft.model ->> 'ru'       AS model,
       airport.airport_name ->> 'ru' AS airport_name,
       airport.city ->> 'ru'         AS city
FROM ranked_flights r_f
         JOIN aircrafts_data aircraft ON r_f.aircraft_code = aircraft.aircraft_code
         JOIN airports_data airport ON r_f.arrival_airport = airport.airport_code
WHERE rn = 1
ORDER BY number_of_flights DESC;

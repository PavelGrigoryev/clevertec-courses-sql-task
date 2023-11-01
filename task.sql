-- Вывести к каждому самолету класс обслуживания и количество мест этого класса
SELECT model ->> 'ru' AS model,
       fare_conditions,
       count(seat_no) AS number_of_seats
FROM aircrafts_data
         JOIN seats ON aircrafts_data.aircraft_code = seats.aircraft_code
GROUP BY model, fare_conditions
ORDER BY model;

-- Найти 3 самых вместительных самолета (модель + кол-во мест)
SELECT model ->> 'ru' AS model,
       count(seat_no) AS number_of_seats
FROM aircrafts_data
         JOIN seats ON aircrafts_data.aircraft_code = seats.aircraft_code
GROUP BY aircrafts_data.aircraft_code
ORDER BY number_of_seats DESC
LIMIT 3;

-- Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам
SELECT aircrafts_data.aircraft_code,
       model ->> 'ru' AS model,
       seat_no
FROM aircrafts_data
         JOIN seats ON aircrafts_data.aircraft_code = seats.aircraft_code
WHERE model ->> 'ru' = 'Аэробус A321-200'
  AND fare_conditions != 'Economy'
ORDER BY seat_no;

-- Вывести города в которых больше 1 аэропорта ( код аэропорта, аэропорт, город)
SELECT airport_code,
       airport_name ->> 'en' AS name,
       city ->> 'ru'         AS city
FROM airports_data
WHERE city IN (SELECT city
               FROM airports_data
               GROUP BY city
               HAVING count(*) > 1)
ORDER BY city;

-- Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация
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

-- Вывести самый дешевый и дорогой билет и стоимость ( в одном результирующем ответе)
SELECT concat('Cheapest #', tf1.ticket_no, ', price = ', tf1.amount)  AS cheapest,
       concat('Expensive #', tf2.ticket_no, ', price = ', tf2.amount) AS expensive
FROM ticket_flights tf1
         JOIN ticket_flights tf2
              ON tf1.amount = (SELECT MIN(amount) FROM ticket_flights)
                  AND tf2.amount = (SELECT MAX(amount) FROM ticket_flights)
LIMIT 1;

-- Вывести информацию о вылете с наибольшей суммарной стоимостью билетов
SELECT flight.flight_id,
       flight.flight_no,
       flight.scheduled_departure,
       flight.scheduled_arrival,
       flight.departure_airport,
       flight.arrival_airport,
       flight.status,
       flight.aircraft_code,
       sum(amount) AS highest_total_amount
FROM flights AS flight
         JOIN ticket_flights ON flight.flight_id = ticket_flights.flight_id
GROUP BY flight.flight_id
ORDER BY highest_total_amount DESC
LIMIT 1;

-- Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели,
-- информацию о модели и общую стоимость
SELECT aircraft.aircraft_code,
       aircraft.model ->> 'ru' AS model,
       aircraft.range,
       sum(amount)             AS highest_total_amount
FROM ticket_flights
         JOIN flights ON ticket_flights.flight_id = flights.flight_id
         JOIN aircrafts_data AS aircraft ON flights.aircraft_code = aircraft.aircraft_code
GROUP BY aircraft.aircraft_code
ORDER BY highest_total_amount DESC
LIMIT 1;

-- Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов,
-- информацию о модели самолета, аэропорт назначения, город
WITH ranked_flights AS (SELECT count(*)                                                               AS number_of_flights,
                               aircraft.model ->> 'ru'                                                AS model,
                               airport.airport_name ->> 'ru'                                          AS airport_name,
                               airport.city ->> 'ru'                                                  AS city,
                               row_number() OVER (PARTITION BY aircraft.model ORDER BY count(*) DESC) AS rn
                        FROM flights
                                 JOIN aircrafts_data aircraft ON flights.aircraft_code = aircraft.aircraft_code
                                 JOIN airports_data airport ON flights.arrival_airport = airport.airport_code
                        GROUP BY model, airport_name, city)
SELECT number_of_flights, model, airport_name, city
FROM ranked_flights
WHERE rn = 1
ORDER BY number_of_flights DESC;

-- Transforming Date with a function taking two parameters; the ending and start date.
CREATE OR REPLACE FUNCTION total_rental(date_return timestamp, date_rented timestamp)
RETURNS int
LANGUAGE plpgsql
AS
$$
DECLARE days int;
BEGIN
SELECT EXTRACT(DAY FROM (date_return-date_rented)) INTO days;
RETURN days;
END;
$$

-- Creating the raw and short tables. These will be empty so the data can be refreshed without recreating the table every time.
CREATE TABLE raw_table (
customer_id smallint,
rental_duration bigint,
amount numeric(7,2),
rental_date timestamp without time zone
);

CREATE TABLE short_table (
customer_id smallint,
average_rental_span bigint,
total_lifetime_sales numeric(7,2),
most_recent_rental timestamp without time zone
);

/*Extract initial data to fill in raw table. Table join can be extended out to include Customer table as well and the Concat the 
customer.first and customer.last then adding a 'customer_name' to both of the new tables. */
INSERT INTO raw_table
SELECT r.customer_id, total_rental(return_date, rental_date), amount, rental_date
FROM rental r
LEFT JOIN payment p  ON r.customer_id = p.customer_id;

SELECT * FROM raw_table;

/*Created trigger on raw table that will update short table when a new entry is added. This can be duplicated to create a trigger 
on the entire database so that both tables can be updated automatically wiithout a manual refresh.*/
CREATE TRIGGER short_trigger
AFTER INSERT
ON raw_table
FOR EACH STATEMENT
EXECUTE PROCEDURE short_trigger_function();

CREATE OR REPLACE FUNCTION short_trigger_function()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
DELETE FROM short_table;
INSERT INTO short_table
SELECT customer_id,
SUM(rental_duration) / COUNT(rental_duration) AS average_rental_length,
SUM(amount),
MAX(rental_date) AS recent_rental
FROM raw_table
GROUP BY customer_id
ORDER BY customer_id;
RETURN NEW;
END;
$$



SELECT * FROM short_table;
DELETE FROM raw_table;
SELECT * FROM raw_table;

INSERT INTO raw_table VALUES (0,100,80.99,current_timestamp);

/*Create a stored procedure to refresh the data in the
raw table AND the short table manually.*/
CREATE OR REPLACE PROCEDURE refresh_procedure()
LANGUAGE plpgsql
AS $$
BEGIN

DELETE FROM short_table;
DELETE FROM raw_table;

INSERT INTO raw_table
SELECT r.customer_id, total_rental(return_date, rental_date),
amount, rental_date
FROM rental r
LEFT JOIN payment p  ON r.customer_id = p.customer_id;

INSERT INTO short_table
SELECT customer_id,
SUM(rental_duration) / COUNT(rental_duration) AS average_rental_length,
SUM(amount),
MAX(rental_date) AS recent_rental
FROM raw_table
GROUP BY customer_id
ORDER BY customer_id;

RETURN;
END;
$$

SELECT * FROM raw_table;
CALL refresh_procedure();

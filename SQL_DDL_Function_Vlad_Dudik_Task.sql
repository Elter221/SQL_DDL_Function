--1 Create a view called "sales_revenue_by_category_qtr" that shows the film category and total sales revenue for the current quarter.
-- The view should only display categories with at least one sale in the current quarter. The current quarter should be determined dynamically.
CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
SELECT 
	c.name,
	SUM(p.amount) AS rental_per_quarter
FROM category c
	JOIN film_category fc ON fc.category_id = c.category_id
	JOIN inventory i ON i.film_id = fc.film_id
	JOIN rental r ON r.inventory_id = i.inventory_id
	JOIN payment p ON r.rental_id = p.rental_id
WHERE p.payment_date >= DATE_TRUNC('quarter', CURRENT_DATE)
GROUP BY c.name
ORDER BY rental_per_quarter

	
SELECT * FROM sales_revenue_by_category_qtr

--2 Create a query language function called "get_sales_revenue_by_category_qtr"
-- that accepts one parameter representing the current quarter and returns the same result as the "sales_revenue_by_category_qtr" view
CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(start_of_quarter TIMESTAMPTZ)
RETURNS TABLE ( 
	category_name TEXT,
	rental_per_qtr NUMERIC(5,2) 
) AS $$
BEGIN
	RETURN QUERY
	SELECT c.name AS category_name,
		SUM(p.amount) AS rental_per_qtr
	FROM category c
		JOIN film_category fc ON fc.category_id = c.category_id
		JOIN inventory i ON i.film_id = fc.film_id
		JOIN rental r ON r.inventory_id = i.inventory_id
		JOIN payment p ON r.rental_id = p.rental_id
	WHERE p.payment_date >= start_of_quarter
	GROUP BY c.name
	ORDER BY rental_per_qtr;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_sales_revenue_by_category_qtr(DATE_TRUNC('quarter', CURRENT_DATE));

--3 Create a procedure language function called "new_movie" that takes a movie title as a parameter and inserts a new movie with the given title in the film table.
-- The function should generate a new unique film ID, set the rental rate to 4.99, the rental duration to three days, the replacement cost to 19.99,
-- the release year to the current year, and "language" as Klingon.
-- The function should also verify that the language exists in the "language" table. Then, ensure that no such function has been created before; if so, replace it.
CREATE OR REPLACE PROCEDURE new_movie(film_title TEXT)
AS
$$
DECLARE
	rental_rate NUMERIC(4,2) := 4.99;
	rental_durtn SMALLINT := 3;
	replacmnt_cost NUMERIC(5,2) := 19.99;
	release_year YEAR := EXTRACT(YEAR FROM CURRENT_DATE);
	lang_id SMALLINT;
	id_check SMALLINT;
BEGIN
	SELECT film_id INTO id_check
	FROM film
	WHERE title = film_title;

	IF id_check IS NOT NULL THEN
		RAISE EXCEPTION 'Film "title" already exists in the table with id: %', id_check;
	END IF;

	SELECT language_id INTO lang_id
    FROM language
    WHERE name = 'Klingon';

	IF lang_id IS NULL THEN
		RAISE EXCEPTION 'Klingon language does not exist in the language table';
	END IF;

	INSERT INTO film(title, description, release_year, language_id, rental_duration, rental_rate, length, replacement_cost, rating, last_update)
	VALUES (
		film_title,
		'N/A',
		release_year,
		lang_id,
		rental_durtn,
		rental_rate,
		NULL,
		replacmnt_cost,
		'R',
		CURRENT_TIMESTAMP
		)
	RETURNING film_id INTO id_check;
	RAISE NOTICE '% was added to the film table with a % id', film_title, id_check; 
END;
$$ LANGUAGE plpgsql;

CALL new_movie('In Bruges')          --Проверка исключения на несуществующий язык
CALL new_movie('CHAMBER ITALIAN')    --Проверка исключения на существующий фильм

INSERT INTO language (name)			  --Добавляем язык
VALUES ('Klingon');

CALL new_movie('In Bruges')          --Пробуем добавить фильм
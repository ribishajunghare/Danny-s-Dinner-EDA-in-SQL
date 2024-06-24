

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');


SELECT *
FROM sales;

SELECT *
FROM menu;

SELECT *
FROM members;


---What is the total amount each customer spent at the restaurant?

SELECT s.customer_id AS customer, SUM(m.price) AS total_amount
FROM sales AS s
INNER JOIN menu AS m
ON s.product_id = m.product_id
GROUP BY s.customer_id 
ORDER BY 2 DESC;

---How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT(order_date)) AS no_of_days_visited
FROM sales
GROUP BY customer_id
ORDER BY 2 DESC;

---What was the first item from the menu purchased by each customer?

SELECT s.customer_id,
    STRING_AGG(m.product_name, ',') AS first_purchases
FROM (
    SELECT customer_id, MIN(order_date) AS first_order_date
    FROM sales
    GROUP BY customer_id
) AS first_orders
JOIN sales AS s ON s.customer_id = first_orders.customer_id AND s.order_date = first_orders.first_order_date
JOIN menu AS m ON s.product_id = m.product_id
GROUP BY s.customer_id;

------OR-----------

WITH first_purchase_cte AS (
    SELECT customer_id, MIN(order_date) AS first_order_date
    FROM sales
    GROUP BY customer_id
)

SELECT s.customer_id,STRING_AGG(m.product_name, ',') AS first_purchases
FROM first_purchase_cte AS f
JOIN sales AS s ON s.customer_id = f.customer_id AND s.order_date = f.first_order_date
JOIN menu AS m ON s.product_id = m.product_id
GROUP BY s.customer_id;

---What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT TOP (1) m.product_name AS most_purchased_item,COUNT(*) AS purchase_count
FROM sales AS s
JOIN menu AS m 
ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY purchase_count DESC

---Which item was the most popular for each customer?

WITH ranked_items AS (
    SELECT s.customer_id,m.product_name,COUNT(*) AS purchase_count,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY COUNT(*) DESC) AS rank
    FROM sales AS s
    JOIN menu AS m ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
)

SELECT customer_id,product_name AS most_popular_item
FROM ranked_items
WHERE rank = 1;

---Which item was purchased first by the customer after they became a member?

WITH first_purchase_after_membership AS (
    SELECT s.customer_id,m.product_name,s.order_date,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS rank
    FROM sales AS s
    JOIN menu AS m ON s.product_id = m.product_id
    JOIN members AS mem ON s.customer_id = mem.customer_id
    WHERE s.order_date >= mem.join_date
)

SELECT customer_id,product_name AS first_purchase_after_membership
FROM first_purchase_after_membership
WHERE rank = 1;


---Which item was purchased just before the customer became a member?

WITH previous_purchase AS (
    SELECT s.customer_id,m.product_name,s.order_date,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rnk
    FROM sales AS s
    JOIN menu AS m ON s.product_id = m.product_id
    LEFT JOIN members AS mem ON s.customer_id = mem.customer_id
    WHERE s.order_date < mem.join_date 
)

SELECT 
    customer_id,
    STRING_AGG(product_name, ',') AS last_purchase_before_membership
FROM previous_purchase
WHERE rnk = 1
GROUP BY customer_id;


---What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id,COUNT(*) AS total_items,SUM(m.price) AS total_amount_spent
FROM sales AS s
JOIN menu AS m ON s.product_id = m.product_id
JOIN members AS mem ON s.customer_id = mem.customer_id
WHERE s.order_date < mem.join_date
GROUP BY s.customer_id;

---If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?


SELECT s.customer_id,
        SUM(CASE WHEN m.product_name = 'sushi' THEN m.price * 2 
		WHEN m.product_name IN ('curry','ramen') THEN m.price * 10
	    END ) AS points_earned
FROM sales AS s
JOIN menu AS m ON s.product_id = m.product_id
GROUP BY s.customer_id;

---In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi 
-- how many points do customer A and B have at the end of January?

WITH points_earned AS (
    SELECT 
        s.customer_id,
        SUM(CASE 
                WHEN s.order_date <= DATEADD(WEEK, 1, mem.join_date) THEN m.price * 2 
                ELSE m.price 
            END) * 10 AS total_points
    FROM 
        sales AS s
    JOIN 
        menu AS m ON s.product_id = m.product_id
    JOIN 
        members AS mem ON s.customer_id = mem.customer_id
    WHERE 
        s.order_date <= '2021-01-31' AND
        (s.order_date <= DATEADD(WEEK, 1, mem.join_date) OR s.order_date > mem.join_date)
    GROUP BY 
        s.customer_id
)

SELECT 
    customer_id,
    total_points
FROM 
    points_earned;

-- Лаба 4 ★★. Row Level Security: покупатель видит только свои чеки.
-- Запуск: dbcheck run demo/rls.sql

-- 1. Суперпользователь видит все чеки
-- expect: rows >= 1
SELECT count(*) AS all_sales FROM sales;

-- 2. Сколько чеков у Иванова (покупатель 1) на самом деле
SELECT count(*) AS ivanov_sales FROM sales WHERE customer_id = 1;

-- 3. Под ролью покупателя Иванова видно только его чеки: столько же, сколько в шаге 2
-- expect: same 2
SET app.customer_id = '1';
SET ROLE pharmacy_client;
SELECT count(*) AS ivanov_sales FROM sales;

-- 4. Чужих чеков среди видимых нет
-- expect: value 0
SELECT count(*) FROM sales WHERE customer_id <> 1;

-- 5. Другой покупатель (Петрова, 2) видит свои
-- expect: true
RESET ROLE;
SET app.customer_id = '2';
SET ROLE pharmacy_client;
SELECT bool_and(customer_id = 2) FROM sales;

-- 6. Возвращаемся к суперпользователю
RESET ROLE;
RESET app.customer_id;
SELECT current_user;

-- Лаба 2. Запросы к базе аптеки. Формат описан в docs/scenarios.md.
-- Запуск: dbcheck run demo/lab2.sql --sql, или в psql: \i /demo/lab2.sql
-- Запросы, которые меняют данные, обёрнуты в BEGIN; ... ROLLBACK; и ничего не портят.

-- 1. Каталог: какие препараты продаются, кто их производит и из какой страны?
-- expect: rows 12
SELECT d.name AS drug, m.name AS manufacturer, m.country, d.price, d.is_prescription
FROM drugs d
JOIN manufacturers m ON m.id = d.manufacturer_id
ORDER BY d.name;

-- 2. Что выписано в каждом рецепте: номер, пациент, врач, препарат и количество?
-- expect: rows 14
SELECT p.number, c.full_name AS patient, p.doctor, d.name AS drug, pi.quantity
FROM prescriptions p
JOIN customers c ON c.id = p.customer_id
JOIN prescription_items pi ON pi.prescription_id = p.id
JOIN drugs d ON d.id = pi.drug_id
ORDER BY p.number, d.name;

-- 3. Какие рецептурные препараты продали, кому и по какому рецепту?
-- expect: rows >= 7
SELECT s.id AS sale_id, s.sold_at, c.full_name AS customer, p.number AS prescription, d.name AS drug, si.quantity
FROM sales s
JOIN sale_items si ON si.sale_id = s.id
JOIN drugs d ON d.id = si.drug_id
JOIN prescriptions p ON p.id = s.prescription_id
JOIN customers c ON c.id = s.customer_id
WHERE d.is_prescription
ORDER BY s.sold_at;

-- 4. Сколько упаковок каждого препарата продано и на какую сумму?
-- expect: rows 12
SELECT d.name, sum(si.quantity) AS packs, sum(si.quantity * si.price) AS revenue
FROM drugs d
JOIN sale_items si ON si.drug_id = d.id
GROUP BY d.id, d.name
ORDER BY revenue DESC;

-- 5. Какие производители принесли аптеке больше 100 000 рублей выручки?
-- expect: rows 3
SELECT m.name, sum(si.quantity * si.price) AS revenue
FROM manufacturers m
JOIN drugs d ON d.manufacturer_id = m.id
JOIN sale_items si ON si.drug_id = d.id
GROUP BY m.id, m.name
HAVING sum(si.quantity * si.price) > 100000
ORDER BY revenue DESC;

-- 6. У каких производителей нет ни одного препарата в каталоге?
-- expect: rows 1
SELECT m.name, m.country
FROM manufacturers m
LEFT JOIN drugs d ON d.manufacturer_id = m.id
WHERE d.id IS NULL;

-- 7. По каким рецептам ещё ничего не купили?
-- expect: rows 3
SELECT p.number, p.issued_on, p.valid_until
FROM prescriptions p
WHERE NOT EXISTS (SELECT 1 FROM sales s WHERE s.prescription_id = p.id)
ORDER BY p.number;

-- 8. Какие препараты дороже средней цены по каталогу?
-- expect: rows >= 1
SELECT name, price
FROM drugs
WHERE price > (SELECT avg(price) FROM drugs)
ORDER BY price DESC;

-- 9. Какие покупатели хоть раз покупали рецептурные препараты?
-- expect: rows >= 1
SELECT full_name, phone
FROM customers
WHERE id IN (
    SELECT s.customer_id
    FROM sales s
    JOIN sale_items si ON si.sale_id = s.id
    JOIN drugs d ON d.id = si.drug_id
    WHERE d.is_prescription
)
ORDER BY full_name;

-- 10. Пришла новая поставка Нурофена: сколько поставок было до и после?
BEGIN;
SELECT count(*) AS supplies_before FROM supplies;
INSERT INTO supplies (drug_id, supplied_at, quantity, purchase_price)
VALUES ((SELECT id FROM drugs WHERE name = 'Нурофен 200 мг №10'), now(), 50, 125.00);
SELECT count(*) AS supplies_after FROM supplies;
ROLLBACK;

-- 11. Отисифарм поднял цены на 5%: какие цены у его препаратов до и после?
BEGIN;
SELECT d.name, d.price AS price_before
FROM drugs d JOIN manufacturers m ON m.id = d.manufacturer_id
WHERE m.name = 'Отисифарм';
UPDATE drugs SET price = round(price * 1.05, 2)
WHERE manufacturer_id = (SELECT id FROM manufacturers WHERE name = 'Отисифарм');
SELECT d.name, d.price AS price_after
FROM drugs d JOIN manufacturers m ON m.id = d.manufacturer_id
WHERE m.name = 'Отисифарм';
ROLLBACK;

-- 12. Удаляем рецепт Р-2026-0008, по которому ничего не купили: сколько строк в составе рецептов до и после?
BEGIN;
SELECT count(*) AS items_before FROM prescription_items;
DELETE FROM prescriptions WHERE number = 'Р-2026-0008';
SELECT count(*) AS items_after FROM prescription_items;
ROLLBACK;

-- 13. Топ-3 самых продаваемых препарата в каждом месяце
-- expect: rows >= 3
WITH monthly AS (
    SELECT date_trunc('month', s.sold_at)::date AS month,
           d.name AS drug,
           sum(si.quantity) AS packs
    FROM sales s
    JOIN sale_items si ON si.sale_id = s.id
    JOIN drugs d ON d.id = si.drug_id
    GROUP BY 1, d.id, d.name
),
ranked AS (
    SELECT month, drug, packs,
           ROW_NUMBER() OVER (PARTITION BY month ORDER BY packs DESC, drug) AS place
    FROM monthly
)
SELECT month, place, drug, packs
FROM ranked
WHERE place <= 3
ORDER BY month, place;

-- 14. Выручка по месяцам и накопительный итог с начала года
-- expect: rows >= 2
WITH monthly AS (
    SELECT date_trunc('month', s.sold_at)::date AS month,
           sum(si.quantity * si.price) AS revenue
    FROM sales s
    JOIN sale_items si ON si.sale_id = s.id
    GROUP BY 1
)
SELECT month,
       revenue,
       SUM(revenue) OVER (ORDER BY month) AS revenue_total
FROM monthly
ORDER BY month;

-- 15. Помесячная динамика: выручка, выручка прошлого месяца и изменение в процентах
-- expect: rows >= 2
WITH monthly AS (
    SELECT date_trunc('month', s.sold_at)::date AS month,
           sum(si.quantity * si.price) AS revenue
    FROM sales s
    JOIN sale_items si ON si.sale_id = s.id
    GROUP BY 1
)
SELECT month,
       revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
       round(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month)) / LAG(revenue) OVER (ORDER BY month), 1) AS change_pct
FROM monthly
ORDER BY month;

-- 16. Календарь продаж за октябрь 2026: каждый день, включая дни без продаж
-- expect: rows 31
WITH RECURSIVE days AS (
    SELECT date '2026-10-01' AS day
    UNION ALL
    SELECT day + 1 FROM days WHERE day < date '2026-10-31'
)
SELECT d.day, count(s.id) AS sales
FROM days d
LEFT JOIN sales s ON s.sold_at::date = d.day
GROUP BY d.day
ORDER BY d.day;

-- Лаба 1 ★★. Массовые данные через generate_series: 1500 продаж и 1500 позиций.
-- Генерируем только безрецептурные покупки, чтобы не нарушать правило про рецепты.

-- Продажи с января 2026 года, примерно раз в 2 часа. Каждый третий чек - с известным покупателем
INSERT INTO sales (sold_at, customer_id, prescription_id, payment_method)
SELECT timestamptz '2026-01-01 09:00+03' + g * interval '137 minutes',
       CASE WHEN g % 3 = 0 THEN g % 10 + 1 END,
       NULL,
       CASE WHEN g % 2 = 0 THEN 'card' ELSE 'cash' END
FROM generate_series(1, 1500) AS g;

-- По одной позиции в каждом новом чеке: безрецептурный препарат по кругу, 1-3 упаковки
INSERT INTO sale_items (sale_id, drug_id, quantity, price)
SELECT s.id, d.id, 1 + s.id % 3, d.price
FROM sales s
CROSS JOIN LATERAL (
    SELECT id, price
    FROM drugs
    WHERE NOT is_prescription
    ORDER BY id
    OFFSET s.id % 7
    LIMIT 1
) d
WHERE NOT EXISTS (SELECT 1 FROM sale_items si WHERE si.sale_id = s.id);

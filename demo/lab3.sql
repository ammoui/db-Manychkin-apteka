-- Лаба 3. Логика в базе аптеки. Формат описан в docs/scenarios.md.
-- Запуск: dbcheck run demo/lab3.sql --sql, или в psql: \i /demo/lab3.sql
-- Изменения обёрнуты в BEGIN; ... ROLLBACK; и ничего не портят.

-- 1. Карточки последних чеков из представления v_sale_card
-- expect: rows 5
SELECT sale_id, sold_at, customer, prescription, positions, total
FROM v_sale_card
WHERE prescription IS NOT NULL
ORDER BY sold_at DESC
LIMIT 5;

-- 2. По каким рецептам ещё можно что-то купить (представление v_prescription_balance)
-- expect: rows >= 1
SELECT number, patient, drug, prescribed, sold, remaining
FROM v_prescription_balance
WHERE remaining > 0
ORDER BY number;

-- 3. Сумма чека №7 (функция sale_total): Кавинтон 520 + Аторис 450
-- expect: value 970.00
SELECT sale_total(7);

-- 4. Сколько Ципрофлоксацина ещё можно продать по рецепту Р-2026-0008 (функция prescription_remaining)
-- expect: value 1
SELECT prescription_remaining(8, 10);

-- 5. Бизнес-операция: продаём по рецепту Р-2026-0008 Ципрофлоксацин, остаток был 1, стал 0
BEGIN;
SELECT prescription_remaining(8, 10) AS remaining_before;
SELECT sell_by_prescription(8, 10, 1, 'card') AS new_sale_id;
SELECT sale_id, customer, prescription, total FROM v_sale_card WHERE sale_id = currval(pg_get_serial_sequence('sales', 'id'));
SELECT prescription_remaining(8, 10) AS remaining_after;
ROLLBACK;

-- 6. Аториса нет в рецепте Р-2026-0001: ошибка триггера
-- expect: error "нет в рецепте"
SELECT sell_by_prescription(1, 6, 1);

-- 7. По рецепту Р-2026-0002 Аторис уже продан (1 из 1): продать ещё нельзя
-- expect: error "нельзя продать ещё"
SELECT sell_by_prescription(2, 6, 1);

-- 8. Рецептурный Амоксициллин без рецепта: ошибка триггера
-- expect: error "только по рецепту"
WITH s AS (INSERT INTO sales (payment_method) VALUES ('cash') RETURNING id)
INSERT INTO sale_items (sale_id, drug_id, quantity, price)
SELECT id, 4, 1, 160.00 FROM s;

-- 9. Служебный триггер: при смене цены Нурофена updated_at обновляется сам
BEGIN;
SELECT name, price, updated_at AS updated_before FROM drugs WHERE id = 2;
UPDATE drugs SET price = 190.00 WHERE id = 2;
SELECT name, price, updated_at AS updated_after FROM drugs WHERE id = 2;
ROLLBACK;

-- 10. ★ Материализованный отчёт не меняется после продажи, пока его не обновить
BEGIN;
SELECT sum(revenue) AS report_before FROM mv_monthly_revenue;
SELECT sell_by_prescription(8, 10, 1, 'card');
SELECT sum(revenue) AS report_not_refreshed FROM mv_monthly_revenue;
REFRESH MATERIALIZED VIEW mv_monthly_revenue;
SELECT sum(revenue) AS report_after_refresh FROM mv_monthly_revenue;
ROLLBACK;

-- 11. ★ Поиск продаж с фильтрами: только покупатель Иванов, остальные фильтры не переданы
-- expect: rows >= 1
SELECT * FROM find_sales(p_customer_id => 1);

-- 12. ★ Поиск продаж за 1-5 октября картой
-- expect: rows >= 1
SELECT * FROM find_sales(date '2026-10-01', date '2026-10-05', NULL, 'card');

-- 13. ★★ Журнал: продажа и смена способа оплаты записываются в sales_log
BEGIN;
SELECT sell_by_prescription(8, 10, 1, 'card');
UPDATE sales SET payment_method = 'cash' WHERE id = currval(pg_get_serial_sequence('sales', 'id'));
SELECT operation,
       old_data ->> 'payment_method' AS old_payment,
       new_data ->> 'payment_method' AS new_payment,
       changed_by, changed_at
FROM sales_log
WHERE sale_id = currval(pg_get_serial_sequence('sales', 'id'))
ORDER BY id;
ROLLBACK;

-- 14. ★★ Состояние чека на момент времени: сразу после продажи оплата была картой, сейчас наличными
BEGIN;
SELECT sell_by_prescription(8, 10, 1, 'card');
UPDATE sales SET payment_method = 'cash' WHERE id = currval(pg_get_serial_sequence('sales', 'id'));
SELECT sale_state_at(currval(pg_get_serial_sequence('sales', 'id'))::int,
                     (SELECT changed_at FROM sales_log
                      WHERE sale_id = currval(pg_get_serial_sequence('sales', 'id')) AND operation = 'INSERT')
                    ) ->> 'payment_method' AS at_sale_time,
       sale_state_at(currval(pg_get_serial_sequence('sales', 'id'))::int, clock_timestamp()) ->> 'payment_method' AS now;
ROLLBACK;

-- Лаба 1. Сценарий для показа. Формат описан в docs/scenarios.md.
-- Запуск: dbcheck run demo/lab1.sql, или в psql: \i /demo/lab1.sql
-- Файл без BEGIN/COMMIT, поэтому всё откатывается и база не меняется.

-- 1. Таблицы на месте: 8 таблиц
-- expect: rows 8
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY 1;

-- 2. Рецепт с уже существующим номером: ошибка UNIQUE
-- expect: error unique
INSERT INTO prescriptions (number, customer_id, doctor, issued_on, valid_until)
VALUES ('Р-2026-0001', 2, 'Белов А. М.', '2026-10-10', '2026-12-09');

-- 3. Препарат с отрицательной ценой: ошибка CHECK
-- expect: error check
INSERT INTO drugs (name, manufacturer_id, is_prescription, price)
VALUES ('Парацетамол 500 мг №10', 1, false, -50.00);

-- 4. Препарат несуществующего производителя: ошибка внешнего ключа
-- expect: error fk
INSERT INTO drugs (name, manufacturer_id, is_prescription, price)
VALUES ('Парацетамол 500 мг №10', 999, false, 50.00);

-- 5. Удалить производителя, у которого есть препараты, нельзя (ON DELETE RESTRICT)
-- expect: error fk
DELETE FROM manufacturers WHERE name = 'Bayer';

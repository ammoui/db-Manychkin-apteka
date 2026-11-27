-- Лаба 4. Транзакции и права. Формат описан в docs/scenarios.md.
-- Запуск: dbcheck run demo/lab4.sql --sql

-- 1. Сумма цен в каталоге до транзакции
SELECT sum(price) AS catalog_sum FROM drugs;

-- 2. Транзакция: поднимаем все цены на 10 ₽, потом добавляем препарат с ценой -1. Вторая команда падает на CHECK, вся транзакция отменяется
-- expect: error check
BEGIN;
UPDATE drugs SET price = price + 10;
INSERT INTO drugs (name, manufacturer_id, is_prescription, price) VALUES ('Ошибочный препарат', 1, false, -1);
COMMIT;

-- 3. Цены не изменились: подорожание тоже откатилось
-- expect: same 1
SELECT sum(price) AS catalog_sum FROM drugs;

-- 4. app_reader читает представление
-- expect: rows >= 1
SET ROLE app_reader;
SELECT number, drug, remaining FROM v_prescription_balance WHERE remaining > 0;

-- 5. app_reader не может читать таблицу напрямую
-- expect: error permission
SELECT * FROM customers;

-- 6. app_reader не может менять цены
-- expect: error permission
UPDATE drugs SET price = 1;

-- 7. app_writer не может вставить продажу в таблицу напрямую
-- expect: error permission
RESET ROLE;
SET ROLE app_writer;
INSERT INTO sales (payment_method) VALUES ('cash');

-- 8. app_writer продаёт через бизнес-операцию: это разрешено (откатываем, чтобы не портить данные)
-- expect: rows 1
RESET ROLE;
BEGIN;
SET ROLE app_writer;
SELECT sell_by_prescription(8, 10, 1, 'card') AS sale_id;
ROLLBACK;

-- 9. После отката роль снова postgres
SELECT current_user;

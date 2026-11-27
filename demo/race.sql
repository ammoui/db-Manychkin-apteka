-- Лаба 4. Гонка: два фармацевта одновременно продают по одному рецепту.
-- По рецепту выписана 1 упаковка Аториса. Оба продают её «напрямую» вставками, правило проверяет только триггер.
-- Запуск: dbcheck run demo/race.sql

-- [setup] Рецепт RACE-TEST: 1 упаковка Аториса (препарат 6), продаж по нему нет
DELETE FROM sale_items WHERE sale_id IN (SELECT s.id FROM sales s JOIN prescriptions p ON p.id = s.prescription_id WHERE p.number = 'RACE-TEST');
DELETE FROM sales WHERE prescription_id IN (SELECT id FROM prescriptions WHERE number = 'RACE-TEST');
DELETE FROM prescriptions WHERE number = 'RACE-TEST';
INSERT INTO prescriptions (number, customer_id, doctor, issued_on, valid_until)
VALUES ('RACE-TEST', 1, 'Орлова Т. В.', current_date, current_date + 30);
INSERT INTO prescription_items (prescription_id, drug_id, quantity)
SELECT id, 6, 1 FROM prescriptions WHERE number = 'RACE-TEST';

-- [A] Окно A: создаёт чек по рецепту
BEGIN;
INSERT INTO sales (customer_id, prescription_id, payment_method)
SELECT customer_id, id, 'cash' FROM prescriptions WHERE number = 'RACE-TEST';

-- [B] Окно B в тот же момент: тоже создаёт чек
BEGIN;
INSERT INTO sales (customer_id, prescription_id, payment_method)
SELECT customer_id, id, 'card' FROM prescriptions WHERE number = 'RACE-TEST';

-- [A] Окно A добавляет упаковку: триггер видит 0 проданных из 1, пропускает
INSERT INTO sale_items (sale_id, drug_id, quantity, price)
VALUES (currval(pg_get_serial_sequence('sales', 'id')), 6, 1, 450.00);

-- [B] Окно B тоже: продажа окна A ещё не зафиксирована, триггер её не видит и тоже пропускает
INSERT INTO sale_items (sale_id, drug_id, quantity, price)
VALUES (currval(pg_get_serial_sequence('sales', 'id')), 6, 1, 450.00);

-- [A]
COMMIT;

-- [B]
COMMIT;

-- [check] Продано не больше, чем выписано?
-- expect: false
SELECT sold <= prescribed FROM v_prescription_balance WHERE number = 'RACE-TEST';

-- [cleanup]
DELETE FROM sale_items WHERE sale_id IN (SELECT s.id FROM sales s JOIN prescriptions p ON p.id = s.prescription_id WHERE p.number = 'RACE-TEST');
DELETE FROM sales WHERE prescription_id IN (SELECT id FROM prescriptions WHERE number = 'RACE-TEST');
DELETE FROM prescriptions WHERE number = 'RACE-TEST';

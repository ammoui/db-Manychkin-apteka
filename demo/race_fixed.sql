-- Лаба 4. Та же ситуация, но оба фармацевта продают через sell_by_prescription,
-- которая блокирует позицию рецепта (SELECT ... FOR UPDATE). Окно B ждёт окно A.
-- Запуск: dbcheck run demo/race_fixed.sql

-- [setup] Рецепт RACE-TEST: 1 упаковка Аториса (препарат 6), продаж по нему нет
DELETE FROM sale_items WHERE sale_id IN (SELECT s.id FROM sales s JOIN prescriptions p ON p.id = s.prescription_id WHERE p.number = 'RACE-TEST');
DELETE FROM sales WHERE prescription_id IN (SELECT id FROM prescriptions WHERE number = 'RACE-TEST');
DELETE FROM prescriptions WHERE number = 'RACE-TEST';
INSERT INTO prescriptions (number, customer_id, doctor, issued_on, valid_until)
VALUES ('RACE-TEST', 1, 'Орлова Т. В.', current_date, current_date + 30);
INSERT INTO prescription_items (prescription_id, drug_id, quantity)
SELECT id, 6, 1 FROM prescriptions WHERE number = 'RACE-TEST';

-- [A] Окно A: продаёт упаковку, позиция рецепта заблокирована до конца транзакции
BEGIN;
SELECT sell_by_prescription((SELECT id FROM prescriptions WHERE number = 'RACE-TEST'), 6, 1, 'cash');

-- [B] Окно B в тот же момент: ждёт, пока окно A отпустит позицию рецепта
-- expect: blocked
BEGIN;
SELECT sell_by_prescription((SELECT id FROM prescriptions WHERE number = 'RACE-TEST'), 6, 1, 'card');

-- [A] Окно A фиксирует продажу и снимает блокировку. Окно B продолжает и видит, что продано 1 из 1: ошибка триггера
COMMIT;

-- [B]
ROLLBACK;

-- [check] Продано не больше, чем выписано?
-- expect: true
SELECT sold <= prescribed FROM v_prescription_balance WHERE number = 'RACE-TEST';

-- [cleanup]
DELETE FROM sale_items WHERE sale_id IN (SELECT s.id FROM sales s JOIN prescriptions p ON p.id = s.prescription_id WHERE p.number = 'RACE-TEST');
DELETE FROM sales WHERE prescription_id IN (SELECT id FROM prescriptions WHERE number = 'RACE-TEST');
DELETE FROM prescriptions WHERE number = 'RACE-TEST';

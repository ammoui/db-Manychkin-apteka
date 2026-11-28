-- Лаба 4 ★. READ COMMITTED (по умолчанию): каждый запрос видит то, что зафиксировано к его началу.
-- Окно A дважды читает цену Нурофена, между чтениями окно B её меняет.

-- [setup]
UPDATE drugs SET price = 180.00 WHERE id = 2;

-- [A] Первое чтение
-- expect: value 180.00
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT price FROM drugs WHERE id = 2;

-- [B] Цена меняется и фиксируется
UPDATE drugs SET price = 200.00 WHERE id = 2;

-- [A] Второе чтение в той же транзакции видит новую цену: неповторяющееся чтение
-- expect: value 200.00
SELECT price FROM drugs WHERE id = 2;
COMMIT;

-- [cleanup]
UPDATE drugs SET price = 180.00 WHERE id = 2;

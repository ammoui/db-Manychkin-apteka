-- Лаба 4 ★. REPEATABLE READ: вся транзакция видит данные на момент первого запроса.
-- Те же шаги, что в isolation_rc.sql, но второе чтение возвращает прежнюю цену.

-- [setup]
UPDATE drugs SET price = 180.00 WHERE id = 2;

-- [A] Первое чтение
-- expect: value 180.00
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT price FROM drugs WHERE id = 2;

-- [B] Цена меняется и фиксируется
UPDATE drugs SET price = 200.00 WHERE id = 2;

-- [A] Второе чтение в той же транзакции: цена прежняя
-- expect: value 180.00
SELECT price FROM drugs WHERE id = 2;
COMMIT;

-- [cleanup]
UPDATE drugs SET price = 180.00 WHERE id = 2;

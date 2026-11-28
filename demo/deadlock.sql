-- Лаба 4 ★. Взаимоблокировка: два окна меняют цены двух препаратов в разном порядке.

-- [setup]
UPDATE drugs SET price = 520.00 WHERE id = 1;
UPDATE drugs SET price = 180.00 WHERE id = 2;

-- [A] Окно A блокирует Арбидол
BEGIN;
UPDATE drugs SET price = price + 1 WHERE id = 1;

-- [B] Окно B блокирует Нурофен
BEGIN;
UPDATE drugs SET price = price + 1 WHERE id = 2;

-- [A] Окно A хочет Нурофен и ждёт окно B
-- expect: blocked
UPDATE drugs SET price = price + 1 WHERE id = 2;

-- [B] Окно B хочет Арбидол и ждёт окно A: круг замкнулся, база отменяет одну из транзакций
-- expect: error deadlock
UPDATE drugs SET price = price + 1 WHERE id = 1;

-- [B]
ROLLBACK;

-- [A]
ROLLBACK;

-- [cleanup]
UPDATE drugs SET price = 520.00 WHERE id = 1;
UPDATE drugs SET price = 180.00 WHERE id = 2;

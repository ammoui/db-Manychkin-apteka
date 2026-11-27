-- Лаба 3. Функции и бизнес-операция.

-- Сумма чека
CREATE FUNCTION sale_total(p_sale_id integer) RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT coalesce(sum(quantity * price), 0) FROM sale_items WHERE sale_id = p_sale_id;
$$;

-- Сколько упаковок препарата ещё можно продать по рецепту
CREATE FUNCTION prescription_remaining(p_prescription_id integer, p_drug_id integer) RETURNS integer
LANGUAGE sql STABLE AS $$
    SELECT coalesce((SELECT remaining FROM v_prescription_balance
                     WHERE prescription_id = p_prescription_id AND drug_id = p_drug_id), 0)::integer;
$$;

-- Бизнес-операция: продажа препарата по рецепту одной командой.
-- Создаёт чек и позицию по текущей цене, возвращает номер чека.
-- Правило (препарат есть в рецепте, рецепт действует, не больше выписанного) проверяет триггер.
CREATE FUNCTION sell_by_prescription(p_prescription_id integer, p_drug_id integer,
                                     p_quantity integer, p_payment text DEFAULT 'card')
RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    v_sale_id integer;
BEGIN
    INSERT INTO sales (customer_id, prescription_id, payment_method)
    SELECT customer_id, id, p_payment FROM prescriptions WHERE id = p_prescription_id
    RETURNING id INTO v_sale_id;

    IF v_sale_id IS NULL THEN
        RAISE EXCEPTION 'Рецепт % не найден', p_prescription_id;
    END IF;

    INSERT INTO sale_items (sale_id, drug_id, quantity, price)
    SELECT v_sale_id, id, p_quantity, price FROM drugs WHERE id = p_drug_id;

    RETURN v_sale_id;
END $$;

-- ★ Поиск продаж по фильтрам. Любой фильтр можно не передавать (NULL = без фильтра)
CREATE FUNCTION find_sales(p_from date DEFAULT NULL, p_to date DEFAULT NULL,
                           p_customer_id integer DEFAULT NULL, p_payment text DEFAULT NULL)
RETURNS TABLE (sale_id integer, sold_at timestamptz, customer text, payment_method text, total numeric)
LANGUAGE sql STABLE AS $$
    SELECT v.sale_id, v.sold_at, v.customer, v.payment_method, v.total
    FROM v_sale_card v
    JOIN sales s ON s.id = v.sale_id
    WHERE (p_from IS NULL OR v.sold_at >= p_from)
      AND (p_to IS NULL OR v.sold_at < p_to + 1)
      AND (p_customer_id IS NULL OR s.customer_id = p_customer_id)
      AND (p_payment IS NULL OR v.payment_method = p_payment)
    ORDER BY v.sold_at;
$$;

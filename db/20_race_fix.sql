-- Лаба 4. Исправление гонки при продаже по рецепту.
-- Проблема: два фармацевта одновременно продают по одному рецепту. Триггер каждого не видит
-- незафиксированную продажу другого, и вместе они продают больше, чем выписано.
-- Исправление: операция сначала блокирует строку рецепта (SELECT ... FOR UPDATE).
-- Вторая продажа по тому же рецепту ждёт, пока первая завершится, и потом видит её в подсчёте.

CREATE OR REPLACE FUNCTION sell_by_prescription(p_prescription_id integer, p_drug_id integer,
                                                p_quantity integer, p_payment text DEFAULT 'card')
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
    v_sale_id integer;
BEGIN
    -- общая строка, за которую конкурируют продажи: позиция рецепта
    PERFORM 1 FROM prescription_items
    WHERE prescription_id = p_prescription_id AND drug_id = p_drug_id
    FOR UPDATE;

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

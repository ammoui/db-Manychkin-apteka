-- Лаба 3. Триггеры: бизнес-правило, служебное поле, журнал изменений.

-- Правило темы: рецептурный препарат продаётся только по рецепту, в котором он есть,
-- пока рецепт действует, и не больше выписанного количества
CREATE FUNCTION check_prescription_sale() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_rx          boolean;
    v_presc_id    integer;
    v_sold_at     timestamptz;
    v_issued      date;
    v_valid       date;
    v_prescribed  integer;
    v_sold        integer;
BEGIN
    SELECT is_prescription INTO v_rx FROM drugs WHERE id = NEW.drug_id;
    IF v_rx IS NOT TRUE THEN
        RETURN NEW;  -- безрецептурный или препарата нет (тогда ошибку вернёт внешний ключ)
    END IF;

    SELECT prescription_id, sold_at INTO v_presc_id, v_sold_at FROM sales WHERE id = NEW.sale_id;
    IF v_presc_id IS NULL THEN
        RAISE EXCEPTION 'Препарат % продаётся только по рецепту', NEW.drug_id;
    END IF;

    SELECT p.issued_on, p.valid_until, pi.quantity
    INTO v_issued, v_valid, v_prescribed
    FROM prescriptions p
    LEFT JOIN prescription_items pi ON pi.prescription_id = p.id AND pi.drug_id = NEW.drug_id
    WHERE p.id = v_presc_id;

    IF v_prescribed IS NULL THEN
        RAISE EXCEPTION 'Препарата % нет в рецепте %', NEW.drug_id, v_presc_id;
    END IF;

    IF v_sold_at::date NOT BETWEEN v_issued AND v_valid THEN
        RAISE EXCEPTION 'Рецепт % не действует на %', v_presc_id, v_sold_at::date;
    END IF;

    SELECT coalesce(sum(si.quantity), 0) INTO v_sold
    FROM sale_items si
    JOIN sales s ON s.id = si.sale_id
    WHERE s.prescription_id = v_presc_id AND si.drug_id = NEW.drug_id
      AND NOT (si.sale_id = NEW.sale_id AND TG_OP = 'UPDATE');

    IF v_sold + NEW.quantity > v_prescribed THEN
        RAISE EXCEPTION 'По рецепту % выписано % уп., уже продано %, нельзя продать ещё %',
            v_presc_id, v_prescribed, v_sold, NEW.quantity;
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER trg_check_prescription_sale
BEFORE INSERT OR UPDATE ON sale_items
FOR EACH ROW EXECUTE FUNCTION check_prescription_sale();

-- Служебный триггер: время последнего изменения препарата (например, цены)
ALTER TABLE drugs ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();

CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;

CREATE TRIGGER trg_drugs_updated_at
BEFORE UPDATE ON drugs
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ★★ Журнал изменений главной таблицы sales: что было, что стало, кто и когда
CREATE TABLE sales_log (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operation  text NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    sale_id    integer NOT NULL,
    old_data   jsonb,
    new_data   jsonb,
    changed_by text NOT NULL DEFAULT session_user,
    changed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE FUNCTION log_sales_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO sales_log (operation, sale_id, old_data, new_data)
    VALUES (TG_OP,
            coalesce(NEW.id, OLD.id),
            CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END,
            CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END);
    RETURN NULL;
END $$;

CREATE TRIGGER trg_sales_log
AFTER INSERT OR UPDATE OR DELETE ON sales
FOR EACH ROW EXECUTE FUNCTION log_sales_change();

-- ★★ Состояние чека на момент времени по журналу. NULL, если чека тогда не было
CREATE FUNCTION sale_state_at(p_sale_id integer, p_at timestamptz) RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT new_data
    FROM sales_log
    WHERE sale_id = p_sale_id AND changed_at <= p_at
    ORDER BY changed_at DESC, id DESC
    LIMIT 1;
$$;

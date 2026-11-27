-- Лаба 3. Представления для частых запросов.

-- Карточка чека: когда, кто купил, по какому рецепту, сколько позиций и на какую сумму
CREATE VIEW v_sale_card AS
SELECT s.id AS sale_id,
       s.sold_at,
       c.full_name AS customer,
       p.number AS prescription,
       s.payment_method,
       count(si.drug_id) AS positions,
       coalesce(sum(si.quantity * si.price), 0) AS total
FROM sales s
LEFT JOIN customers c ON c.id = s.customer_id
LEFT JOIN prescriptions p ON p.id = s.prescription_id
LEFT JOIN sale_items si ON si.sale_id = s.id
GROUP BY s.id, c.full_name, p.number;

-- Остаток по рецептам: сколько выписано, сколько уже продано и сколько ещё можно продать
CREATE VIEW v_prescription_balance AS
SELECT p.id AS prescription_id,
       p.number,
       c.full_name AS patient,
       d.id AS drug_id,
       d.name AS drug,
       pi.quantity AS prescribed,
       coalesce(sold.qty, 0) AS sold,
       pi.quantity - coalesce(sold.qty, 0) AS remaining,
       p.valid_until
FROM prescriptions p
JOIN customers c ON c.id = p.customer_id
JOIN prescription_items pi ON pi.prescription_id = p.id
JOIN drugs d ON d.id = pi.drug_id
LEFT JOIN (
    SELECT s.prescription_id, si.drug_id, sum(si.quantity) AS qty
    FROM sales s
    JOIN sale_items si ON si.sale_id = s.id
    WHERE s.prescription_id IS NOT NULL
    GROUP BY s.prescription_id, si.drug_id
) sold ON sold.prescription_id = p.id AND sold.drug_id = d.id;

-- ★ Отчёт по выручке за месяц. Хранит результат, обновляется командой REFRESH MATERIALIZED VIEW
CREATE MATERIALIZED VIEW mv_monthly_revenue AS
SELECT date_trunc('month', s.sold_at)::date AS month,
       count(DISTINCT s.id) AS sales,
       sum(si.quantity) AS packs,
       sum(si.quantity * si.price) AS revenue
FROM sales s
JOIN sale_items si ON si.sale_id = s.id
GROUP BY 1;

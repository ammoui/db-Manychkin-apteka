-- Лаба 4 ★★. Row Level Security: покупатель в личном кабинете видит только свои чеки.
-- Кто сейчас смотрит, приложение передаёт настройкой app.customer_id.
-- Владелец таблицы и суперпользователь политику не замечают.

CREATE ROLE pharmacy_client NOLOGIN;
GRANT USAGE ON SCHEMA public TO pharmacy_client;
GRANT SELECT ON sales, sale_items TO pharmacy_client;

ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY client_own_sales ON sales
    FOR SELECT TO pharmacy_client
    USING (customer_id = current_setting('app.customer_id', true)::integer);

CREATE POLICY client_own_sale_items ON sale_items
    FOR SELECT TO pharmacy_client
    USING (sale_id IN (SELECT id FROM sales));   -- sales уже отфильтрованы своей политикой

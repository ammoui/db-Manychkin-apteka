-- Лаба 4. Роли приложения. Пароли берутся из .env через \getenv, в файле их нет.
-- app_reader: только читает представления.
-- app_writer: всё, что может app_reader, плюс бизнес-операция продажи. Таблицы напрямую не меняет.

\getenv reader_password APP_READER_PASSWORD
\getenv writer_password APP_WRITER_PASSWORD

CREATE ROLE app_reader LOGIN PASSWORD :'reader_password';
CREATE ROLE app_writer LOGIN PASSWORD :'writer_password' IN ROLE app_reader;

-- по умолчанию функции может вызывать кто угодно, забираем это право
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO app_reader;

-- чтение: только представления
GRANT SELECT ON v_sale_card, v_prescription_balance, mv_monthly_revenue TO app_reader;
-- функции чтения обращаются к таблицам, поэтому работают с правами владельца
ALTER FUNCTION sale_total(integer) SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION prescription_remaining(integer, integer) SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION find_sales(date, date, integer, text) SECURITY DEFINER SET search_path = public, pg_temp;
GRANT EXECUTE ON FUNCTION sale_total(integer), prescription_remaining(integer, integer),
                          find_sales(date, date, integer, text) TO app_reader;

-- запись: только через бизнес-операцию (SECURITY DEFINER, работает с правами владельца)
GRANT EXECUTE ON FUNCTION sell_by_prescription(integer, integer, integer, text) TO app_writer;

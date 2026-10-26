-- Лаба 1. Схема базы аптеки: таблицы, ключи, ограничения.
-- Скрипты из db/ выполняются по порядку имён при первом docker compose up.
-- Таблицы идут в таком порядке, чтобы та, на которую ссылаются, создавалась раньше.

-- Производители препаратов
CREATE TABLE manufacturers (
    id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name    text NOT NULL UNIQUE,
    country text NOT NULL
);

-- Каталог препаратов: одна строка = одна позиция каталога, а не конкретная упаковка
CREATE TABLE drugs (
    id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            text NOT NULL,
    manufacturer_id integer NOT NULL REFERENCES manufacturers (id) ON DELETE RESTRICT,
    is_prescription boolean NOT NULL DEFAULT false,      -- рецептурный или нет
    price           numeric(10, 2) NOT NULL CHECK (price > 0),  -- текущая цена по прайсу
    UNIQUE (name, manufacturer_id)
);

-- Покупатели (они же пациенты, которым выписывают рецепты)
CREATE TABLE customers (
    id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name text NOT NULL,
    phone     text NOT NULL UNIQUE
);

-- Рецепты от врачей
CREATE TABLE prescriptions (
    id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    number      text NOT NULL UNIQUE,
    customer_id integer NOT NULL REFERENCES customers (id) ON DELETE RESTRICT,
    doctor      text NOT NULL,
    issued_on   date NOT NULL,
    valid_until date NOT NULL,
    CHECK (valid_until >= issued_on)
);

-- Состав рецепта: связь N:M рецепт <-> препарат
CREATE TABLE prescription_items (
    prescription_id integer NOT NULL REFERENCES prescriptions (id) ON DELETE CASCADE,
    drug_id         integer NOT NULL REFERENCES drugs (id) ON DELETE RESTRICT,
    quantity        integer NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (prescription_id, drug_id)
);

-- Поставки препаратов на склад
CREATE TABLE supplies (
    id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    drug_id        integer NOT NULL REFERENCES drugs (id) ON DELETE RESTRICT,
    supplied_at    timestamptz NOT NULL DEFAULT now(),
    quantity       integer NOT NULL CHECK (quantity > 0),
    purchase_price numeric(10, 2) NOT NULL CHECK (purchase_price > 0)
);

-- Продажи (чеки). Покупатель и рецепт могут быть не указаны:
-- безрецептурное можно купить анонимно
CREATE TABLE sales (
    id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sold_at         timestamptz NOT NULL DEFAULT now(),
    customer_id     integer REFERENCES customers (id) ON DELETE SET NULL,
    prescription_id integer REFERENCES prescriptions (id) ON DELETE RESTRICT,
    payment_method  text NOT NULL CHECK (payment_method IN ('cash', 'card'))
);

-- Позиции чека. price - цена на момент продажи, она не меняется, если потом поменяется прайс
CREATE TABLE sale_items (
    sale_id  integer NOT NULL REFERENCES sales (id) ON DELETE CASCADE,
    drug_id  integer NOT NULL REFERENCES drugs (id) ON DELETE RESTRICT,
    quantity integer NOT NULL CHECK (quantity > 0),
    price    numeric(10, 2) NOT NULL CHECK (price >= 0),
    PRIMARY KEY (sale_id, drug_id)
);

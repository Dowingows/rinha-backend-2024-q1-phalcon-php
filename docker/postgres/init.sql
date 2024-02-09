CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    limite INT,
    saldo INT
);

CREATE TABLE IF NOT EXISTS transacoes (
    id SERIAL PRIMARY KEY,
    valor INT,
    tipo CHAR(1),
    cliente_id INT,
    descricao CHAR(10),
    realizada_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id)
);


INSERT INTO clientes (limite, saldo) VALUES
(100000, 0),
(80000, 0),
(1000000, 0),
(10000000, 0),
(500000, 0);


CREATE OR REPLACE PROCEDURE realizar_transacao(
    IN p_cliente_id INT,
    IN p_valor INT,
    IN p_descricao CHAR(10),
    IN p_tipo CHAR(1)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_saldo_atual INT;
    v_limite INT;
BEGIN

    SELECT saldo, limite INTO v_saldo_atual, v_limite
    FROM clientes
    WHERE id = p_cliente_id;

    IF p_tipo = 'd' THEN
        IF (v_saldo_atual - p_valor) < (-v_limite) THEN
            RAISE EXCEPTION 'Limite disponível atingido!';
        ELSE
            UPDATE clientes
            SET saldo = saldo - p_valor
            WHERE id = p_cliente_id;

            INSERT INTO transacoes (valor, tipo, cliente_id, descricao)
            VALUES (p_valor, 'd', p_cliente_id, p_descricao);
        END IF;
    ELSIF p_tipo = 'c' THEN
        UPDATE clientes
        SET saldo = saldo + p_valor
        WHERE id = p_cliente_id;

        INSERT INTO transacoes (valor, tipo, cliente_id, descricao)
        VALUES (p_valor, 'c', p_cliente_id, p_descricao);
    ELSE
        RAISE EXCEPTION 'Transação inválida!';
    END IF;
END;
$$;

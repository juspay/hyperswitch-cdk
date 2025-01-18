-- Your SQL goes here

CREATE TABLE merchant (
  id SERIAL,
  tenant_id VARCHAR(255) NOT NULL, 
  merchant_id VARCHAR(255) NOT NULL,
  enc_key BYTEA NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
  
  PRIMARY KEY (tenant_id, merchant_id)
);

CREATE TABLE locker (
  id SERIAL,
  locker_id VARCHAR(255) NOT NULL,
  tenant_id VARCHAR(255) NOT NULL, 
  merchant_id VARCHAR(255) NOT NULL, 
  customer_id VARCHAR(255) NOT NULL,
  enc_data BYTEA NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,

  PRIMARY KEY (tenant_id, merchant_id, customer_id, locker_id)
);
-- Your SQL goes here


CREATE TABLE hash_table (
  id SERIAL,
  hash_id VARCHAR(255) NOT NULL,
  data_hash BYTEA UNIQUE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,

  PRIMARY KEY (hash_id)
);


ALTER TABLE locker ADD IF NOT EXISTS hash_id VARCHAR(255) NOT NULL;
-- Your SQL goes here

CREATE TABLE fingerprint (
  id SERIAL,
  card_hash BYTEA UNIQUE NOT NULL,
  card_fingerprint VARCHAR(64) NOT NULL,
  PRIMARY KEY (card_hash)
);-- Your SQL goes here

ALTER TABLE locker ADD COLUMN IF NOT EXISTS ttl TIMESTAMP DEFAULT NULL;-- Your SQL goes here
ALTER TABLE merchant DROP CONSTRAINT merchant_pkey, ADD CONSTRAINT merchant_pkey PRIMARY KEY (merchant_id);
ALTER TABLE merchant DROP COLUMN IF EXISTS tenant_id;

ALTER TABLE locker DROP CONSTRAINT locker_pkey, ADD CONSTRAINT locker_pkey PRIMARY KEY (merchant_id, customer_id, locker_id);
ALTER TABLE locker DROP COLUMN IF EXISTS tenant_id;


-- Your SQL goes here

ALTER TABLE fingerprint RENAME COLUMN card_fingerprint TO fingerprint_id;
ALTER TABLE fingerprint RENAME COLUMN card_hash TO fingerprint_hash;

CREATE TABLE IF NOT EXISTS vault (
    id SERIAL,
    entity_id VARCHAR(255) NOT NULL, 
    vault_id VARCHAR(255) NOT NULL,
    encrypted_data BYTEA NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    expires_at TIMESTAMP DEFAULT NULL,
    
    PRIMARY KEY (entity_id, vault_id)
);

CREATE TABLE IF NOT EXISTS entity (
    id SERIAL,
    entity_id VARCHAR(255) NOT NULL,
    enc_key_id VARCHAR(255) NOT NULL,

    PRIMARY KEY (entity_id)
);-- Your SQL goes here
ALTER TABLE entity
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP;

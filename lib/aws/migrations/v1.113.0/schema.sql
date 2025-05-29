-- File: migrations/00000000000000_diesel_initial_setup/up.sql
-- This file was automatically created by Diesel to setup helper functions
-- and other internal bookkeeping. This file is safe to edit, any future
-- changes will be added to existing projects as new migrations.




-- Sets up a trigger for the given table to automatically set a column called
-- `updated_at` whenever the row is modified (unless `updated_at` was included
-- in the modified columns)
--
-- # Example
--
-- ```sql
-- CREATE TABLE users (id SERIAL PRIMARY KEY, updated_at TIMESTAMP NOT NULL DEFAULT NOW());
--
-- SELECT diesel_manage_updated_at('users');
-- ```
CREATE OR REPLACE FUNCTION diesel_manage_updated_at(_tbl regclass) RETURNS VOID AS $$
BEGIN
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON %s
                    FOR EACH ROW EXECUTE PROCEDURE diesel_set_updated_at()', _tbl);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION diesel_set_updated_at() RETURNS trigger AS $$
BEGIN
    IF (
        NEW IS DISTINCT FROM OLD AND
        NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at
    ) THEN
        NEW.updated_at := current_timestamp;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
 


-- File: migrations/2022-09-29-084920_create_initial_tables/up.sql
-- Types
CREATE TYPE "AttemptStatus" AS ENUM (
    'started',
    'authentication_failed',
    'juspay_declined',
    'pending_vbv',
    'vbv_successful',
    'authorized',
    'authorization_failed',
    'charged',
    'authorizing',
    'cod_initiated',
    'voided',
    'void_initiated',
    'capture_initiated',
    'capture_failed',
    'void_failed',
    'auto_refunded',
    'partial_charged',
    'pending',
    'failure',
    'payment_method_awaited',
    'confirmation_awaited'
);

CREATE TYPE "AuthenticationType" AS ENUM ('three_ds', 'no_three_ds');

CREATE TYPE "CaptureMethod" AS ENUM ('automatic', 'manual', 'scheduled');

CREATE TYPE "ConnectorType" AS ENUM (
    'payment_processor',
    'payment_vas',
    'fin_operations',
    'fiz_operations',
    'networks',
    'banking_entities',
    'non_banking_finance'
);

CREATE TYPE "Currency" AS ENUM (
    'AED',
    'ALL',
    'AMD',
    'ARS',
    'AUD',
    'AWG',
    'AZN',
    'BBD',
    'BDT',
    'BHD',
    'BMD',
    'BND',
    'BOB',
    'BRL',
    'BSD',
    'BWP',
    'BZD',
    'CAD',
    'CHF',
    'CNY',
    'COP',
    'CRC',
    'CUP',
    'CZK',
    'DKK',
    'DOP',
    'DZD',
    'EGP',
    'ETB',
    'EUR',
    'FJD',
    'GBP',
    'GHS',
    'GIP',
    'GMD',
    'GTQ',
    'GYD',
    'HKD',
    'HNL',
    'HRK',
    'HTG',
    'HUF',
    'IDR',
    'ILS',
    'INR',
    'JMD',
    'JOD',
    'JPY',
    'KES',
    'KGS',
    'KHR',
    'KRW',
    'KWD',
    'KYD',
    'KZT',
    'LAK',
    'LBP',
    'LKR',
    'LRD',
    'LSL',
    'MAD',
    'MDL',
    'MKD',
    'MMK',
    'MNT',
    'MOP',
    'MUR',
    'MVR',
    'MWK',
    'MXN',
    'MYR',
    'NAD',
    'NGN',
    'NIO',
    'NOK',
    'NPR',
    'NZD',
    'OMR',
    'PEN',
    'PGK',
    'PHP',
    'PKR',
    'PLN',
    'QAR',
    'RUB',
    'SAR',
    'SCR',
    'SEK',
    'SGD',
    'SLL',
    'SOS',
    'SSP',
    'SVC',
    'SZL',
    'THB',
    'TTD',
    'TWD',
    'TZS',
    'USD',
    'UYU',
    'UZS',
    'YER',
    'ZAR'
);

CREATE TYPE "EventClass" AS ENUM ('payments');

CREATE TYPE "EventObjectType" AS ENUM ('payment_details');

CREATE TYPE "EventType" AS ENUM ('payment_succeeded');

CREATE TYPE "FutureUsage" AS ENUM ('on_session', 'off_session');

CREATE TYPE "IntentStatus" AS ENUM (
    'succeeded',
    'failed',
    'processing',
    'requires_customer_action',
    'requires_payment_method',
    'requires_confirmation'
);

CREATE TYPE "MandateStatus" AS ENUM (
    'active',
    'inactive',
    'pending',
    'revoked'
);

CREATE TYPE "MandateType" AS ENUM ('single_use', 'multi_use');

CREATE TYPE "PaymentFlow" AS ENUM (
    'vsc',
    'emi',
    'otp',
    'upi_intent',
    'upi_collect',
    'upi_scan_and_pay',
    'sdk'
);

CREATE TYPE "PaymentMethodIssuerCode" AS ENUM (
    'jp_hdfc',
    'jp_icici',
    'jp_googlepay',
    'jp_applepay',
    'jp_phonepe',
    'jp_wechat',
    'jp_sofort',
    'jp_giropay',
    'jp_sepa',
    'jp_bacs'
);

CREATE TYPE "PaymentMethodSubType" AS ENUM (
    'credit',
    'debit',
    'upi_intent',
    'upi_collect',
    'credit_card_installments',
    'pay_later_installments'
);

CREATE TYPE "PaymentMethodType" AS ENUM (
    'card',
    'bank_transfer',
    'netbanking',
    'upi',
    'open_banking',
    'consumer_finance',
    'wallet',
    'payment_container',
    'bank_debit',
    'pay_later'
);

CREATE TYPE "ProcessTrackerStatus" AS ENUM (
    'processing',
    'new',
    'pending',
    'process_started',
    'finish'
);

CREATE TYPE "RefundStatus" AS ENUM (
    'failure',
    'manual_review',
    'pending',
    'success',
    'transaction_failure'
);

CREATE TYPE "RefundType" AS ENUM (
    'instant_refund',
    'regular_refund',
    'retry_refund'
);

CREATE TYPE "RoutingAlgorithm" AS ENUM (
    'round_robin',
    'max_conversion',
    'min_cost',
    'custom'
);

-- Tables
CREATE TABLE address (
    id SERIAL,
    address_id VARCHAR(255) PRIMARY KEY,
    city VARCHAR(255),
    country VARCHAR(255),
    line1 VARCHAR(255),
    line2 VARCHAR(255),
    line3 VARCHAR(255),
    state VARCHAR(255),
    zip VARCHAR(255),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    phone_number VARCHAR(255),
    country_code VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    modified_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP
);

CREATE TABLE configs (
    id SERIAL,
    key VARCHAR(255) NOT NULL,
    config TEXT NOT NULL,
    PRIMARY KEY (key)
);

CREATE TABLE customers (
    id SERIAL,
    customer_id VARCHAR(255) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    NAME VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(255),
    phone_country_code VARCHAR(255),
    description VARCHAR(255),
    address JSON,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    metadata JSON,
    PRIMARY KEY (customer_id, merchant_id)
);

CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    event_id VARCHAR(255) NOT NULL,
    event_type "EventType" NOT NULL,
    event_class "EventClass" NOT NULL,
    is_webhook_notified BOOLEAN NOT NULL DEFAULT FALSE,
    intent_reference_id VARCHAR(255),
    primary_object_id VARCHAR(255) NOT NULL,
    primary_object_type "EventObjectType" NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP
);

CREATE TABLE locker_mock_up (
    id SERIAL PRIMARY KEY,
    card_id VARCHAR(255) NOT NULL,
    external_id VARCHAR(255) NOT NULL,
    card_fingerprint VARCHAR(255) NOT NULL,
    card_global_fingerprint VARCHAR(255) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    card_number VARCHAR(255) NOT NULL,
    card_exp_year VARCHAR(255) NOT NULL,
    card_exp_month VARCHAR(255) NOT NULL,
    name_on_card VARCHAR(255),
    nickname VARCHAR(255),
    customer_id VARCHAR(255),
    duplicate BOOLEAN
);

CREATE TABLE mandate (
    id SERIAL PRIMARY KEY,
    mandate_id VARCHAR(255) NOT NULL,
    customer_id VARCHAR(255) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    payment_method_id VARCHAR(255) NOT NULL,
    mandate_status "MandateStatus" NOT NULL,
    mandate_type "MandateType" NOT NULL,
    customer_accepted_at TIMESTAMP,
    customer_ip_address VARCHAR(255),
    customer_user_agent VARCHAR(255),
    network_transaction_id VARCHAR(255),
    previous_transaction_id VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP
);

CREATE TABLE merchant_account (
    id SERIAL PRIMARY KEY,
    merchant_id VARCHAR(255) NOT NULL,
    api_key VARCHAR(255),
    return_url VARCHAR(255),
    enable_payment_response_hash BOOLEAN NOT NULL DEFAULT FALSE,
    payment_response_hash_key VARCHAR(255) DEFAULT NULL,
    redirect_to_merchant_with_http_post BOOLEAN NOT NULL DEFAULT FALSE,
    merchant_name VARCHAR(255),
    merchant_details JSON,
    webhook_details JSON,
    routing_algorithm "RoutingAlgorithm",
    custom_routing_rules JSON,
    sub_merchants_enabled BOOLEAN DEFAULT FALSE,
    parent_merchant_id VARCHAR(255),
    publishable_key VARCHAR(255)
);

CREATE TABLE merchant_connector_account (
    id SERIAL PRIMARY KEY,
    merchant_id VARCHAR(255) NOT NULL,
    connector_name VARCHAR(255) NOT NULL,
    connector_account_details JSON NOT NULL,
    test_mode BOOLEAN,
    disabled BOOLEAN,
    merchant_connector_id SERIAL NOT NULL,
    payment_methods_enabled JSON [ ],
    connector_type "ConnectorType" NOT NULL DEFAULT 'payment_processor'::"ConnectorType"
);

CREATE TABLE payment_attempt (
    id SERIAL PRIMARY KEY,
    payment_id VARCHAR(255) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    txn_id VARCHAR(255) NOT NULL,
    status "AttemptStatus" NOT NULL,
    amount INTEGER NOT NULL,
    currency "Currency",
    save_to_locker BOOLEAN,
    connector VARCHAR(255) NOT NULL,
    error_message TEXT,
    offer_amount INTEGER,
    surcharge_amount INTEGER,
    tax_amount INTEGER,
    payment_method_id VARCHAR(255),
    payment_method "PaymentMethodType",
    payment_flow "PaymentFlow",
    redirect BOOLEAN,
    connector_transaction_id VARCHAR(255),
    capture_method "CaptureMethod",
    capture_on TIMESTAMP,
    confirm BOOLEAN NOT NULL,
    authentication_type "AuthenticationType",
    created_at TIMESTAMP NOT NULL,
    modified_at TIMESTAMP NOT NULL,
    last_synced TIMESTAMP
);

CREATE TABLE payment_intent (
    id SERIAL PRIMARY KEY,
    payment_id VARCHAR(255) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    status "IntentStatus" NOT NULL,
    amount INTEGER NOT NULL,
    currency "Currency",
    amount_captured INTEGER,
    customer_id VARCHAR(255),
    description VARCHAR(255),
    return_url VARCHAR(255),
    metadata JSONB DEFAULT '{}'::JSONB,
    connector_id VARCHAR(255),
    shipping_address_id VARCHAR(255),
    billing_address_id VARCHAR(255),
    statement_descriptor_name VARCHAR(255),
    statement_descriptor_suffix VARCHAR(255),
    created_at TIMESTAMP NOT NULL,
    modified_at TIMESTAMP NOT NULL,
    last_synced TIMESTAMP,
    setup_future_usage "FutureUsage",
    off_session BOOLEAN,
    client_secret VARCHAR(255)
);

CREATE TABLE payment_methods (
    id SERIAL PRIMARY KEY,
    customer_id VARCHAR(255) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    payment_method_id VARCHAR(255) NOT NULL,
    accepted_currency "Currency" [ ],
    scheme VARCHAR(255),
    token VARCHAR(255),
    cardholder_name VARCHAR(255),
    issuer_name VARCHAR(255),
    issuer_country VARCHAR(255),
    payer_country TEXT [ ],
    is_stored BOOLEAN,
    swift_code VARCHAR(255),
    direct_debit_token VARCHAR(255),
    network_transaction_id VARCHAR(255),
    created_at TIMESTAMP NOT NULL,
    last_modified TIMESTAMP NOT NULL,
    payment_method "PaymentMethodType" NOT NULL,
    payment_method_type "PaymentMethodSubType",
    payment_method_issuer VARCHAR(255),
    payment_method_issuer_code "PaymentMethodIssuerCode"
);

CREATE TABLE process_tracker (
    id VARCHAR(127) PRIMARY KEY,
    NAME VARCHAR(255),
    tag TEXT [ ] NOT NULL DEFAULT '{}'::TEXT [ ],
    runner VARCHAR(255),
    retry_count INTEGER NOT NULL,
    schedule_time TIMESTAMP,
    rule VARCHAR(255) NOT NULL,
    tracking_data JSON NOT NULL,
    business_status VARCHAR(255) NOT NULL,
    status "ProcessTrackerStatus" NOT NULL,
    event TEXT [ ] NOT NULL DEFAULT '{}'::TEXT [ ],
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE refund (
    id SERIAL PRIMARY KEY,
    internal_reference_id VARCHAR(255) NOT NULL,
    refund_id VARCHAR(255) NOT NULL,
    payment_id VARCHAR(255) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    transaction_id VARCHAR(255) NOT NULL,
    connector VARCHAR(255) NOT NULL,
    pg_refund_id VARCHAR(255),
    external_reference_id VARCHAR(255),
    refund_type "RefundType" NOT NULL,
    total_amount INTEGER NOT NULL,
    currency "Currency" NOT NULL,
    refund_amount INTEGER NOT NULL,
    refund_status "RefundStatus" NOT NULL,
    sent_to_gateway BOOLEAN NOT NULL DEFAULT FALSE,
    refund_error_message TEXT,
    metadata JSON,
    refund_arn VARCHAR(255),
    created_at TIMESTAMP NOT NULL,
    modified_at TIMESTAMP NOT NULL,
    description VARCHAR(255)
);

CREATE TABLE temp_card (
    id SERIAL PRIMARY KEY,
    date_created TIMESTAMP NOT NULL,
    txn_id VARCHAR(255),
    card_info JSON
);

-- Indices
CREATE INDEX customers_created_at_index ON customers (created_at);

CREATE UNIQUE INDEX merchant_account_api_key_index ON merchant_account (api_key);

CREATE UNIQUE INDEX merchant_account_merchant_id_index ON merchant_account (merchant_id);

CREATE UNIQUE INDEX merchant_account_publishable_key_index ON merchant_account (publishable_key);

CREATE INDEX merchant_connector_account_connector_type_index ON merchant_connector_account (connector_type);

CREATE INDEX merchant_connector_account_merchant_id_index ON merchant_connector_account (merchant_id);

CREATE UNIQUE INDEX payment_attempt_payment_id_merchant_id_index ON payment_attempt (payment_id, merchant_id);

CREATE UNIQUE INDEX payment_intent_payment_id_merchant_id_index ON payment_intent (payment_id, merchant_id);

CREATE INDEX payment_methods_created_at_index ON payment_methods (created_at);

CREATE INDEX payment_methods_customer_id_index ON payment_methods (customer_id);

CREATE INDEX payment_methods_last_modified_index ON payment_methods (last_modified);

CREATE INDEX payment_methods_payment_method_id_index ON payment_methods (payment_method_id);

CREATE INDEX refund_internal_reference_id_index ON refund (internal_reference_id);

CREATE INDEX refund_payment_id_merchant_id_index ON refund (payment_id, merchant_id);

CREATE INDEX refund_refund_id_index ON refund (refund_id);

CREATE UNIQUE INDEX refund_refund_id_merchant_id_index ON refund (refund_id, merchant_id);

CREATE INDEX temp_card_txn_id_index ON temp_card (txn_id);
 


-- File: migrations/2022-09-29-093314_create_seed_data/up.sql
INSERT INTO merchant_account (
        merchant_id,
        api_key,
        merchant_name,
        merchant_details,
        custom_routing_rules,
        publishable_key
    )
VALUES (
        'juspay_merchant',
        'MySecretApiKey',
        'Juspay Merchant',
        '{ "primary_email": "merchant@juspay.in" }',
        '[ { "connectors_pecking_order": [ "stripe" ] } ]',
        'pk_MyPublicApiKey'
    );

INSERT INTO merchant_connector_account (
        merchant_id,
        connector_name,
        connector_account_details
    )
VALUES (
        'juspay_merchant',
        'stripe',
        '{ "auth_type": "HeaderKey", "api_key": "Basic MyStripeApiKey" }'
    );


-- File: migrations/2022-10-20-100628_add_cancellation_reason/up.sql
ALTER TABLE payment_attempt
ADD COLUMN cancellation_reason VARCHAR(255);


-- File: migrations/2022-10-26-101016_update_payment_attempt_status_intent_status/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt ADD IF NOT EXISTS amount_to_capture INTEGER;
ALTER TYPE "CaptureMethod" ADD VALUE 'manual_multiple' AFTER 'manual';
ALTER TYPE "IntentStatus" ADD VALUE 'requires_capture';
-- File: migrations/2022-11-03-130214_create_connector_response_table/up.sql
-- Your SQL goes here
CREATE TABLE connector_response (
    id SERIAL PRIMARY KEY,
    payment_id VARCHAR(255) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    txn_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    modified_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    connector_name VARCHAR(32) NOT NULL,
    connector_transaction_id VARCHAR(255),
    authentication_data JSON,
    encoded_data TEXT
);

CREATE UNIQUE INDEX connector_response_id_index ON connector_response (payment_id, merchant_id, txn_id); 


-- File: migrations/2022-11-08-101705_add_cancel_to_payment_intent_status/up.sql
-- Your SQL goes here
ALTER TYPE "IntentStatus" ADD VALUE 'cancelled' after 'failed';

 


-- File: migrations/2022-11-21-133803_add_mandate_id_in_payment_attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt ADD IF NOT EXISTS mandate_id VARCHAR(255);
 


-- File: migrations/2022-11-24-095709_add_browser_info_to_payment_attempt/up.sql
ALTER TABLE payment_attempt
ADD COLUMN browser_info JSONB DEFAULT NULL;
 


-- File: migrations/2022-11-25-121143_add_paypal_pmt/up.sql
-- Your SQL goes here
ALTER TYPE "PaymentMethodType" ADD VALUE 'paypal' after 'pay_later';
 


-- File: migrations/2022-11-30-084736_update-index-in-mca/up.sql
CREATE UNIQUE INDEX merchant_connector_account_merchant_id_connector_name_index ON merchant_connector_account (merchant_id, connector_name); 


-- File: migrations/2022-12-05-090521_single_use_mandate_fields/up.sql
-- Your SQL goes here
ALTER TABLE mandate
ADD IF NOT EXISTS single_use_amount INTEGER DEFAULT NULL,
ADD IF NOT EXISTS single_use_currency "Currency" DEFAULT NULL;
 


-- File: migrations/2022-12-07-055441_add_use_kv_to_merchant_account/up.sql
-- Your SQL goes here

CREATE TYPE "MerchantStorageScheme" AS ENUM (
    'postgres_only',
    'redis_kv'
);

ALTER TABLE merchant_account ADD COLUMN storage_scheme "MerchantStorageScheme" NOT NULL DEFAULT 'postgres_only';
 


-- File: migrations/2022-12-07-133736_make_connector_field_optional/up.sql
ALTER TABLE payment_attempt ALTER COLUMN connector DROP NOT NULL;
ALTER TABLE connector_response ALTER COLUMN connector_name DROP NOT NULL; 


-- File: migrations/2022-12-09-102635_mandate-connector-and-amount/up.sql
-- Your SQL goes here
ALTER TABLE mandate
RENAME COLUMN single_use_amount TO mandate_amount;
ALTER TABLE mandate
RENAME COLUMN single_use_currency TO mandate_currency;
ALTER TABLE mandate
ADD IF NOT EXISTS amount_captured INTEGER DEFAULT NULL,
ADD IF NOT EXISTS connector VARCHAR(255) NOT NULL DEFAULT 'dummy',
ADD IF NOT EXISTS connector_mandate_id VARCHAR(255) DEFAULT NULL; 


-- File: migrations/2022-12-10-123613_update_address_and_customer/up.sql
-- Your SQL goes here
ALTER TABLE address
ADD COLUMN customer_id VARCHAR(255) NOT NULL,
ADD COLUMN merchant_id VARCHAR(255) NOT NULL;

CREATE INDEX address_customer_id_merchant_id_index ON address (customer_id, merchant_id);

ALTER TABLE customers DROP COLUMN address; 


-- File: migrations/2022-12-11-190755_update_mock_up/up.sql
-- Your SQL goes here
ALTER TABLE locker_mock_up
ADD COLUMN card_cvc VARCHAR(8); 


-- File: migrations/2022-12-12-132936_reverse_lookup/up.sql
CREATE TABLE reverse_lookup (
    lookup_id VARCHAR(255) NOT NULL PRIMARY KEY,
    sk_id VARCHAR(50) NOT NULL,
    pk_id VARCHAR(255) NOT NULL,
    source VARCHAR(30) NOT NULL
);

CREATE INDEX lookup_id_index ON reverse_lookup (lookup_id);
 


-- File: migrations/2022-12-13-170152_add_connector_metadata/up.sql
ALTER TABLE merchant_connector_account ADD COLUMN metadata JSONB DEFAULT NULL;
 


-- File: migrations/2022-12-14-074547_error-code-in-payment_attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD IF NOT EXISTS error_code VARCHAR(255) DEFAULT NULL; 


-- File: migrations/2022-12-14-090419_add_payment_token_in_payment_attempt/up.sql
ALTER TABLE payment_attempt ADD COLUMN payment_token VARCHAR(255); 


-- File: migrations/2022-12-14-092540_i32_to_i64/up.sql
-- Your SQL goes here
ALTER TABLE mandate
    ALTER COLUMN mandate_amount TYPE bigint,
    ALTER COLUMN amount_captured TYPE bigint;

ALTER TABLE payment_attempt
    ALTER COLUMN amount TYPE bigint,
    ALTER COLUMN offer_amount TYPE bigint,
    ALTER COLUMN surcharge_amount TYPE bigint,
    ALTER COLUMN tax_amount TYPE bigint,
    ALTER COLUMN amount_to_capture TYPE bigint;

ALTER TABLE payment_intent
    ALTER COLUMN amount TYPE bigint,
    ALTER COLUMN amount_captured TYPE bigint;

ALTER TABLE refund
    ALTER COLUMN total_amount TYPE bigint,
    ALTER COLUMN refund_amount TYPE bigint;
 


-- File: migrations/2022-12-14-162701_update_payment_method/up.sql
-- Your SQL goes here
ALTER TABLE payment_methods
ADD COLUMN metadata JSON; 


-- File: migrations/2022-12-19-085322_rename_txn_id_to_attempt_id/up.sql
ALTER TABLE payment_attempt
RENAME COLUMN txn_id to attempt_id;
 


-- File: migrations/2022-12-19-085739_add_attempt_id_to_refund/up.sql
ALTER TABLE refund ADD COLUMN attempt_id VARCHAR(64) NOT NULL;
 


-- File: migrations/2022-12-20-065945_reduce_size_of_varchar_columns/up.sql
ALTER TABLE address
    ALTER COLUMN address_id TYPE VARCHAR(64),
    ALTER COLUMN city TYPE VARCHAR(128),
    ALTER COLUMN country TYPE VARCHAR(64),
    ALTER COLUMN state TYPE VARCHAR(128),
    ALTER COLUMN zip TYPE VARCHAR(16),
    ALTER COLUMN phone_number TYPE VARCHAR(32),
    ALTER COLUMN country_code TYPE VARCHAR(8),
    ALTER COLUMN customer_id TYPE VARCHAR(64),
    ALTER COLUMN merchant_id TYPE VARCHAR(64);

ALTER TABLE connector_response RENAME COLUMN txn_id TO attempt_id;

ALTER TABLE connector_response
    ALTER COLUMN payment_id TYPE VARCHAR(64),
    ALTER COLUMN merchant_id TYPE VARCHAR(64),
    ALTER COLUMN attempt_id TYPE VARCHAR(64),
    ALTER COLUMN connector_name TYPE VARCHAR(64),
    ALTER COLUMN connector_transaction_id TYPE VARCHAR(128);

ALTER TABLE customers
    ALTER COLUMN customer_id TYPE VARCHAR(64),
    ALTER COLUMN merchant_id TYPE VARCHAR(64),
    ALTER COLUMN phone TYPE VARCHAR(32),
    ALTER COLUMN phone_country_code TYPE VARCHAR(8);

ALTER TABLE events
    ALTER COLUMN event_id TYPE VARCHAR(64),
    ALTER COLUMN intent_reference_id TYPE VARCHAR(64),
    ALTER COLUMN primary_object_id TYPE VARCHAR(64);

ALTER TABLE mandate RENAME COLUMN previous_transaction_id to previous_attempt_id;

ALTER TABLE mandate
    ALTER COLUMN mandate_id TYPE VARCHAR(64),
    ALTER COLUMN customer_id TYPE VARCHAR(64),
    ALTER COLUMN merchant_id TYPE VARCHAR(64),
    ALTER COLUMN payment_method_id TYPE VARCHAR(64),
    ALTER COLUMN customer_ip_address TYPE VARCHAR(64),
    ALTER COLUMN network_transaction_id TYPE VARCHAR(128),
    ALTER COLUMN previous_attempt_id TYPE VARCHAR(64),
    ALTER COLUMN connector TYPE VARCHAR(64),
    ALTER COLUMN connector_mandate_id TYPE VARCHAR(128);

ALTER TABLE merchant_account
    ALTER COLUMN merchant_id TYPE VARCHAR(64),
    ALTER COLUMN api_key TYPE VARCHAR(128),
    ALTER COLUMN merchant_name TYPE VARCHAR(128),
    ALTER COLUMN parent_merchant_id TYPE VARCHAR(64),
    ALTER COLUMN publishable_key TYPE VARCHAR(128);

ALTER TABLE merchant_connector_account
    ALTER COLUMN merchant_id TYPE VARCHAR(64),
    ALTER COLUMN connector_name TYPE VARCHAR(64);

ALTER TABLE payment_attempt
    ALTER COLUMN payment_id TYPE VARCHAR(64),
    ALTER COLUMN merchant_id TYPE VARCHAR(64),
    ALTER COLUMN attempt_id TYPE VARCHAR(64),
    ALTER COLUMN connector TYPE VARCHAR(64),
    ALTER COLUMN payment_method_id TYPE VARCHAR(64),
    ALTER COLUMN connector_transaction_id TYPE VARCHAR(128),
    ALTER COLUMN mandate_id TYPE VARCHAR(64),
    ALTER COLUMN payment_token TYPE VARCHAR(128);

ALTER TABLE payment_intent
    ALTER COLUMN payment_id TYPE VARCHAR(64),
    ALTER COLUMN merchant_id TYPE VARCHAR(64),
    ALTER COLUMN customer_id TYPE VARCHAR(64),
    ALTER COLUMN connector_id TYPE VARCHAR(64),
    ALTER COLUMN shipping_address_id TYPE VARCHAR(64),
    ALTER COLUMN billing_address_id TYPE VARCHAR(64),
    ALTER COLUMN client_secret TYPE VARCHAR(128);

ALTER TABLE payment_methods DROP COLUMN network_transaction_id;

ALTER TABLE payment_methods
    ALTER COLUMN customer_id TYPE VARCHAR(64),
    ALTER COLUMN merchant_id TYPE VARCHAR(64),
    ALTER COLUMN payment_method_id TYPE VARCHAR(64),
    ALTER COLUMN scheme TYPE VARCHAR(32),
    ALTER COLUMN token TYPE VARCHAR(128),
    ALTER COLUMN issuer_name TYPE VARCHAR(64),
    ALTER COLUMN issuer_country TYPE VARCHAR(64),
    ALTER COLUMN swift_code TYPE VARCHAR(32),
    ALTER COLUMN direct_debit_token TYPE VARCHAR(128),
    ALTER COLUMN payment_method_issuer TYPE VARCHAR(128);

ALTER TABLE process_tracker
    ALTER COLUMN name TYPE VARCHAR(64),
    ALTER COLUMN runner TYPE VARCHAR(64);

ALTER TABLE refund RENAME COLUMN transaction_id to connector_transaction_id;
ALTER TABLE refund RENAME COLUMN pg_refund_id to connector_refund_id;

ALTER TABLE refund
    ALTER COLUMN internal_reference_id TYPE VARCHAR(64),
    ALTER COLUMN refund_id TYPE VARCHAR(64),
    ALTER COLUMN payment_id TYPE VARCHAR(64),
    ALTER COLUMN merchant_id TYPE VARCHAR(64),
    ALTER COLUMN connector_transaction_id TYPE VARCHAR(128),
    ALTER COLUMN connector TYPE VARCHAR(64),
    ALTER COLUMN connector_refund_id TYPE VARCHAR(128),
    ALTER COLUMN external_reference_id TYPE VARCHAR(64),
    ALTER COLUMN refund_arn TYPE VARCHAR(128);

ALTER TABLE reverse_lookup
    ALTER COLUMN lookup_id TYPE VARCHAR(128),
    ALTER COLUMN sk_id TYPE VARCHAR(128),
    ALTER COLUMN pk_id TYPE VARCHAR(128),
    ALTER COLUMN source TYPE VARCHAR(128);
 


-- File: migrations/2022-12-21-071825_add_refund_reason/up.sql
ALTER TABLE REFUND ADD COLUMN refund_reason VARCHAR(255) DEFAULT NULL;
 


-- File: migrations/2022-12-21-124904_remove_metadata_default_as_null/up.sql
ALTER TABLE payment_intent ALTER COLUMN metadata DROP DEFAULT; 


-- File: migrations/2022-12-22-091431_attempt_status_rename/up.sql
ALTER TYPE "AttemptStatus" RENAME VALUE 'juspay_declined' TO 'router_declined';
ALTER TYPE "AttemptStatus" RENAME VALUE 'pending_vbv' TO 'authentication_successful';
ALTER TYPE "AttemptStatus" RENAME VALUE 'vbv_successful' TO 'authentication_pending';
 


-- File: migrations/2022-12-27-172643_update_locker_mock_up/up.sql
-- Your SQL goes here
ALTER TABLE locker_mock_up
ADD COLUMN payment_method_id VARCHAR(64); 


-- File: migrations/2023-01-03-122401_update_merchant_account/up.sql
-- Your SQL goes here
ALTER TABLE merchant_account
ADD COLUMN locker_id VARCHAR(64); 


-- File: migrations/2023-01-10-035412_connector-metadata-payment-attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt ADD COLUMN connector_metadata JSONB DEFAULT NULL; 


-- File: migrations/2023-01-11-134448_add_metadata_to_merchant_account/up.sql
-- Your SQL goes here
ALTER TABLE merchant_account ADD COLUMN metadata JSONB DEFAULT NULL; 


-- File: migrations/2023-01-12-084710_update_merchant_routing_algorithm/up.sql
-- Your SQL goes here
ALTER TABLE merchant_account DROP COLUMN routing_algorithm;
ALTER TABLE merchant_account DROP COLUMN custom_routing_rules;
ALTER TABLE merchant_account ADD COLUMN routing_algorithm JSON;
DROP TYPE "RoutingAlgorithm";
 


-- File: migrations/2023-01-12-140107_drop_temp_card/up.sql
DROP TABLE temp_card;
 


-- File: migrations/2023-01-19-122511_add_refund_error_code/up.sql
ALTER TABLE refund
ADD IF NOT EXISTS refund_error_code TEXT DEFAULT NULL;
 


-- File: migrations/2023-01-20-113235_add_attempt_id_to_payment_intent/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN active_attempt_id VARCHAR(64) NOT NULL DEFAULT 'xxx';

UPDATE payment_intent SET active_attempt_id = payment_attempt.attempt_id from payment_attempt where payment_intent.active_attempt_id = payment_attempt.payment_id;

CREATE UNIQUE INDEX payment_attempt_payment_id_merchant_id_attempt_id_index ON payment_attempt (payment_id, merchant_id, attempt_id);

-- Because payment_attempt table can have rows with same payment_id and merchant_id, this index is dropped.
DROP index payment_attempt_payment_id_merchant_id_index;

CREATE INDEX payment_attempt_payment_id_merchant_id_index ON payment_attempt (payment_id, merchant_id);
 


-- File: migrations/2023-02-01-135102_create_api_keys_table/up.sql
CREATE TABLE api_keys (
    key_id VARCHAR(64) NOT NULL PRIMARY KEY,
    merchant_id VARCHAR(64) NOT NULL,
    NAME VARCHAR(64) NOT NULL,
    description VARCHAR(256) DEFAULT NULL,
    hash_key VARCHAR(64) NOT NULL,
    hashed_api_key VARCHAR(128) NOT NULL,
    prefix VARCHAR(16) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    expires_at TIMESTAMP DEFAULT NULL,
    last_used TIMESTAMP DEFAULT NULL
);
 


-- File: migrations/2023-02-02-055700_add_payment_issuer_and_experience_in_payment_attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS payment_issuer VARCHAR(50);

ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS payment_experience VARCHAR(50);
 


-- File: migrations/2023-02-02-062215_remove_redirect_and_payment_flow_from_payment_attempt/up.sql
ALTER TABLE payment_attempt DROP COLUMN IF EXISTS redirect;

ALTER TABLE payment_attempt DROP COLUMN IF EXISTS payment_flow;

DROP TYPE IF EXISTS "PaymentFlow";
 


-- File: migrations/2023-02-07-070512_change_merchant_connector_id_data_type/up.sql
ALTER TABLE merchant_connector_account
ALTER COLUMN merchant_connector_id TYPE VARCHAR(128) USING merchant_connector_id::varchar;


ALTER TABLE merchant_connector_account
ALTER COLUMN merchant_connector_id DROP DEFAULT;
 


-- File: migrations/2023-02-09-093400_add_bank_redirect/up.sql
-- Your SQL goes here
ALTER TYPE "PaymentMethodType" ADD VALUE 'bank_redirect' after 'paypal';
 


-- File: migrations/2023-02-10-083146_make_payment_method_type_as_text/up.sql
-- Your SQL goes here
ALTER TABLE payment_methods
ALTER COLUMN payment_method_type TYPE VARCHAR(64);

ALTER TABLE payment_attempt
ADD COLUMN payment_method_type VARCHAR(64);

DROP TYPE IF EXISTS "PaymentMethodSubType";
 


-- File: migrations/2023-02-20-101809_update_merchant_connector_account/up.sql
ALTER TABLE merchant_connector_account
ADD COLUMN connector_label VARCHAR(255),
    ADD COLUMN business_country VARCHAR(2) DEFAULT 'US' NOT NULL,
    ADD COLUMN business_label VARCHAR(255) DEFAULT 'default' NOT NULL;

-- To backfill, use `US` as default country and `default` as the business_label
UPDATE merchant_connector_account AS m
SET connector_label = concat(
        m.connector_name,
        '_',
        'US',
        '_',
        'default'
    );

ALTER TABLE merchant_connector_account
ALTER COLUMN connector_label
SET NOT NULL,
    ALTER COLUMN business_country DROP DEFAULT,
    ALTER COLUMN business_label DROP DEFAULT;

DROP INDEX merchant_connector_account_merchant_id_connector_name_index;

CREATE UNIQUE INDEX merchant_connector_account_merchant_id_connector_label_index ON merchant_connector_account (merchant_id, connector_label);
 


-- File: migrations/2023-02-21-065628_update_merchant_account/up.sql
ALTER TABLE merchant_account
ADD COLUMN IF NOT EXISTS primary_business_details JSON NOT NULL DEFAULT '{"country": ["US"], "business": ["default"]}';
 


-- File: migrations/2023-02-21-094019_api_keys_remove_hash_key/up.sql
ALTER TABLE api_keys DROP COLUMN hash_key;

/*
 Once we've dropped the `hash_key` column, we cannot use the existing API keys
 from the `api_keys` table anymore, as the `hash_key` is a random string that
 we no longer have.
 */
TRUNCATE TABLE api_keys;

ALTER TABLE api_keys
ADD CONSTRAINT api_keys_hashed_api_key_key UNIQUE (hashed_api_key);
 


-- File: migrations/2023-02-22-100331_rename_pm_type_enum/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt
ALTER COLUMN payment_method TYPE VARCHAR;

ALTER TABLE payment_methods
ALTER COLUMN payment_method TYPE VARCHAR;

ALTER TABLE payment_methods
ALTER COLUMN payment_method_type TYPE VARCHAR;

ALTER TABLE payment_attempt DROP COLUMN payment_issuer;

ALTER TABLE payment_attempt
ADD COLUMN payment_method_data JSONB;

DROP TYPE "PaymentMethodType";
 


-- File: migrations/2023-02-28-072631_ang-currency/up.sql
-- Your SQL goes here
ALTER TYPE "Currency" ADD VALUE 'ANG' after 'AMD';
 


-- File: migrations/2023-02-28-112730_add_refund_webhook_types/up.sql
-- Your SQL goes here
ALTER TYPE "EventClass" ADD VALUE 'refunds';

ALTER TYPE "EventObjectType" ADD VALUE 'refund_details';

ALTER TYPE "EventType" ADD VALUE 'refund_succeeded';

ALTER TYPE "EventType" ADD VALUE 'refund_failed'; 


-- File: migrations/2023-03-04-114058_remove_api_key_column_merchant_account_table/up.sql
ALTER TABLE merchant_account DROP COLUMN api_key;
 


-- File: migrations/2023-03-07-141638_make_payment_attempt_connector_json/up.sql
-- Alter column type to json
-- as well as the connector.
ALTER TABLE payment_attempt
ALTER COLUMN connector TYPE JSONB
USING jsonb_build_object(
    'routed_through', connector,
    'algorithm',      NULL
);
 


-- File: migrations/2023-03-14-123541_add_cards_info_table/up.sql
-- Your SQL goes here
CREATE TABLE cards_info (
    card_iin VARCHAR(16) PRIMARY KEY,
    card_issuer TEXT,
    card_network TEXT,
    card_type TEXT,
    card_subtype TEXT,
    card_issuing_country TEXT,
    bank_code_id VARCHAR(32),
    bank_code VARCHAR(32),
    country_code VARCHAR(32),
    date_created TIMESTAMP NOT NULL,
    last_updated TIMESTAMP,
    last_updated_provider TEXT
);
 


-- File: migrations/2023-03-15-082312_add_connector_txn_id_merchant_id_index_in_payment_attempt/up.sql
-- Your SQL goes here
CREATE INDEX payment_attempt_connector_transaction_id_merchant_id_index ON payment_attempt (connector_transaction_id, merchant_id);
 


-- File: migrations/2023-03-15-185959_add_dispute_table/up.sql
CREATE TYPE "DisputeStage" AS ENUM ('pre_dispute', 'dispute', 'pre_arbitration');

CREATE TYPE "DisputeStatus" AS ENUM ('dispute_opened', 'dispute_expired', 'dispute_accepted', 'dispute_cancelled', 'dispute_challenged', 'dispute_won', 'dispute_lost');

CREATE TABLE dispute (
    id SERIAL PRIMARY KEY,
    dispute_id VARCHAR(64) NOT NULL,
    amount VARCHAR(255) NOT NULL,
    currency VARCHAR(255) NOT NULL,
    dispute_stage "DisputeStage" NOT NULL,
    dispute_status "DisputeStatus" NOT NULL,
    payment_id VARCHAR(255) NOT NULL,
    attempt_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    connector_status VARCHAR(255) NOT NULL,
    connector_dispute_id VARCHAR(255) NOT NULL,
    connector_reason VARCHAR(255),
    connector_reason_code VARCHAR(255),
    challenge_required_by VARCHAR(255),
    dispute_created_at VARCHAR(255),
    updated_at VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    modified_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP
);

CREATE UNIQUE INDEX merchant_id_dispute_id_index ON dispute (merchant_id, dispute_id);

CREATE UNIQUE INDEX merchant_id_payment_id_connector_dispute_id_index ON dispute (merchant_id, payment_id, connector_dispute_id);

CREATE INDEX dispute_status_index ON dispute (dispute_status);

CREATE INDEX dispute_stage_index ON dispute (dispute_stage);

ALTER TYPE "EventClass" ADD VALUE 'disputes';

ALTER TYPE "EventObjectType" ADD VALUE 'dispute_details';

ALTER TYPE "EventType" ADD VALUE 'dispute_opened';
ALTER TYPE "EventType" ADD VALUE 'dispute_expired';
ALTER TYPE "EventType" ADD VALUE 'dispute_accepted';
ALTER TYPE "EventType" ADD VALUE 'dispute_cancelled';
ALTER TYPE "EventType" ADD VALUE 'dispute_challenged';
ALTER TYPE "EventType" ADD VALUE 'dispute_won';
ALTER TYPE "EventType" ADD VALUE 'dispute_lost';
 


-- File: migrations/2023-03-16-105114_add_data_collection_status/up.sql
ALTER TYPE "AttemptStatus" ADD VALUE IF NOT EXISTS 'device_data_collection_pending'; 


-- File: migrations/2023-03-23-095309_add_business_sub_label_to_mca/up.sql
ALTER TABLE merchant_connector_account
ADD COLUMN IF NOT EXISTS business_sub_label VARCHAR(64) DEFAULT 'default';
 


-- File: migrations/2023-03-23-123920_add_business_label_and_country_to_pi/up.sql
ALTER TABLE payment_intent
ADD COLUMN IF NOT EXISTS business_country VARCHAR(2) NOT NULL DEFAULT 'US',
    ADD COLUMN IF NOT EXISTS business_label VARCHAR(64) NOT NULL DEFAULT 'default';
 


-- File: migrations/2023-03-26-163105_add_unresolved_status/up.sql
ALTER TYPE "AttemptStatus" ADD VALUE IF NOT EXISTS 'unresolved';
ALTER TYPE "IntentStatus" ADD VALUE IF NOT EXISTS 'requires_merchant_action' after 'requires_customer_action';
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'action_required';
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payment_processing';
 


-- File: migrations/2023-03-27-091611_change_country_to_enum/up.sql
CREATE TYPE "CountryCode" AS ENUM (
    'AF',
    'AX',
    'AL',
    'DZ',
    'AS',
    'AD',
    'AO',
    'AI',
    'AQ',
    'AG',
    'AR',
    'AM',
    'AW',
    'AU',
    'AT',
    'AZ',
    'BS',
    'BH',
    'BD',
    'BB',
    'BY',
    'BE',
    'BZ',
    'BJ',
    'BM',
    'BT',
    'BO',
    'BQ',
    'BA',
    'BW',
    'BV',
    'BR',
    'IO',
    'BN',
    'BG',
    'BF',
    'BI',
    'KH',
    'CM',
    'CA',
    'CV',
    'KY',
    'CF',
    'TD',
    'CL',
    'CN',
    'CX',
    'CC',
    'CO',
    'KM',
    'CG',
    'CD',
    'CK',
    'CR',
    'CI',
    'HR',
    'CU',
    'CW',
    'CY',
    'CZ',
    'DK',
    'DJ',
    'DM',
    'DO',
    'EC',
    'EG',
    'SV',
    'GQ',
    'ER',
    'EE',
    'ET',
    'FK',
    'FO',
    'FJ',
    'FI',
    'FR',
    'GF',
    'PF',
    'TF',
    'GA',
    'GM',
    'GE',
    'DE',
    'GH',
    'GI',
    'GR',
    'GL',
    'GD',
    'GP',
    'GU',
    'GT',
    'GG',
    'GN',
    'GW',
    'GY',
    'HT',
    'HM',
    'VA',
    'HN',
    'HK',
    'HU',
    'IS',
    'IN',
    'ID',
    'IR',
    'IQ',
    'IE',
    'IM',
    'IL',
    'IT',
    'JM',
    'JP',
    'JE',
    'JO',
    'KZ',
    'KE',
    'KI',
    'KP',
    'KR',
    'KW',
    'KG',
    'LA',
    'LV',
    'LB',
    'LS',
    'LR',
    'LY',
    'LI',
    'LT',
    'LU',
    'MO',
    'MK',
    'MG',
    'MW',
    'MY',
    'MV',
    'ML',
    'MT',
    'MH',
    'MQ',
    'MR',
    'MU',
    'YT',
    'MX',
    'FM',
    'MD',
    'MC',
    'MN',
    'ME',
    'MS',
    'MA',
    'MZ',
    'MM',
    'NA',
    'NR',
    'NP',
    'NL',
    'NC',
    'NZ',
    'NI',
    'NE',
    'NG',
    'NU',
    'NF',
    'MP',
    'NO',
    'OM',
    'PK',
    'PW',
    'PS',
    'PA',
    'PG',
    'PY',
    'PE',
    'PH',
    'PN',
    'PL',
    'PT',
    'PR',
    'QA',
    'RE',
    'RO',
    'RU',
    'RW',
    'BL',
    'SH',
    'KN',
    'LC',
    'MF',
    'PM',
    'VC',
    'WS',
    'SM',
    'ST',
    'SA',
    'SN',
    'RS',
    'SC',
    'SL',
    'SG',
    'SX',
    'SK',
    'SI',
    'SB',
    'SO',
    'ZA',
    'GS',
    'SS',
    'ES',
    'LK',
    'SD',
    'SR',
    'SJ',
    'SZ',
    'SE',
    'CH',
    'SY',
    'TW',
    'TJ',
    'TZ',
    'TH',
    'TL',
    'TG',
    'TK',
    'TO',
    'TT',
    'TN',
    'TR',
    'TM',
    'TC',
    'TV',
    'UG',
    'UA',
    'AE',
    'GB',
    'US',
    'UM',
    'UY',
    'UZ',
    'VU',
    'VE',
    'VN',
    'VG',
    'VI',
    'WF',
    'EH',
    'YE',
    'ZM',
    'ZW'
);

ALTER TABLE address
ALTER COLUMN country TYPE "CountryCode" USING country::"CountryCode";
 


-- File: migrations/2023-03-30-132338_add_start_end_date_for_mandates/up.sql
ALTER TABLE mandate
ADD IF NOT EXISTS start_date TIMESTAMP NULL,
ADD IF NOT EXISTS end_date TIMESTAMP NULL,
ADD COLUMN metadata JSONB DEFAULT NULL; 


-- File: migrations/2023-04-03-082335_update_mca_frm_configs/up.sql
ALTER TABLE "merchant_connector_account" ADD COLUMN frm_configs jsonb; 


-- File: migrations/2023-04-04-061926_add_dispute_api_schema/up.sql
-- Your SQL goes here
CREATE TABLE file_metadata (
    file_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(255) NOT NULL,
    file_name VARCHAR(255),
    file_size INTEGER NOT NULL,
    file_type VARCHAR(255) NOT NULL,
    provider_file_id VARCHAR(255),
    file_upload_provider VARCHAR(255),
    available BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    PRIMARY KEY (file_id, merchant_id)
);
 


-- File: migrations/2023-04-05-051523_add_business_sub_label_to_payment_attempt/up.sql
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS business_sub_label VARCHAR(64);
 


-- File: migrations/2023-04-05-121040_alter_mca_change_country_to_enum/up.sql
ALTER TABLE merchant_connector_account
ALTER COLUMN business_country TYPE "CountryCode" USING business_country::"CountryCode";
 


-- File: migrations/2023-04-05-121047_alter_pi_change_country_to_enum/up.sql
ALTER TABLE payment_intent
ALTER COLUMN business_country DROP DEFAULT,
    ALTER COLUMN business_country TYPE "CountryCode" USING business_country::"CountryCode";
 


-- File: migrations/2023-04-06-063047_add_connector_col_in_dispute/up.sql
-- Your SQL goes here
ALTER TABLE dispute
ADD COLUMN connector VARCHAR(255) NOT NULL; 


-- File: migrations/2023-04-06-092008_create_merchant_ek/up.sql
CREATE TABLE merchant_key_store(
    merchant_id VARCHAR(255) NOT NULL PRIMARY KEY,
    key bytea NOT NULL,
    created_at TIMESTAMP NOT NULL
);

 


-- File: migrations/2023-04-11-084958_pii-migration/up.sql
-- Your SQL goes here
ALTER TABLE merchant_connector_account
    ALTER COLUMN connector_account_details TYPE bytea
    USING convert_to(connector_account_details::text, 'UTF8');

ALTER TABLE merchant_account
    ALTER COLUMN merchant_name TYPE bytea USING convert_to(merchant_name, 'UTF8'),
    ALTER merchant_details TYPE bytea USING convert_to(merchant_details::text, 'UTF8');

ALTER TABLE address
    ALTER COLUMN line1 TYPE bytea USING convert_to(line1, 'UTF8'),
    ALTER COLUMN line2 TYPE bytea USING convert_to(line2, 'UTF8'),
    ALTER COLUMN line3 TYPE bytea USING convert_to(line3, 'UTF8'),
    ALTER COLUMN state TYPE bytea USING convert_to(state, 'UTF8'),
    ALTER COLUMN zip TYPE bytea USING convert_to(zip, 'UTF8'),
    ALTER COLUMN first_name TYPE bytea USING convert_to(first_name, 'UTF8'),
    ALTER COLUMN last_name TYPE bytea USING convert_to(last_name, 'UTF8'),
    ALTER COLUMN phone_number TYPE bytea USING convert_to(phone_number, 'UTF8');

ALTER TABLE customers
    ALTER COLUMN name TYPE bytea USING convert_to(name, 'UTF8'),
    ALTER COLUMN email TYPE bytea USING convert_to(email, 'UTF8'),
    ALTER COLUMN phone TYPE bytea USING convert_to(phone, 'UTF8');
 


-- File: migrations/2023-04-12-075449_separate_payment_attempt_algorithm_col/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD COLUMN straight_through_algorithm JSONB;

UPDATE payment_attempt SET straight_through_algorithm = connector->'algorithm'
WHERE connector->>'algorithm' IS NOT NULL;

ALTER TABLE payment_attempt
ALTER COLUMN connector TYPE VARCHAR(64)
USING connector->>'routed_through';
 


-- File: migrations/2023-04-13-094917_change_primary_business_type/up.sql
-- This change will allow older merchant accounts to be used with new changes
UPDATE merchant_account
SET primary_business_details = '[{"country": "US", "business": "default"}]';

-- Since this field is optional, default is not required
ALTER TABLE merchant_connector_account
ALTER COLUMN business_sub_label DROP DEFAULT;
 


-- File: migrations/2023-04-19-072152_merchant_account_add_intent_fulfilment_time/up.sql
ALTER TABLE merchant_account ADD COLUMN IF NOT EXISTS intent_fulfillment_time BIGINT;
 


-- File: migrations/2023-04-19-120503_update_customer_connector_customer/up.sql
-- Your SQL goes here
ALTER TABLE customers
ADD COLUMN connector_customer JSONB; 


-- File: migrations/2023-04-19-120735_add_time_for_tables/up.sql
-- Your SQL goes here
ALTER TABLE merchant_account
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT now(),
ADD COLUMN IF NOT EXISTS modified_at TIMESTAMP NOT NULL DEFAULT now();

ALTER TABLE merchant_connector_account
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT now(),
ADD COLUMN IF NOT EXISTS modified_at TIMESTAMP NOT NULL DEFAULT now();


ALTER TABLE customers
ADD COLUMN IF NOT EXISTS modified_at TIMESTAMP NOT NULL DEFAULT now();
 


-- File: migrations/2023-04-20-073704_allow_multiple_mandate_ids/up.sql
ALTER TABLE mandate
    ADD COLUMN connector_mandate_ids jsonb;
UPDATE mandate SET connector_mandate_ids = jsonb_build_object(
            'mandate_id', connector_mandate_id,
            'payment_method_id', NULL
        ); 


-- File: migrations/2023-04-20-162755_add_preprocessing_step_id_payment_attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt ADD COLUMN preprocessing_step_id VARCHAR DEFAULT NULL;
CREATE INDEX preprocessing_step_id_index ON payment_attempt (preprocessing_step_id);
 


-- File: migrations/2023-04-21-100150_create_index_for_api_keys/up.sql
CREATE UNIQUE INDEX api_keys_merchant_id_key_id_index ON api_keys (merchant_id, key_id); 


-- File: migrations/2023-04-25-061159_rename_country_code_to_country_alpha2/up.sql
-- Your SQL goes here
ALTER TYPE "CountryCode" RENAME TO "CountryAlpha2"; 


-- File: migrations/2023-04-25-091017_merchant_account_add_frm_routing_algorithm.sql/up.sql

ALTER TABLE merchant_account
ADD COLUMN frm_routing_algorithm JSONB NULL; 


-- File: migrations/2023-04-25-141011_add_connector_label_col_in_file_metadata/up.sql
-- Your SQL goes here
ALTER TABLE file_metadata
ADD COLUMN connector_label VARCHAR(255); 


-- File: migrations/2023-04-26-062424_alter_dispute_table/up.sql
ALTER TABLE dispute
ALTER COLUMN challenge_required_by TYPE TIMESTAMP USING dispute_created_at::TIMESTAMP,
ALTER COLUMN dispute_created_at TYPE TIMESTAMP USING dispute_created_at::TIMESTAMP,
ALTER COLUMN updated_at TYPE TIMESTAMP USING dispute_created_at::TIMESTAMP;


-- File: migrations/2023-04-26-090005_remove_default_created_at_modified_at/up.sql
-- Merchant Account
ALTER TABLE merchant_account
ALTER COLUMN modified_at DROP DEFAULT;

ALTER TABLE merchant_account
ALTER COLUMN created_at DROP DEFAULT;


-- Merchant Connector Account
ALTER TABLE merchant_connector_account
ALTER COLUMN modified_at DROP DEFAULT;

ALTER TABLE merchant_connector_account
ALTER COLUMN created_at DROP DEFAULT;

-- Customers
ALTER TABLE customers
ALTER COLUMN modified_at DROP DEFAULT;

ALTER TABLE customers
ALTER COLUMN created_at DROP DEFAULT;

-- Address
ALTER TABLE address
ALTER COLUMN modified_at DROP DEFAULT;

ALTER TABLE address
ALTER COLUMN created_at DROP DEFAULT;

-- Refunds
ALTER TABLE refund
ALTER COLUMN modified_at DROP DEFAULT;

ALTER TABLE refund
ALTER COLUMN created_at DROP DEFAULT;

-- Connector Response
ALTER TABLE connector_response
ALTER COLUMN modified_at DROP DEFAULT;

ALTER TABLE connector_response
ALTER COLUMN created_at DROP DEFAULT;

-- Payment methods
ALTER TABLE payment_methods
ALTER COLUMN created_at DROP DEFAULT;

-- Payment Intent
ALTER TABLE payment_intent
ALTER COLUMN modified_at DROP DEFAULT;

ALTER TABLE payment_intent
ALTER COLUMN created_at DROP DEFAULT;

--- Payment Attempt
ALTER TABLE payment_attempt
ALTER COLUMN modified_at DROP DEFAULT;

ALTER TABLE payment_attempt
ALTER COLUMN created_at DROP DEFAULT;
 


-- File: migrations/2023-04-27-120010_add_payment_failed_event_type/up.sql
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payment_failed'; 


-- File: migrations/2023-05-02-102332_payout_create/up.sql
CREATE type "PayoutStatus" AS ENUM (
    'success',
    'failed',
    'cancelled',
    'pending',
    'ineligible',
    'requires_creation',
    'requires_payout_method_data',
    'requires_fulfillment'
);

CREATE type "PayoutType" AS ENUM ('card', 'bank');

CREATE TABLE
    PAYOUT_ATTEMPT (
        payout_attempt_id VARCHAR (64) NOT NULL PRIMARY KEY,
        payout_id VARCHAR (64) NOT NULL,
        customer_id VARCHAR (64) NOT NULL,
        merchant_id VARCHAR (64) NOT NULL,
        address_id VARCHAR (64) NOT NULL,
        connector VARCHAR (64) NOT NULL,
        connector_payout_id VARCHAR (128) NOT NULL,
        payout_token VARCHAR (64),
        status "PayoutStatus" NOT NULL,
        is_eligible BOOLEAN,
        error_message TEXT,
        error_code VARCHAR (64),
        business_country "CountryAlpha2",
        business_label VARCHAR(64),
        created_at timestamp NOT NULL DEFAULT NOW():: timestamp,
        last_modified_at timestamp NOT NULL DEFAULT NOW():: timestamp
    );

CREATE TABLE
    PAYOUTS (
        payout_id VARCHAR (64) NOT NULL PRIMARY KEY,
        merchant_id VARCHAR (64) NOT NULL,
        customer_id VARCHAR (64) NOT NULL,
        address_id VARCHAR (64) NOT NULL,
        payout_type "PayoutType" NOT NULL,
        payout_method_id VARCHAR (64),
        amount BIGINT NOT NULL,
        destination_currency "Currency" NOT NULL,
        source_currency "Currency" NOT NULL,
        description VARCHAR (255),
        recurring BOOLEAN NOT NULL,
        auto_fulfill BOOLEAN NOT NULL,
        return_url VARCHAR (255),
        entity_type VARCHAR (64) NOT NULL,
        metadata JSONB DEFAULT '{}':: JSONB,
        created_at timestamp NOT NULL DEFAULT NOW():: timestamp,
        last_modified_at timestamp NOT NULL DEFAULT NOW():: timestamp
    );

CREATE UNIQUE INDEX payout_attempt_index ON PAYOUT_ATTEMPT (
    merchant_id,
    payout_attempt_id,
    payout_id
);

CREATE UNIQUE INDEX payouts_index ON PAYOUTS (merchant_id, payout_id);

-- Alterations

ALTER TABLE merchant_account
ADD
    COLUMN payout_routing_algorithm JSONB;

ALTER TABLE locker_mock_up ADD COLUMN enc_card_data TEXT;

ALTER TYPE "ConnectorType" ADD VALUE 'payout_processor'; 


-- File: migrations/2023-05-03-121025_nest_straight_through_col_in_payment_attempt/up.sql
-- Your SQL goes here
UPDATE payment_attempt
SET straight_through_algorithm = jsonb_build_object('algorithm', straight_through_algorithm);
 


-- File: migrations/2023-05-05-112013_add_evidence_col_in_dispute/up.sql
-- Your SQL goes here
ALTER TABLE dispute
ADD COLUMN evidence JSONB NOT NULL DEFAULT '{}'::JSONB; 


-- File: migrations/2023-05-08-141907_rename_dispute_cols/up.sql
-- Your SQL goes here
ALTER TABLE dispute
RENAME COLUMN dispute_created_at TO connector_created_at;

ALTER TABLE dispute
RENAME COLUMN updated_at TO connector_updated_at;
 


-- File: migrations/2023-05-16-145008_mandate_data_in_pa/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt ADD COLUMN mandate_details JSONB;
 


-- File: migrations/2023-05-29-094747_order-details-as-a-separate-column.sql/up.sql
ALTER TABLE payment_intent ADD COLUMN order_details jsonb[]; 


-- File: migrations/2023-05-31-152153_add_connector_webhook_details_to_mca/up.sql
-- Your SQL goes here
ALTER TABLE merchant_connector_account
ADD COLUMN IF NOT EXISTS connector_webhook_details JSONB DEFAULT NULL; 


-- File: migrations/2023-06-14-105035_add_reason_in_payment_attempt/up.sql
ALTER TABLE payment_attempt
ADD COLUMN error_reason TEXT;
 


-- File: migrations/2023-06-16-073615_add_ron_currency_to_db/up.sql
-- Your SQL goes here
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'RON' AFTER 'QAR';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'TRY' AFTER 'TTD';
 


-- File: migrations/2023-06-18-042123_add_udf_column_in_payments/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN udf JSONB;
 


-- File: migrations/2023-06-19-071300_merchant_key_store_shrink_merchant_id/up.sql
ALTER TABLE merchant_key_store
ALTER COLUMN merchant_id TYPE VARCHAR(64);
 


-- File: migrations/2023-06-22-161131_change-type-of-frm-configs.sql/up.sql
UPDATE merchant_connector_account set frm_configs = null ;

ALTER TABLE merchant_connector_account 
ALTER COLUMN frm_configs TYPE jsonb[]
USING ARRAY[frm_configs]::jsonb[];

UPDATE merchant_connector_account set frm_configs = null ;
 


-- File: migrations/2023-06-26-124254_add_vnd_to_currency_enum/up.sql
-- Your SQL goes here
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'VND' AFTER 'UZS'; 


-- File: migrations/2023-06-29-094858_payment-intent-remove-udf-field/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent DROP COLUMN udf;
 


-- File: migrations/2023-07-01-184850_payment-intent-add-metadata-fields/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent
ADD COLUMN allowed_payment_method_types JSON,
ADD COLUMN connector_metadata JSON,
ADD COLUMN feature_metadata JSON;
 


-- File: migrations/2023-07-03-093552_add_attempt_count_in_payment_intent/up.sql
ALTER TABLE payment_intent ADD COLUMN attempt_count SMALLINT NOT NULL DEFAULT 1;

UPDATE payment_intent
SET attempt_count = payment_id_count.count
FROM (SELECT payment_id, count(payment_id) FROM payment_attempt GROUP BY payment_id) as payment_id_count
WHERE payment_intent.payment_id = payment_id_count.payment_id;
 


-- File: migrations/2023-07-04-131721_add_org_id_and_org_name/up.sql
-- Your SQL goes here
ALTER TABLE merchant_account
ADD COLUMN IF NOT EXISTS organization_id VARCHAR(32);
 


-- File: migrations/2023-07-07-091223_create_captures_table/up.sql

CREATE TYPE "CaptureStatus" AS ENUM (
    'started',
    'charged',
    'pending',
    'failed'
);
ALTER TYPE "IntentStatus" ADD VALUE If NOT EXISTS 'partially_captured' AFTER 'requires_capture';
CREATE TABLE captures(
    capture_id VARCHAR(64) NOT NULL PRIMARY KEY,
    payment_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(64) NOT NULL,
    status "CaptureStatus" NOT NULL,
    amount BIGINT NOT NULL,
    currency "Currency",
    connector VARCHAR(255),
    error_message VARCHAR(255),
    error_code VARCHAR(255),
    error_reason VARCHAR(255),
    tax_amount BIGINT,
    created_at TIMESTAMP NOT NULL,
    modified_at TIMESTAMP NOT NULL,
    authorized_attempt_id VARCHAR(64) NOT NULL,
    connector_transaction_id VARCHAR(128),
    capture_sequence SMALLINT NOT NULL
);

CREATE INDEX captures_merchant_id_payment_id_authorized_attempt_id_index ON captures (
    merchant_id,
    payment_id,
    authorized_attempt_id
);
CREATE INDEX captures_connector_transaction_id_index ON captures (
    connector_transaction_id
);

ALTER TABLE payment_attempt
ADD COLUMN multiple_capture_count SMALLINT; --number of captures available for this payment attempt in captures table
 


-- File: migrations/2023-07-08-134807_add_connector_response_reference_id_in_payment_intent/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt ADD COLUMN IF NOT EXISTS connector_response_reference_id VARCHAR(128); 


-- File: migrations/2023-07-11-140347_add_is_recon_enabled_field_in_merchant_account/up.sql
-- Your SQL goes here
ALTER TABLE merchant_account ADD COLUMN "is_recon_enabled" BOOLEAN NOT NULL DEFAULT FALSE; 


-- File: migrations/2023-07-17-111427_add-fraud-check-table.sql/up.sql
-- Your SQL goes here-- Your SQL goes here
CREATE TYPE "FraudCheckType" AS ENUM (
    'pre_frm',
    'post_frm'
);

CREATE TYPE "FraudCheckStatus" AS ENUM (
    'fraud',
    'manual_review',
    'pending',
    'legit',
    'transaction_failure'
);

CREATE TABLE fraud_check (
    frm_id VARCHAR(64) NOT NULL UNIQUE,
    payment_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(64) NOT NULL,
    attempt_id VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    frm_name VARCHAR(255) NOT NULL,
    frm_transaction_id VARCHAR(255) UNIQUE,
    frm_transaction_type "FraudCheckType" NOT NULL,
    frm_status "FraudCheckStatus" NOT NULL,
    frm_score INTEGER,
    frm_reason JSONB,
    frm_error VARCHAR(255),
    payment_details JSONB,
    metadata JSONB,
    modified_at TIMESTAMP NOT NULL DEFAULT now(),

    PRIMARY KEY (frm_id, attempt_id, payment_id, merchant_id)
);

CREATE UNIQUE INDEX frm_id_index ON fraud_check (frm_id, attempt_id, payment_id, merchant_id);
 


-- File: migrations/2023-07-19-081050_add_zero_decimal_currencies/up.sql
-- Your SQL goes here
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'BIF' AFTER 'BHD';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'CLP' AFTER 'CHF';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'DJF' AFTER 'CZK';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'GNF' AFTER 'GMD';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'KMF' AFTER 'KHR';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'MGA' AFTER 'MDL';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'PYG' AFTER 'PLN';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'RWF' AFTER 'RUB';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'UGX' AFTER 'TZS';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'VUV' AFTER 'VND';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'XAF' AFTER 'VUV';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'XOF' AFTER 'XAF';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'XPF' AFTER 'XOF';
 


-- File: migrations/2023-07-28-111829_update_columns_to_fix_db_diff/up.sql
ALTER TABLE dispute
ALTER COLUMN payment_id TYPE VARCHAR(64);

ALTER TABLE payment_methods
ALTER COLUMN payment_method_type TYPE VARCHAR(64);

ALTER TABLE merchant_account
ALTER COLUMN primary_business_details DROP DEFAULT; 


-- File: migrations/2023-08-01-165717_make_event_id_unique_for_events_table/up.sql
-- Your SQL goes here
ALTER TABLE events
ADD CONSTRAINT event_id_unique UNIQUE (event_id);
 


-- File: migrations/2023-08-08-144148_add_business_profile_table/up.sql
-- Your SQL goes here
CREATE TABLE IF NOT EXISTS business_profile (
    profile_id VARCHAR(64) PRIMARY KEY,
    merchant_id VARCHAR(64) NOT NULL,
    profile_name VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    modified_at TIMESTAMP NOT NULL,
    return_url TEXT,
    enable_payment_response_hash BOOLEAN NOT NULL DEFAULT TRUE,
    payment_response_hash_key VARCHAR(255) DEFAULT NULL,
    redirect_to_merchant_with_http_post BOOLEAN NOT NULL DEFAULT FALSE,
    webhook_details JSON,
    metadata JSON,
    routing_algorithm JSON,
    intent_fulfillment_time BIGINT,
    frm_routing_algorithm JSONB,
    payout_routing_algorithm JSONB,
    is_recon_enabled BOOLEAN NOT NULL DEFAULT FALSE
);
 


-- File: migrations/2023-08-11-073905_add_frm_config_in_mca/up.sql
ALTER TABLE "merchant_connector_account" ADD COLUMN frm_config jsonb[];
-- Do not run below migration in PROD as this only makes sandbox compatible to PROD version
ALTER TABLE merchant_connector_account 
ALTER COLUMN frm_configs TYPE jsonb
USING frm_configs[1]::jsonb; 


-- File: migrations/2023-08-16-080721_make_connector_field_mandatory_capture_table/up.sql
-- Your SQL goes here
ALTER TABLE captures ALTER COLUMN connector SET NOT NULL;
ALTER TABLE captures RENAME COLUMN connector_transaction_id TO connector_capture_id;
ALTER TABLE captures add COLUMN IF NOT EXISTS connector_response_reference_id VARCHAR(128); 


-- File: migrations/2023-08-16-103806_add_last_executed_frm_step/up.sql
alter table fraud_check add column last_step VARCHAR(64) NOT NULL DEFAULT 'processing'; 


-- File: migrations/2023-08-16-112847_add_profile_id_in_affected_tables/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent
ADD COLUMN IF NOT EXISTS profile_id VARCHAR(64);

ALTER TABLE merchant_connector_account
ADD COLUMN IF NOT EXISTS profile_id VARCHAR(64);

ALTER TABLE merchant_account
ADD COLUMN IF NOT EXISTS default_profile VARCHAR(64);

-- Profile id is needed in refunds for listing refunds by business profile
ALTER TABLE refund
ADD COLUMN IF NOT EXISTS profile_id VARCHAR(64);

-- For listing disputes by business profile
ALTER TABLE dispute
ADD COLUMN IF NOT EXISTS profile_id VARCHAR(64);

-- For a similar use case as to payments
ALTER TABLE payout_attempt
ADD COLUMN IF NOT EXISTS profile_id VARCHAR(64);
 


-- File: migrations/2023-08-23-090712_payment_attempt_perf_idx/up.sql
-- Your SQL goes here
CREATE INDEX payment_attempt_attempt_id_merchant_id_index ON payment_attempt (attempt_id, merchant_id);

 


-- File: migrations/2023-08-24-095037_add_profile_id_in_file_metadata/up.sql
-- Your SQL goes here
ALTER TABLE file_metadata
ADD COLUMN IF NOT EXISTS profile_id VARCHAR(64);
 


-- File: migrations/2023-08-25-094551_add_recon_status_in_merchant_account/up.sql
-- Your SQL goes here
CREATE TYPE "ReconStatus" AS ENUM ('requested','active', 'disabled','not_requested');
ALTER TABLE merchant_account ADD recon_status "ReconStatus" NOT NULL DEFAULT "ReconStatus"('not_requested'); 


-- File: migrations/2023-08-28-131238_make_business_details_optional/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent
ALTER COLUMN business_country DROP NOT NULL;

ALTER TABLE payment_intent
ALTER COLUMN business_label DROP NOT NULL;

ALTER TABLE merchant_connector_account
ALTER COLUMN business_country DROP NOT NULL;

ALTER TABLE merchant_connector_account
ALTER COLUMN business_label DROP NOT NULL;

ALTER TABLE merchant_connector_account
ALTER COLUMN connector_label DROP NOT NULL;

DROP INDEX IF EXISTS merchant_connector_account_merchant_id_connector_label_index;

CREATE UNIQUE INDEX IF NOT EXISTS merchant_connector_account_profile_id_connector_id_index ON merchant_connector_account(profile_id, connector_name);

CREATE UNIQUE INDEX IF NOT EXISTS business_profile_merchant_id_profile_name_index ON business_profile(merchant_id, profile_name);
 


-- File: migrations/2023-08-31-093852_add_merchant_decision/up.sql
alter table payment_intent add column merchant_decision VARCHAR(64); 


-- File: migrations/2023-09-06-101704_payment_method_data_in_payment_methods/up.sql
-- Your SQL goes here
ALTER TABLE payment_methods ADD COLUMN IF NOT EXISTS payment_method_data BYTEA DEFAULT NULL; 


-- File: migrations/2023-09-07-113914_add_amount_capturable_field_payment_attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS amount_capturable BIGINT NOT NULL DEFAULT 0; 


-- File: migrations/2023-09-08-101302_add_payment_link/up.sql
-- Your SQL goes here
CREATE TABLE payment_link (
    payment_link_id VARCHAR(255) NOT NULL,
    payment_id VARCHAR(64) NOT NULL,
    link_to_pay VARCHAR(255) NOT NULL,
    merchant_id VARCHAR(64) NOT NULL,
    amount INT8 NOT NULL,
    currency "Currency",
    created_at TIMESTAMP NOT NULL,
    last_modified_at TIMESTAMP NOT NULL,
    fulfilment_time TIMESTAMP,
    PRIMARY KEY (payment_link_id)
);
 


-- File: migrations/2023-09-08-112817_applepay_verified_domains_in_business_profile/up.sql
ALTER TABLE business_profile
ADD COLUMN IF NOT EXISTS applepay_verified_domains text[];

 


-- File: migrations/2023-09-08-114828_add_payment_link_id_in_payment_intent/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent ADD column payment_link_id VARCHAR(255); 


-- File: migrations/2023-09-08-134514_add_payment_confirm_source_in_payment_intent/up.sql
-- Your SQL goes here
CREATE TYPE "PaymentSource" AS ENUM (
    'merchant_server',
    'postman',
    'dashboard',
    'sdk'
);

ALTER TABLE payment_intent
ADD COLUMN IF NOT EXISTS payment_confirm_source "PaymentSource"; 


-- File: migrations/2023-09-13-075226_applepay_verified_domains_in_mca/up.sql
ALTER TABLE merchant_connector_account
ADD COLUMN IF NOT EXISTS applepay_verified_domains text[];
 


-- File: migrations/2023-09-14-032447_add_payment_id_in_address/up.sql
-- Your SQL goes here
ALTER TABLE address ADD COLUMN payment_id VARCHAR(64);
ALTER TABLE customers ADD COLUMN address_id VARCHAR(64); 


-- File: migrations/2023-09-17-152010_make_id_not_null_address/up.sql
-- Your SQL goes here
ALTER TABLE address ALTER COLUMN id DROP NOT NULL; 


-- File: migrations/2023-09-18-104900_add_pm_auth_config_mca/up.sql
-- Your SQL goes here
ALTER TABLE merchant_connector_account ADD COLUMN IF NOT EXISTS pm_auth_config JSONB DEFAULT NULL;
ALTER TYPE "ConnectorType" ADD VALUE 'payment_method_auth'; 


-- File: migrations/2023-09-25-125007_add_surcharge_metadata_payment_attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS surcharge_metadata JSONB DEFAULT NULL; 


-- File: migrations/2023-10-05-085859_make_org_id_mandatory_in_ma/up.sql
-- Your SQL goes here
UPDATE merchant_account
SET organization_id = 'org_abcdefghijklmn'
WHERE organization_id IS NULL;

ALTER TABLE merchant_account
ALTER COLUMN organization_id
SET NOT NULL;
 


-- File: migrations/2023-10-05-114138_add_payment_id_in_mandate/up.sql
-- Your SQL goes here
ALTER TABLE mandate ADD COLUMN original_payment_id VARCHAR(64); 


-- File: migrations/2023-10-05-130917_add_mandate_webhook_types/up.sql
-- Your SQL goes here
ALTER TYPE "EventClass" ADD VALUE 'mandates';

ALTER TYPE "EventObjectType" ADD VALUE 'mandate_details';

ALTER TYPE "EventType" ADD VALUE 'mandate_active';

ALTER TYPE "EventType" ADD VALUE 'mandate_revoked'; 


-- File: migrations/2023-10-06-101134_add_paymentLink_metadata_in_merchant_account/up.sql
-- Your SQL goes here
ALTER TABLE merchant_account
ADD COLUMN IF NOT EXISTS payment_link_config JSONB NULL;

 


-- File: migrations/2023-10-13-090450_add_updated_by_for_tables/up.sql
ALTER TABLE payment_intent ADD column updated_by VARCHAR(32) NOT NULL DEFAULT 'postgres_only';

ALTER TABLE payment_attempt ADD column updated_by VARCHAR(32) NOT NULL DEFAULT 'postgres_only';

ALTER TABLE refund ADD column updated_by VARCHAR(32) NOT NULL DEFAULT 'postgres_only';

ALTER TABLE connector_response ADD column updated_by VARCHAR(32) NOT NULL DEFAULT 'postgres_only';

ALTER TABLE reverse_lookup ADD column updated_by VARCHAR(32) NOT NULL DEFAULT 'postgres_only';

ALTER TABLE address ADD column updated_by VARCHAR(32) NOT NULL DEFAULT 'postgres_only';

 


-- File: migrations/2023-10-13-100447_add-payment-cancelledvent-type/up.sql
-- Your SQL goes here
ALTER TYPE "EventType" ADD VALUE 'payment_cancelled'; 


-- File: migrations/2023-10-19-071731_add_connector_id_to_payment_attempt/up.sql
-- Your SQL goes here
-- The type is VARCHAR(32) as this will store the merchant_connector_account id
-- which will be generated by the application using default length
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS merchant_connector_id VARCHAR(32);
 


-- File: migrations/2023-10-19-075810_add_surcharge_applicable_payment_intent/up.sql
ALTER TABLE payment_attempt
DROP COLUMN surcharge_metadata;


ALTER TABLE payment_intent
ADD surcharge_applicable boolean; 


-- File: migrations/2023-10-19-101558_create_routing_algorithm_table/up.sql
-- Your SQL goes here

CREATE TYPE "RoutingAlgorithmKind" AS ENUM ('single', 'priority', 'volume_split', 'advanced');

CREATE TABLE routing_algorithm (
    algorithm_id VARCHAR(64) PRIMARY KEY,
    profile_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(64) NOT NULL,
    name VARCHAR(64) NOT NULL,
    description VARCHAR(256),
    kind "RoutingAlgorithmKind" NOT NULL,
    algorithm_data JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL,
    modified_at TIMESTAMP NOT NULL
);

CREATE INDEX routing_algorithm_profile_id_modified_at ON routing_algorithm (profile_id, modified_at DESC);

CREATE INDEX routing_algorithm_merchant_id_modified_at ON routing_algorithm (merchant_id, modified_at DESC);
 


-- File: migrations/2023-10-19-102636_back_fill_n_remove_connector_response/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt 
ADD COLUMN authentication_data JSON, 
ADD COLUMN encoded_data TEXT;

UPDATE payment_attempt 
SET (authentication_data, encoded_data) = (connector_response.authentication_data, connector_response.encoded_data) 
from connector_response 
where payment_attempt.payment_id = connector_response.payment_id 
    and payment_attempt.attempt_id = connector_response.attempt_id
    and payment_attempt.merchant_id = connector_response.merchant_id;
 


-- File: migrations/2023-10-19-124023_add_connector_id_to_other_tables/up.sql
-- Your SQL goes here
ALTER TABLE file_metadata
ADD COLUMN IF NOT EXISTS merchant_connector_id VARCHAR(32);

ALTER TABLE refund
ADD COLUMN IF NOT EXISTS merchant_connector_id VARCHAR(32);

ALTER TABLE payout_attempt
ADD COLUMN IF NOT EXISTS merchant_connector_id VARCHAR(32);

ALTER TABLE dispute
ADD COLUMN IF NOT EXISTS merchant_connector_id VARCHAR(32);

ALTER TABLE mandate
ADD COLUMN IF NOT EXISTS merchant_connector_id VARCHAR(32);
 


-- File: migrations/2023-10-23-101023_add_organization_table/up.sql
-- Your SQL goes here
CREATE TABLE IF NOT EXISTS ORGANIZATION (
    org_id VARCHAR(32) PRIMARY KEY NOT NULL,
    org_name TEXT
);
 


-- File: migrations/2023-10-25-070909_add_merchant_custom_name_payment_link/up.sql
-- Your SQL goes here
ALTER TABLE payment_link ADD COLUMN custom_merchant_name VARCHAR(64); 


-- File: migrations/2023-10-27-064512_alter_payout_profile_id/up.sql
ALTER TABLE
    payout_attempt
ALTER COLUMN
    profile_id
SET
    NOT NULL; 


-- File: migrations/2023-10-31-070509_add_payment_link_config_in_payment_link_db/up.sql
-- Your SQL goes here
ALTER TABLE payment_link ADD COLUMN IF NOT EXISTS payment_link_config JSONB NULL;
 


-- File: migrations/2023-11-02-074243_make_customer_id_nullable_in_address_table/up.sql
-- Your SQL goes here
ALTER TABLE address ALTER COLUMN customer_id DROP NOT NULL; 


-- File: migrations/2023-11-06-065213_add_description_to_payment_link/up.sql
-- Your SQL goes here
ALTER table payment_link ADD COLUMN IF NOT EXISTS description VARCHAR (255); 


-- File: migrations/2023-11-06-110233_create_user_table/up.sql
-- Your SQL goes here
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    is_verified bool NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    last_modified_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS user_id_index ON users (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS user_email_index ON users (email); 


-- File: migrations/2023-11-06-113726_create_user_roles_table/up.sql
-- Your SQL goes here
CREATE TABLE IF NOT EXISTS user_roles (
	id SERIAL PRIMARY KEY,
	user_id VARCHAR(64) NOT NULL,
	merchant_id VARCHAR(64) NOT NULL,
	role_id VARCHAR(64) NOT NULL,
	org_id VARCHAR(64) NOT NULL, 
	status VARCHAR(64) NOT NULL, 
	created_by VARCHAR(64) NOT NULL,
	last_modified_by VARCHAR(64) NOT NULL,
	created_at TIMESTAMP NOT NULL DEFAULT now(),
	last_modified_at TIMESTAMP NOT NULL DEFAULT now(),
	CONSTRAINT user_merchant_unique UNIQUE (user_id, merchant_id)
);


CREATE INDEX IF NOT EXISTS  user_id_roles_index ON user_roles (user_id);
CREATE INDEX IF NOT EXISTS  user_mid_roles_index ON user_roles (merchant_id); 


-- File: migrations/2023-11-06-153840_introduce_new_attempt_and_intent_status/up.sql
-- Your SQL goes here
ALTER TYPE "IntentStatus" ADD VALUE IF NOT EXISTS 'partially_captured_and_capturable';
ALTER TYPE "AttemptStatus" ADD VALUE IF NOT EXISTS 'partial_charged_and_chargeable'; 


-- File: migrations/2023-11-07-110139_add_gsm_table/up.sql
-- Your SQL goes here
-- Tables
CREATE TABLE IF NOT EXISTS gateway_status_map (
    connector VARCHAR(64) NOT NULL,
    flow VARCHAR(64) NOT NULL,
    sub_flow VARCHAR(64) NOT NULL,
    code VARCHAR(255) NOT NULL,
    message VARCHAR(1024),
    status VARCHAR(64) NOT NULL,
    router_error VARCHAR(64),
    decision VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    last_modified TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    step_up_possible BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (connector, flow, sub_flow, code, message)
);
 


-- File: migrations/2023-11-08-144951_drop_connector_response_table/up.sql
-- Your SQL goes here
DROP TABLE connector_response; --NOT to run in deployment envs 


-- File: migrations/2023-11-12-131143_connector-status-column/up.sql
-- Your SQL goes here
CREATE TYPE "ConnectorStatus" AS ENUM ('active', 'inactive');

ALTER TABLE merchant_connector_account
ADD COLUMN status "ConnectorStatus";

UPDATE merchant_connector_account SET status='active';

ALTER TABLE merchant_connector_account
ALTER COLUMN status SET NOT NULL,
ALTER COLUMN status SET DEFAULT 'inactive';
 


-- File: migrations/2023-11-17-061003_add-unifiedrror-code-mssg-gsm/up.sql
-- Your SQL goes here
ALTER TABLE gateway_status_map ADD COLUMN IF NOT EXISTS unified_code VARCHAR(255);
ALTER TABLE gateway_status_map ADD COLUMN IF NOT EXISTS unified_message VARCHAR(1024); 


-- File: migrations/2023-11-17-084413_add-unifiedrror-code-mssg-payment-attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt ADD COLUMN IF NOT EXISTS unified_code VARCHAR(255);
ALTER TABLE payment_attempt ADD COLUMN IF NOT EXISTS unified_message VARCHAR(1024); 


-- File: migrations/2023-11-23-100644_create_dashboard_metadata_table/up.sql
-- Your SQL goes here

CREATE TABLE IF NOT EXISTS dashboard_metadata (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(64),
        merchant_id VARCHAR(64) NOT NULL,
        org_id VARCHAR(64) NOT NULL,
        data_key VARCHAR(64) NOT NULL,
        data_value JSON NOT NULL,
        created_by VARCHAR(64) NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT now(),
        last_modified_by VARCHAR(64) NOT NULL,
        last_modified_at TIMESTAMP NOT NULL DEFAULT now()
    );

CREATE UNIQUE INDEX IF NOT EXISTS dashboard_metadata_index ON dashboard_metadata (
    COALESCE(user_id, '0'),
    merchant_id,
    org_id,
    data_key
); 


-- File: migrations/2023-11-24-112541_add_payment_config_business_profile/up.sql
-- Your SQL goes here
ALTER TABLE business_profile
ADD COLUMN IF NOT EXISTS payment_link_config JSONB DEFAULT NULL;
 


-- File: migrations/2023-11-24-115538_add_profile_id_payment_link/up.sql
-- Your SQL goes here
ALTER TABLE payment_link ADD COLUMN IF NOT EXISTS  profile_id VARCHAR(64) DEFAULT NULL;
 


-- File: migrations/2023-11-28-081058_add-request_incremental_authorization-in-payment-intent/up.sql
-- Your SQL goes here
CREATE TYPE "RequestIncrementalAuthorization" AS ENUM ('true', 'false', 'default');
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS request_incremental_authorization "RequestIncrementalAuthorization" NOT NULL DEFAULT 'false'::"RequestIncrementalAuthorization";
 


-- File: migrations/2023-11-29-063030_add-incremental_authorization_allowed-in-payment-intent/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS incremental_authorization_allowed BOOLEAN; 


-- File: migrations/2023-11-30-170902_add-authorizations-table/up.sql
-- Your SQL goes here

CREATE TABLE IF NOT EXISTS incremental_authorization (
    authorization_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(64) NOT NULL,
    payment_id VARCHAR(64) NOT NULL,
    amount BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    modified_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    status VARCHAR(64) NOT NULL,
    error_code VARCHAR(255),
    error_message TEXT,
    connector_authorization_id VARCHAR(64),
    previously_authorized_amount BIGINT NOT NULL,
    PRIMARY KEY (authorization_id, merchant_id)
); 


-- File: migrations/2023-12-01-090834_add-authorization_count-in-payment_intent/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS authorization_count INTEGER;
 


-- File: migrations/2023-12-06-060216_change_primary_key_for_mca/up.sql
-- Your SQL goes here
ALTER TABLE merchant_connector_account
ADD UNIQUE (profile_id, connector_label);

DROP INDEX IF EXISTS "merchant_connector_account_profile_id_connector_id_index";
 


-- File: migrations/2023-12-06-112810_add_intent_fullfilment_time_payment_intent/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS session_expiry TIMESTAMP DEFAULT NULL;
 


-- File: migrations/2023-12-07-075240_make-request-incremental-auth-optional-intent/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent ALTER COLUMN request_incremental_authorization DROP NOT NULL; 


-- File: migrations/2023-12-11-075542_create_pm_fingerprint_table/up.sql
-- Your SQL goes here

CREATE TYPE "BlocklistDataKind" AS ENUM (
    'payment_method',
    'card_bin',
    'extended_card_bin'
);

CREATE TABLE blocklist_fingerprint (
  id SERIAL PRIMARY KEY,
  merchant_id VARCHAR(64) NOT NULL,
  fingerprint_id VARCHAR(64) NOT NULL,
  data_kind "BlocklistDataKind" NOT NULL,
  encrypted_fingerprint TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX blocklist_fingerprint_merchant_id_fingerprint_id_index
ON blocklist_fingerprint (merchant_id, fingerprint_id);
 


-- File: migrations/2023-12-12-112941_create_pm_blocklist_table/up.sql
-- Your SQL goes here

CREATE TABLE blocklist (
  id SERIAL PRIMARY KEY,
  merchant_id VARCHAR(64) NOT NULL,
  fingerprint_id VARCHAR(64) NOT NULL,
  data_kind "BlocklistDataKind" NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX blocklist_unique_fingerprint_id_index ON blocklist (merchant_id, fingerprint_id);
CREATE INDEX blocklist_merchant_id_data_kind_created_at_index ON blocklist (merchant_id, data_kind, created_at DESC);
 


-- File: migrations/2023-12-12-113330_add_fingerprint_id_in_payment_intent/up.sql
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS fingerprint_id VARCHAR(64);
 


-- File: migrations/2023-12-14-060824_user_roles_user_status_column/up.sql
-- Your SQL goes here
ALTER TABLE user_roles RENAME COLUMN last_modified_at TO last_modified;
CREATE TYPE "UserStatus" AS ENUM ('active', 'invitation_sent');
ALTER TABLE user_roles ALTER COLUMN status TYPE "UserStatus" USING (status::"UserStatus");
 


-- File: migrations/2023-12-14-101348_alter_dashboard_metadata_key_type/up.sql
-- Your SQL goes here
CREATE TYPE "DashboardMetadata" AS ENUM (
    'production_agreement',
    'setup_processor',
    'configure_endpoint',
    'setup_complete',
    'first_processor_connected',
    'second_processor_connected',
    'configured_routing',
    'test_payment',
    'integration_method',
    'stripe_connected',
    'paypal_connected',
    'sp_routing_configured',
    'sp_test_payment',
    'download_woocom',
    'configure_woocom',
    'setup_woocom_webhook',
    'is_multiple_configuration',
    'configuration_type',
    'feedback',
    'prod_intent'
);

ALTER TABLE dashboard_metadata ALTER COLUMN data_key TYPE "DashboardMetadata" USING (data_key::"DashboardMetadata"); 


-- File: migrations/2023-12-15-062816__net_amount_in_payment_attempt/up.sql
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS net_amount BIGINT;
-- Backfill
UPDATE payment_attempt pa
SET net_amount = pa.amount + COALESCE(pa.surcharge_amount, 0) + COALESCE(pa.tax_amount, 0);
 


-- File: migrations/2023-12-18-062613_create_blocklist_lookup_table/up.sql
-- Your SQL goes here

CREATE TABLE blocklist_lookup (
  id SERIAL PRIMARY KEY,
  merchant_id VARCHAR(64) NOT NULL,
  fingerprint TEXT NOT NULL
);

CREATE UNIQUE INDEX blocklist_lookup_merchant_id_fingerprint_index ON blocklist_lookup (merchant_id, fingerprint);
 


-- File: migrations/2023-12-27-104559_business_profile_add_session_expiry/up.sql
-- Your SQL goes here
ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS session_expiry BIGINT DEFAULT NULL;
 


-- File: migrations/2023-12-28-063619_add_enum_types_to_EventType/up.sql
-- Your SQL goes here
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payment_authorized';
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payment_captured';
 


-- File: migrations/2024-01-02-111223_users_preferred_merchant_column/up.sql
-- Your SQL goes here
ALTER TABLE users ADD COLUMN preferred_merchant_id VARCHAR(64);
 


-- File: migrations/2024-01-04-121733_add_dashboard_metadata_key_integration_completed/up.sql
-- Your SQL goes here
ALTER TYPE "DashboardMetadata" ADD VALUE IF NOT EXISTS 'integration_completed'; 


-- File: migrations/2024-01-29-100008_routing_info_for_payout_attempts/up.sql
-- Your SQL goes here
ALTER TABLE payout_attempt
ALTER COLUMN connector TYPE JSONB USING jsonb_build_object (
    'routed_through', connector, 'algorithm', NULL
);

ALTER TABLE payout_attempt ADD COLUMN routing_info JSONB;

UPDATE payout_attempt
SET
    routing_info = connector -> 'algorithm'
WHERE
    connector ->> 'algorithm' IS NOT NULL;

ALTER TABLE payout_attempt
ALTER COLUMN connector TYPE VARCHAR(64) USING connector ->> 'routed_through';

ALTER TABLE payout_attempt ALTER COLUMN connector DROP NOT NULL;

CREATE type "TransactionType" as ENUM('payment', 'payout');

ALTER TABLE routing_algorithm
ADD COLUMN algorithm_for "TransactionType" DEFAULT 'payment' NOT NULL;

ALTER TABLE routing_algorithm
ALTER COLUMN algorithm_for
DROP DEFAULT; 


-- File: migrations/2024-01-30-090815_alter_payout_type/up.sql
-- Your SQL goes here
ALTER TYPE "PayoutType" ADD VALUE IF NOT EXISTS 'wallet'; 


-- File: migrations/2024-02-05-123412_add_attempt_count_column_to_payouts/up.sql
-- Your SQL goes here
ALTER TABLE payouts
ADD COLUMN attempt_count SMALLINT NOT NULL DEFAULT 1;


UPDATE payouts
SET attempt_count = payout_id_count.count
FROM (SELECT payout_id, count(payout_id) FROM payout_attempt GROUP BY payout_id) as payout_id_count
WHERE payouts.payout_id = payout_id_count.payout_id;
 


-- File: migrations/2024-02-08-142804_add_mandate_data_payment_attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS mandate_data JSONB DEFAULT NULL; 


-- File: migrations/2024-02-12-135546_add_fingerprint_id_in_payment_attempt/up.sql
-- Your SQL goes here
ALTER TABLE payment_attempt ADD COLUMN IF NOT EXISTS fingerprint_id VARCHAR(64);
 


-- File: migrations/2024-02-14-092225_create_roles_table/up.sql
-- Your SQL goes here
CREATE TYPE "RoleScope" AS ENUM ('merchant','organization');

CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    role_name VARCHAR(64) NOT NULL,
    role_id VARCHAR(64) NOT NULL UNIQUE,
    merchant_id VARCHAR(64) NOT NULL,
    org_id VARCHAR(64) NOT NULL,
    groups TEXT[] NOT NULL,
    scope "RoleScope" NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    created_by VARCHAR(64) NOT NULL,
    last_modified_at TIMESTAMP NOT NULL DEFAULT now(),
    last_modified_by VARCHAR(64) NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS role_id_index ON roles (role_id);
CREATE INDEX roles_merchant_org_index ON roles (merchant_id, org_id); 


-- File: migrations/2024-02-15-133957_add_email_to_address/up.sql
-- Your SQL goes here
ALTER TABLE address
ADD COLUMN IF NOT EXISTS email BYTEA;
 


-- File: migrations/2024-02-15-153757_add_dashboard_metadata_enum_is_change_password_required/up.sql
-- Your SQL goes here
ALTER TYPE "DashboardMetadata" ADD VALUE IF NOT EXISTS 'is_change_password_required'; 


-- File: migrations/2024-02-20-142032_add_locker_id_to_payment_methods/up.sql
-- Your SQL goes here

ALTER TABLE payment_methods ADD COLUMN IF NOT EXISTS locker_id VARCHAR(64) DEFAULT NULL; 


-- File: migrations/2024-02-21-120100_add_last_used_at_in_payment_methods/up.sql
-- Your SQL goes here
ALTER TABLE payment_methods ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP; 


-- File: migrations/2024-02-21-143530_add_default_payment_method_in_customers/up.sql
-- Your SQL goes here
ALTER TABLE customers
ADD COLUMN IF NOT EXISTS default_payment_method_id VARCHAR(64); 


-- File: migrations/2024-02-22-060352_add_mit_columns_to_payment_methods/up.sql
-- Your SQL goes here

ALTER TABLE payment_methods
ADD COLUMN connector_mandate_details JSONB
DEFAULT NULL;

ALTER TABLE payment_methods
ADD COLUMN customer_acceptance JSONB
DEFAULT NULL;

ALTER TABLE payment_methods
ADD COLUMN status VARCHAR(64)
NOT NULL DEFAULT 'active';
 


-- File: migrations/2024-02-22-100718_role_name_org_id_constraint/up.sql
-- Your SQL goes here
CREATE UNIQUE INDEX role_name_org_id_org_scope_index ON roles(org_id, role_name) WHERE scope='organization';
CREATE UNIQUE INDEX role_name_merchant_id_merchant_scope_index ON roles(merchant_id, role_name) WHERE scope='merchant';
 


-- File: migrations/2024-02-28-103308_add_dispute_amount_to_dispute/up.sql
-- Your SQL goes here
-- Add the new column with a default value
ALTER TABLE dispute
ADD COLUMN dispute_amount BIGINT NOT NULL DEFAULT 0;

-- Update existing rows to set the default value based on the integer equivalent of the amount column
UPDATE dispute
SET dispute_amount = CAST(amount AS BIGINT);
 

CREATE TABLE IF NOT EXISTS authentication (
    authentication_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(64) NOT NULL,
    authentication_connector VARCHAR(64) NOT NULL,
    connector_authentication_id VARCHAR(64),
    authentication_data JSONB,
    payment_method_id VARCHAR(64) NOT NULL,
    authentication_type VARCHAR(64),
    authentication_status VARCHAR(64) NOT NULL,
    authentication_lifecycle_status VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    modified_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    error_message VARCHAR(64),
    error_code VARCHAR(64),
    PRIMARY KEY (authentication_id)
);
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS external_three_ds_authentication_attempted BOOLEAN default false,
ADD COLUMN IF NOT EXISTS authentication_connector VARCHAR(64),
ADD COLUMN IF NOT EXISTS authentication_id VARCHAR(64);
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS request_external_three_ds_authentication BOOLEAN;
-- Your SQL goes here
ALTER TYPE "ConnectorType" ADD VALUE IF NOT EXISTS 'authentication_processor';
-- Your SQL goes here
ALTER TABLE authentication ADD COLUMN IF NOT EXISTS connector_metadata JSONB DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS payment_method_billing_address_id VARCHAR(64);
-- Your SQL goes here
ALTER TYPE "PaymentSource" ADD VALUE 'webhook';
ALTER TYPE "PaymentSource" ADD VALUE 'external_authenticator';
ALTER TABLE
  PAYOUTS
ADD
  COLUMN profile_id VARCHAR(64);

UPDATE
  PAYOUTS AS PO
SET
  profile_id = POA.profile_id
FROM
  PAYOUT_ATTEMPT AS POA
WHERE
  PO.payout_id = POA.payout_id;

ALTER TABLE
  PAYOUTS
ALTER COLUMN
  profile_id
SET
  NOT NULL;

ALTER TABLE
  PAYOUTS
ADD
  COLUMN status "PayoutStatus";

UPDATE
  PAYOUTS AS PO
SET
  status = POA.status
FROM
  PAYOUT_ATTEMPT AS POA
WHERE
  PO.payout_id = POA.payout_id;

ALTER TABLE
  PAYOUTS
ALTER COLUMN
  status
SET
  NOT NULL;
-- Your SQL goes here
ALTER TABLE business_profile
ADD COLUMN IF NOT EXISTS authentication_connector_details JSONB NULL;
-- The following queries must be run before the newer version of the application is deployed.
ALTER TABLE events
    ADD COLUMN merchant_id VARCHAR(64) DEFAULT NULL,
    ADD COLUMN business_profile_id VARCHAR(64) DEFAULT NULL,
    ADD COLUMN primary_object_created_at TIMESTAMP DEFAULT NULL,
    ADD COLUMN idempotent_event_id VARCHAR(64) DEFAULT NULL,
    ADD COLUMN initial_attempt_id VARCHAR(64) DEFAULT NULL,
    ADD COLUMN request BYTEA DEFAULT NULL,
    ADD COLUMN response BYTEA DEFAULT NULL;

UPDATE events
SET idempotent_event_id = event_id
WHERE idempotent_event_id IS NULL;

UPDATE events
SET initial_attempt_id = event_id
WHERE initial_attempt_id IS NULL;

ALTER TABLE events
ADD CONSTRAINT idempotent_event_id_unique UNIQUE (idempotent_event_id);

-- The following queries must be run after the newer version of the application is deployed.
-- Running these queries can even be deferred for some time (a couple of weeks or even a month) until the
-- new version being deployed is considered stable.
-- Make `event_id` primary key instead of `id`
ALTER TABLE events DROP CONSTRAINT events_pkey;

ALTER TABLE events
ADD PRIMARY KEY (event_id);

ALTER TABLE events DROP CONSTRAINT event_id_unique;

-- Dropping unused columns
ALTER TABLE events
    DROP COLUMN id,
    DROP COLUMN intent_reference_id;
-- Your SQL goes here

ALTER TABLE payment_methods ADD COLUMN network_transaction_id VARCHAR(255) DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE authentication
ADD COLUMN IF NOT EXISTS maximum_supported_version JSONB,
ADD COLUMN IF NOT EXISTS threeds_server_transaction_id VARCHAR(64),
ADD COLUMN IF NOT EXISTS cavv VARCHAR(64),
ADD COLUMN IF NOT EXISTS authentication_flow_type VARCHAR(64),
ADD COLUMN IF NOT EXISTS message_version JSONB,
ADD COLUMN IF NOT EXISTS eci VARCHAR(64),
ADD COLUMN IF NOT EXISTS trans_status VARCHAR(64),
ADD COLUMN IF NOT EXISTS acquirer_bin VARCHAR(64),
ADD COLUMN IF NOT EXISTS acquirer_merchant_id VARCHAR(64),
ADD COLUMN IF NOT EXISTS three_ds_method_data VARCHAR,
ADD COLUMN IF NOT EXISTS three_ds_method_url VARCHAR,
ADD COLUMN IF NOT EXISTS acs_url VARCHAR,
ADD COLUMN IF NOT EXISTS challenge_request VARCHAR,
ADD COLUMN IF NOT EXISTS acs_reference_number VARCHAR,
ADD COLUMN IF NOT EXISTS acs_trans_id VARCHAR,
ADD COLUMN IF NOT EXISTS three_dsserver_trans_id VARCHAR,
ADD COLUMN IF NOT EXISTS acs_signed_content VARCHAR,
ADD COLUMN IF NOT EXISTS connector_metadata JSONB;
-- Your SQL goes here
ALTER TABLE payment_methods ADD COLUMN IF NOT EXISTS client_secret VARCHAR(128) DEFAULT NULL;
ALTER TABLE payment_methods ALTER COLUMN payment_method DROP NOT NULL;
CREATE UNIQUE INDEX events_merchant_id_event_id_index ON events (merchant_id, event_id);

CREATE INDEX events_merchant_id_initial_attempt_id_index ON events (merchant_id, initial_attempt_id);

CREATE INDEX events_merchant_id_initial_events_index ON events (merchant_id, (event_id = initial_attempt_id));

CREATE INDEX events_business_profile_id_initial_attempt_id_index ON events (business_profile_id, initial_attempt_id);

CREATE INDEX events_business_profile_id_initial_events_index ON events (
    business_profile_id,
    (event_id = initial_attempt_id)
);

CREATE TYPE "WebhookDeliveryAttempt" AS ENUM (
    'initial_attempt',
    'automatic_retry',
    'manual_retry'
);

ALTER TABLE events
ADD COLUMN delivery_attempt "WebhookDeliveryAttempt" DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE authentication ADD COLUMN profile_id VARCHAR(64) NOT NULL;
-- Your SQL goes here
ALTER TABLE authentication ADD COLUMN payment_id VARCHAR(255);
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS confirm bool;
ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'requires_vendor_account_creation';
-- Your SQL goes here
ALTER TYPE "DashboardMetadata"
ADD VALUE IF NOT EXISTS 'onboarding_survey';
-- Your SQL goes here
ALTER TABLE merchant_connector_account ADD COLUMN IF NOT EXISTS additional_merchant_data BYTEA DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE authentication ADD COLUMN merchant_connector_id VARCHAR(128) NOT NULL;
CREATE TYPE "GenericLinkType" as ENUM(
    'payment_method_collect',
    'payout_link'
);

CREATE TABLE generic_link (
  link_id VARCHAR (64) NOT NULL PRIMARY KEY,
  primary_reference VARCHAR (64) NOT NULL,
  merchant_id VARCHAR (64) NOT NULL,
  created_at timestamp NOT NULL DEFAULT NOW():: timestamp,
  last_modified_at timestamp NOT NULL DEFAULT NOW():: timestamp,
  expiry timestamp NOT NULL,
  link_data JSONB NOT NULL,
  link_status JSONB NOT NULL,
  link_type "GenericLinkType" NOT NULL,
  url TEXT NOT NULL,
  return_url TEXT NULL
);
ALTER TABLE merchant_account
ADD COLUMN IF NOT EXISTS pm_collect_link_config JSONB NULL;

ALTER TABLE business_profile
ADD COLUMN IF NOT EXISTS payout_link_config JSONB NULL;
-- Your SQL goes here

ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS is_extended_card_info_enabled BOOLEAN DEFAULT FALSE;
-- Your SQL goes here

ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS extended_card_info_config JSONB DEFAULT NULL;
ALTER TABLE fraud_check 
ADD COLUMN IF NOT EXISTS payment_capture_method "CaptureMethod" NULL;
-- Your SQL goes here

ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS is_connector_agnostic_mit_enabled BOOLEAN DEFAULT FALSE;
-- Your SQL goes here
ALTER TABLE authentication ALTER COLUMN error_message TYPE TEXT;
-- Your SQL goes here
ALTER TABLE payment_methods
ADD COLUMN IF NOT EXISTS payment_method_billing_address BYTEA;
-- Your SQL goes here
ALTER TABLE business_profile
ADD COLUMN IF NOT EXISTS use_billing_as_payment_method_billing BOOLEAN DEFAULT TRUE;
-- Your SQL goes here
CREATE TABLE IF NOT EXISTS user_key_store (
    user_id VARCHAR(64) PRIMARY KEY,
    key bytea NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS charges jsonb;

ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS charge_id VARCHAR(64);

ALTER TABLE refund ADD COLUMN IF NOT EXISTS charges jsonb;
-- Your SQL goes here
CREATE TYPE "TotpStatus" AS ENUM (
  'set',
  'in_progress',
  'not_set'
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_status "TotpStatus" DEFAULT 'not_set' NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_secret bytea DEFAULT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_recovery_codes TEXT[] DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_password_modified_at TIMESTAMP;
-- Your SQL goes here
ALTER TABLE authentication DROP COLUMN three_dsserver_trans_id;
-- Your SQL goes here

ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS collect_shipping_details_from_wallet_connector BOOLEAN DEFAULT FALSE;
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS frm_metadata JSONB DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE payment_methods ADD COLUMN IF NOT EXISTS updated_by VARCHAR(64);

ALTER TABLE mandate ADD COLUMN IF NOT EXISTS updated_by VARCHAR(64);

ALTER TABLE customers ADD COLUMN IF NOT EXISTS updated_by VARCHAR(64);
-- Your SQL goes here
ALTER TABLE payment_attempt ADD COLUMN IF NOT EXISTS client_source VARCHAR(64) DEFAULT NULL;
ALTER TABLE payment_attempt ADD COLUMN IF NOT EXISTS client_version VARCHAR(64) DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE payout_attempt ALTER COLUMN connector_payout_id DROP NOT NULL;

UPDATE payout_attempt SET connector_payout_id = NULL WHERE connector_payout_id = '';
-- Your SQL goes here
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payout_success';
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payout_failed';
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payout_processing';
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payout_cancelled';
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payout_initiated';
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payout_expired';
ALTER TYPE "EventType" ADD VALUE IF NOT EXISTS 'payout_reversed';

ALTER TYPE "EventObjectType" ADD VALUE IF NOT EXISTS 'payout_details';

ALTER TYPE "EventClass" ADD VALUE IF NOT EXISTS 'payouts';
-- Your SQL goes here
ALTER TABLE authentication ADD COLUMN IF NOT EXISTS ds_trans_id VARCHAR(64);
-- Your SQL goes here
ALTER TABLE authentication ADD COLUMN IF NOT EXISTS directory_server_id VARCHAR(128);
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'AOA';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'BAM';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'BGN';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'BYN';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'CVE';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'FKP';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'GEL';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'IQD';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'LYD';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'MRU';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'MZN';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'PAB';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'RSD';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'SBD';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'SHP';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'SLE';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'SRD';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'STN';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'TND';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'TOP';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'UAH';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'VES';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'WST';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'XCD';
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'ZMW';
-- Your SQL goes here
ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'initiated';
ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'expired';
ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'reversed';
-- Your SQL goes here
ALTER TABLE merchant_connector_account ADD COLUMN IF NOT EXISTS connector_wallets_details BYTEA DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS payout_link_id VARCHAR(255);
-- Your SQL goes here
ALTER TABLE authentication ADD COLUMN IF NOT EXISTS acquirer_country_code VARCHAR(64);
-- First drop the primary key of payment_intent
ALTER TABLE payment_intent DROP CONSTRAINT payment_intent_pkey;

-- Create new primary key
ALTER TABLE payment_intent
ADD PRIMARY KEY (payment_id, merchant_id);

-- Make the previous primary key as optional
ALTER TABLE payment_intent
ALTER COLUMN id DROP NOT NULL;

-- Follow the same steps for payment attempt as well
ALTER TABLE payment_attempt DROP CONSTRAINT payment_attempt_pkey;

ALTER TABLE payment_attempt
ADD PRIMARY KEY (attempt_id, merchant_id);

ALTER TABLE payment_attempt
ALTER COLUMN id DROP NOT NULL;
-- Your SQL goes here
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS client_secret VARCHAR(128) DEFAULT NULL;

ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'requires_confirmation';
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS priority VARCHAR(32);
CREATE INDEX connector_payout_id_merchant_id_index ON payout_attempt (connector_payout_id, merchant_id);
-- Your SQL goes here
ALTER TABLE users ALTER COLUMN password DROP NOT NULL;
-- Your SQL goes here
CREATE TABLE IF NOT EXISTS user_authentication_methods (
    id VARCHAR(64) PRIMARY KEY,
    auth_id VARCHAR(64) NOT NULL,
    owner_id VARCHAR(64) NOT NULL,
    owner_type VARCHAR(64) NOT NULL,
    auth_type VARCHAR(64) NOT NULL,
    private_config bytea,
    public_config JSONB,
    allow_signup BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    last_modified_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS auth_id_index ON user_authentication_methods (auth_id);
CREATE INDEX IF NOT EXISTS owner_id_index ON user_authentication_methods (owner_id);
-- Your SQL goes here
ALTER TABLE payouts ALTER COLUMN payout_type DROP NOT NULL;
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS customer_details BYTEA DEFAULT NULL;
ALTER TABLE events ADD COLUMN metadata JSONB DEFAULT NULL;
-- Your SQL goes here

ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS collect_billing_details_from_wallet_connector BOOLEAN DEFAULT FALSE;
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS billing_details BYTEA DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS merchant_order_reference_id VARCHAR(255) DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS shipping_details BYTEA DEFAULT NULL;
ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS outgoing_webhook_custom_http_headers BYTEA DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE payment_attempt ADD COLUMN IF NOT EXISTS customer_acceptance JSONB DEFAULT NULL;
-- Your SQL goes here
-- The below query will lock the merchant account table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query is necessary for the application to not use id in update of merchant_account
-- This query should be run after the new version of application is deployed
ALTER TABLE merchant_account DROP CONSTRAINT merchant_account_pkey;

-- Use the `merchant_id` column as primary key
-- This is already a unique, not null column
-- So this query should not fail for not null or duplicate values reasons
ALTER TABLE merchant_account
ADD PRIMARY KEY (merchant_id);
-- Your SQL goes here
-- The below query will lock the dispute table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query is necessary for the application to not use id in update of dispute
-- This query should be run only after the new version of application is deployed
ALTER TABLE dispute DROP CONSTRAINT dispute_pkey;

-- Use the `dispute_id` column as primary key
ALTER TABLE dispute
ADD PRIMARY KEY (dispute_id);
-- Your SQL goes here
-- The below query will lock the mandate table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query is necessary for the application to not use id in update of mandate
-- This query should be run only after the new version of application is deployed
ALTER TABLE mandate DROP CONSTRAINT mandate_pkey;

-- Use the `mandate_id` column as primary key
ALTER TABLE mandate
ADD PRIMARY KEY (mandate_id);
-- Your SQL goes here
-- The below query will lock the merchant connector account table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query should be run only after the new version of application is deployed
ALTER TABLE merchant_connector_account DROP CONSTRAINT merchant_connector_account_pkey;

-- Use the `merchant_connector_id` column as primary key
-- This is not a unique column, but in an ideal scenario there should not be any duplicate keys as this is being generated by the application
-- So this query should not fail for not null or duplicate values reasons
ALTER TABLE merchant_connector_account
ADD PRIMARY KEY (merchant_connector_id);
UPDATE generic_link
SET link_data = jsonb_set(link_data, '{allowed_domains}', '["*"]'::jsonb)
WHERE
    NOT link_data ? 'allowed_domains'
    AND link_type = 'payout_link';
-- Add a new column for allowed domains and secure link endpoint
ALTER table payment_link ADD COLUMN IF NOT EXISTS secure_link VARCHAR(255);
-- Your SQL goes here
-- The below query will lock the blocklist table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query should be run after the new version of application is deployed
ALTER TABLE blocklist DROP CONSTRAINT blocklist_pkey;

-- Use the `merchant_id, fingerprint_id` columns as primary key
-- These are already unique, not null columns
-- So this query should not fail for not null or duplicate value reasons
ALTER TABLE blocklist
ADD PRIMARY KEY (merchant_id, fingerprint_id);
-- Your SQL goes here
ALTER TABLE organization
ADD COLUMN organization_details jsonb,
ADD COLUMN metadata jsonb,
ADD created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
ADD modified_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP;
-- Your SQL goes here
-- The below query will lock the refund table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query should be run after the new version of application is deployed
ALTER TABLE refund DROP CONSTRAINT refund_pkey;

-- Use the `merchant_id, refund_id` columns as primary key
-- These are already unique, not null columns
-- So this query should not fail for not null or duplicate value reasons
ALTER TABLE refund
ADD PRIMARY KEY (merchant_id, refund_id);
-- Your SQL goes here
-- The below query will lock the users table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query should be run after the new version of application is deployed
ALTER TABLE users DROP CONSTRAINT users_pkey;

-- Use the `user_id` columns as primary key
-- These are already unique, not null column
-- So this query should not fail for not null or duplicate value reasons
ALTER TABLE users
ADD PRIMARY KEY (user_id);
-- Your SQL goes here
-- The below query will lock the user_roles table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query should be run after the new version of application is deployed
ALTER TABLE user_roles DROP CONSTRAINT user_roles_pkey;

-- Use the `user_id, merchant_id` columns as primary key
-- These are already unique, not null columns
-- So this query should not fail for not null or duplicate value reasons
ALTER TABLE user_roles
ADD PRIMARY KEY (user_id, merchant_id);
-- Your SQL goes here
-- The below query will lock the user_roles table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query should be run after the new version of application is deployed
ALTER TABLE roles DROP CONSTRAINT roles_pkey;

-- Use the `role_id` column as primary key
-- These are already unique, not null column
-- So this query should not fail for not null or duplicate value reasons
ALTER TABLE roles
ADD PRIMARY KEY (role_id);
-- Your SQL goes here
-- The below query will lock the payment_methods table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query should be run after the new version of application is deployed
ALTER TABLE payment_methods DROP CONSTRAINT payment_methods_pkey;

-- Use the `payment_method_id` column as primary key
-- This is already unique, not null column
-- So this query should not fail for not null or duplicate value reasons
ALTER TABLE payment_methods
ADD PRIMARY KEY (payment_method_id);
-- Your SQL goes here
-- The below query will lock the user_roles table
-- Running this query is not necessary on higher environments
-- as the application will work fine without these queries being run
-- This query should be run after the new version of application is deployed
ALTER TABLE user_roles DROP CONSTRAINT user_roles_pkey;
-- Use the `id` column as primary key
-- This is serial and a not null column
-- So this query should not fail for not null or duplicate value reasons
ALTER TABLE user_roles ADD PRIMARY KEY (id);

ALTER TABLE user_roles ALTER COLUMN org_id DROP NOT NULL;
ALTER TABLE user_roles ALTER COLUMN merchant_id DROP NOT NULL;

ALTER TABLE user_roles ADD COLUMN profile_id VARCHAR(64);
ALTER TABLE user_roles ADD COLUMN entity_id VARCHAR(64);
ALTER TABLE user_roles ADD COLUMN entity_type VARCHAR(64);

CREATE TYPE "UserRoleVersion" AS ENUM('v1', 'v2');
ALTER TABLE user_roles ADD COLUMN version "UserRoleVersion" DEFAULT 'v1' NOT NULL;

-- Add a new column for allowed domains and secure link endpoint
ALTER table payment_link ADD COLUMN IF NOT EXISTS secure_link VARCHAR(255);
-- Your SQL goes here
ALTER TABLE organization
ADD COLUMN id VARCHAR(32);
ALTER TABLE organization
ADD COLUMN organization_name TEXT;
      
-- Your SQL goes here
ALTER TABLE roles ADD COLUMN entity_type VARCHAR(64);

-- Your SQL goes here

CREATE TYPE "ApiVersion" AS ENUM ('v1', 'v2');

ALTER TABLE customers ADD COLUMN IF NOT EXISTS version "ApiVersion" NOT NULL DEFAULT 'v1';
-- Your SQL goes here

ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS always_collect_billing_details_from_wallet_connector BOOLEAN DEFAULT FALSE;
-- Your SQL goes here

ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS always_collect_shipping_details_from_wallet_connector BOOLEAN DEFAULT FALSE;
ALTER TABLE payouts
ALTER COLUMN customer_id
DROP NOT NULL,
ALTER COLUMN address_id
DROP NOT NULL;

ALTER TABLE payout_attempt
ALTER COLUMN customer_id
DROP NOT NULL,
ALTER COLUMN address_id
DROP NOT NULL;
-- Your SQL goes here
ALTER TABLE payment_intent
ADD COLUMN IF NOT EXISTS is_payment_processor_token_flow BOOLEAN;
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS shipping_cost BIGINT;
-- Your SQL goes here
ALTER TABLE user_roles DROP CONSTRAINT user_merchant_unique;
-- Your SQL goes here
ALTER TABLE merchant_account
ADD COLUMN IF NOT EXISTS version "ApiVersion" NOT NULL DEFAULT 'v1';
-- Your SQL goes here
ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS tax_connector_id VARCHAR(64);
ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS is_tax_connector_enabled BOOLEAN;
-- Your SQL goes here
ALTER TABLE merchant_connector_account
ADD COLUMN IF NOT EXISTS version "ApiVersion" NOT NULL DEFAULT 'v1';
CREATE TABLE IF NOT EXISTS unified_translations (
    unified_code VARCHAR(255) NOT NULL,
    unified_message VARCHAR(1024) NOT NULL,
    locale VARCHAR(255) NOT NULL ,
    translation VARCHAR(1024) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    last_modified_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    PRIMARY KEY (unified_code,unified_message,locale)
);
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS profile_id VARCHAR(64) NOT NULL DEFAULT 'default_profile';

-- Add organization_id to payment_attempt table
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS organization_id VARCHAR(32) NOT NULL DEFAULT 'default_org';

-- Add organization_id to payment_intent table
ALTER TABLE payment_intent
ADD COLUMN IF NOT EXISTS organization_id VARCHAR(32) NOT NULL DEFAULT 'default_org';

-- Add organization_id to refund table
ALTER TABLE refund
ADD COLUMN IF NOT EXISTS organization_id VARCHAR(32) NOT NULL DEFAULT 'default_org';

-- Add organization_id to dispute table
ALTER TABLE dispute
ADD COLUMN IF NOT EXISTS organization_id VARCHAR(32) NOT NULL DEFAULT 'default_org';

-- This doesn't work on V2
-- The below backfill step has to be run after the code deployment
-- UPDATE payment_attempt pa
-- SET organization_id = ma.organization_id
-- FROM merchant_account ma
-- WHERE pa.merchant_id = ma.merchant_id;

-- UPDATE payment_intent pi
-- SET organization_id = ma.organization_id
-- FROM merchant_account ma
-- WHERE pi.merchant_id = ma.merchant_id;

-- UPDATE refund r
-- SET organization_id = ma.organization_id
-- FROM merchant_account ma
-- WHERE r.merchant_id = ma.merchant_id;

-- UPDATE payment_attempt pa
-- SET profile_id = pi.profile_id
-- FROM payment_intent pi
-- WHERE pa.payment_id = pi.payment_id
-- AND pa.merchant_id = pi.merchant_id
-- AND pi.profile_id IS NOT NULL;
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS tax_details JSONB;
-- Your SQL goes here

ALTER TABLE payment_attempt ADD COLUMN card_network VARCHAR(32);
UPDATE payment_attempt
SET card_network = (payment_method_data -> 'card' -> 'card_network')::VARCHAR(32);
-- Your SQL goes here
ALTER TYPE "ConnectorType"
ADD VALUE IF NOT EXISTS 'tax_processor';
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS skip_external_tax_calculation BOOLEAN;
-- Your SQL goes here
ALTER TABLE business_profile
ADD COLUMN version "ApiVersion" DEFAULT 'v1' NOT NULL;
-- Your SQL goes here
ALTER TABLE users DROP COLUMN preferred_merchant_id;
-- Your SQL goes here
ALTER TABLE payment_methods
ADD COLUMN IF NOT EXISTS version "ApiVersion" NOT NULL DEFAULT 'v1';
ALTER TABLE payout_attempt
ADD COLUMN IF NOT EXISTS unified_code VARCHAR(255) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS unified_message VARCHAR(1024) DEFAULT NULL;
-- Your SQL goes here
ALTER TYPE "RoutingAlgorithmKind" ADD VALUE 'dynamic';
-- Your SQL goes here
ALTER TABLE
    business_profile
ADD
    COLUMN dynamic_routing_algorithm JSON DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE payment_attempt ADD COLUMN IF NOT EXISTS shipping_cost BIGINT;
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS order_tax_amount BIGINT;
-- Your SQL goes here
ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS is_network_tokenization_enabled BOOLEAN NOT NULL DEFAULT FALSE;
-- Your SQL goes here
ALTER TABLE payment_methods ADD COLUMN IF NOT EXISTS network_token_requestor_reference_id VARCHAR(128) DEFAULT NULL;

ALTER TABLE payment_methods ADD COLUMN IF NOT EXISTS network_token_locker_id VARCHAR(64) DEFAULT NULL;

ALTER TABLE payment_methods ADD COLUMN IF NOT EXISTS network_token_payment_method_data BYTEA DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE payout_attempt 
ADD COLUMN IF NOT EXISTS additional_payout_method_data JSONB DEFAULT NULL;
-- Your SQL goes here
UPDATE user_roles SET entity_type = 'merchant' WHERE entity_type = 'internal';
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS connector_transaction_data VARCHAR(512);

ALTER TABLE refund
ADD COLUMN IF NOT EXISTS connector_refund_data VARCHAR(512);

ALTER TABLE refund
ADD COLUMN IF NOT EXISTS connector_transaction_data VARCHAR(512);

ALTER TABLE captures
ADD COLUMN IF NOT EXISTS connector_capture_data VARCHAR(512);
-- Your SQL goes here
-- Add is_auto_retries_enabled column in business_profile table
ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS is_auto_retries_enabled BOOLEAN;

-- Add max_auto_retries_enabled column in business_profile table
ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS max_auto_retries_enabled SMALLINT;
-- Your SQL goes here
ALTER TABLE payment_attempt
ADD COLUMN connector_mandate_detail JSONB DEFAULT NULL;
-- Your SQL goes here
UPDATE roles SET entity_type = 'merchant' WHERE entity_type IS NULL;

ALTER TABLE roles ALTER COLUMN entity_type SET DEFAULT 'merchant';

ALTER TABLE roles ALTER COLUMN entity_type SET NOT NULL;

-- Your SQL goes here
ALTER TABLE roles ADD COLUMN IF NOT EXISTS profile_id VARCHAR(64);
-- Your SQL goes here
ALTER TYPE "RoleScope"
ADD VALUE IF NOT EXISTS 'profile';
-- Your SQL goes here
ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS tenant_id VARCHAR(64) NOT NULL DEFAULT 'public';
-- Your SQL goes here
ALTER TABLE dispute ADD COLUMN IF NOT EXISTS dispute_currency "Currency";
-- Your SQL goes here
CREATE TABLE IF NOT EXISTS themes (
    theme_id VARCHAR(64) PRIMARY KEY,
    tenant_id VARCHAR(64) NOT NULL,
    org_id VARCHAR(64),
    merchant_id VARCHAR(64),
    profile_id VARCHAR(64),
    created_at TIMESTAMP NOT NULL,
    last_modified_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS themes_index ON themes (
    tenant_id,
    COALESCE(org_id, '0'),
    COALESCE(merchant_id, '0'),
    COALESCE(profile_id, '0')
);
-- Your SQL goes here
CREATE TABLE IF NOT EXISTS callback_mapper (
    id VARCHAR(128) NOT NULL,
    type VARCHAR(64) NOT NULL,
    data JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL,
    last_modified_at TIMESTAMP NOT NULL,
    PRIMARY KEY (id, type)
);
CREATE TYPE "ScaExemptionType" AS ENUM (
    'low_value',
    'transaction_risk_analysis'
);

ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS psd2_sca_exemption_type "ScaExemptionType";
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum
        WHERE enumlabel = 'sequential_automatic'
          AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'CaptureMethod')
    ) THEN
        ALTER TYPE "CaptureMethod" ADD VALUE 'sequential_automatic' AFTER 'manual';
    END IF;
END $$;
-- Your SQL goes here
ALTER TABLE themes ADD COLUMN IF NOT EXISTS entity_type VARCHAR(64) NOT NULL;
ALTER TABLE themes ADD COLUMN IF NOT EXISTS theme_name VARCHAR(64) NOT NULL;
-- Your SQL goes here
ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS split_payments jsonb;
-- Your SQL goes here
ALTER TABLE gateway_status_map ADD COLUMN error_category VARCHAR(64);
-- Your SQL goes here
ALTER TABLE refund ADD COLUMN IF NOT EXISTS split_refunds jsonb;
--- Your SQL goes here
CREATE TYPE "SuccessBasedRoutingConclusiveState" AS ENUM(
  'true_positive',
  'false_positive',
  'true_negative',
  'false_negative'
);

CREATE TABLE IF NOT EXISTS dynamic_routing_stats (
    payment_id VARCHAR(64) NOT NULL,
    attempt_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(64) NOT NULL,
    profile_id VARCHAR(64) NOT NULL,
    amount BIGINT NOT NULL,
    success_based_routing_connector VARCHAR(64) NOT NULL,
    payment_connector VARCHAR(64) NOT NULL,
    currency "Currency",
    payment_method VARCHAR(64),
    capture_method "CaptureMethod",
    authentication_type "AuthenticationType",
    payment_status "AttemptStatus" NOT NULL,
    conclusive_classification "SuccessBasedRoutingConclusiveState" NOT NULL,
    created_at TIMESTAMP NOT NULL,
    PRIMARY KEY(attempt_id, merchant_id)
);
CREATE INDEX profile_id_index ON dynamic_routing_stats (profile_id);
-- Your SQL goes here
-- Incomplete migration, also run migrations/2024-12-13-080558_entity-id-backfill-for-user-roles
UPDATE user_roles
SET
    entity_type = CASE
        WHEN role_id = 'org_admin' THEN 'organization'
        ELSE 'merchant'
    END
WHERE
    version = 'v1'
    AND entity_type IS NULL;
-- Your SQL goes here
ALTER TABLE merchant_account ADD COLUMN IF NOT EXISTS is_platform_account BOOL NOT NULL DEFAULT FALSE;

ALTER TABLE payment_intent ADD COLUMN IF NOT EXISTS platform_merchant_id VARCHAR(64);
-- Your SQL goes here
ALTER TABLE business_profile ADD COLUMN IF NOT EXISTS is_click_to_pay_enabled BOOLEAN NOT NULL DEFAULT FALSE;
-- Your SQL goes here
ALTER TABLE authentication
ADD COLUMN IF NOT EXISTS service_details JSONB
DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE themes ADD COLUMN IF NOT EXISTS email_primary_color VARCHAR(64) NOT NULL DEFAULT '#006DF9';
ALTER TABLE themes ADD COLUMN IF NOT EXISTS email_foreground_color VARCHAR(64) NOT NULL DEFAULT '#000000';
ALTER TABLE themes ADD COLUMN IF NOT EXISTS email_background_color VARCHAR(64) NOT NULL DEFAULT '#FFFFFF';
ALTER TABLE themes ADD COLUMN IF NOT EXISTS email_entity_name VARCHAR(64) NOT NULL DEFAULT 'Hyperswitch';
ALTER TABLE themes ADD COLUMN IF NOT EXISTS email_entity_logo_url TEXT NOT NULL DEFAULT 'https://app.hyperswitch.io/email-assets/HyperswitchLogo.png';
-- Your SQL goes here
ALTER TABLE user_authentication_methods ADD COLUMN email_domain VARCHAR(64);
UPDATE user_authentication_methods SET email_domain = auth_id WHERE email_domain IS NULL;
ALTER TABLE user_authentication_methods ALTER COLUMN email_domain SET NOT NULL;

CREATE INDEX email_domain_index ON user_authentication_methods (email_domain);
-- Your SQL goes here
ALTER TABLE business_profile
ADD COLUMN IF NOT EXISTS authentication_product_ids JSONB NULL;
-- Your SQL goes here
UPDATE user_roles
SET
    entity_id = CASE
        WHEN role_id = 'org_admin' THEN org_id
        ELSE merchant_id
    END
WHERE
    version = 'v1'
    AND entity_id IS NULL;
-- Your SQL goes here
ALTER TABLE dynamic_routing_stats
ADD COLUMN IF NOT EXISTS payment_method_type VARCHAR(64);
-- Your SQL goes here
CREATE TYPE "RelayStatus" AS ENUM ('created', 'pending', 'failure', 'success');

CREATE TYPE "RelayType" AS ENUM ('refund');

CREATE TABLE relay (
    id VARCHAR(64) PRIMARY KEY,
    connector_resource_id VARCHAR(128) NOT NULL,
    connector_id VARCHAR(64) NOT NULL,
    profile_id VARCHAR(64) NOT NULL,
    merchant_id VARCHAR(64) NOT NULL,
    relay_type "RelayType" NOT NULL,
    request_data JSONB DEFAULT NULL,
    status "RelayStatus" NOT NULL,
    connector_reference_id VARCHAR(128),
    error_code VARCHAR(64),
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    modified_at TIMESTAMP NOT NULL DEFAULT now()::TIMESTAMP,
    response_data JSONB DEFAULT NULL
);

-- Your SQL goes here

DROP INDEX IF EXISTS role_name_org_id_org_scope_index;

DROP INDEX IF EXISTS role_name_merchant_id_merchant_scope_index;

DROP INDEX IF EXISTS roles_merchant_org_index;

CREATE INDEX roles_merchant_org_index ON roles (
    org_id,
    merchant_id,
    profile_id
);
-- Your SQL goes here
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum
        WHERE enumlabel = 'non_deterministic'
          AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'SuccessBasedRoutingConclusiveState')
    ) THEN
        ALTER TYPE "SuccessBasedRoutingConclusiveState" ADD VALUE 'non_deterministic';
    END IF;
END $$;
-- Your SQL goes here
ALTER TABLE refund
ADD COLUMN IF NOT EXISTS unified_code VARCHAR(255) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS unified_message VARCHAR(1024) DEFAULT NULL;
-- Your SQL goes here
ALTER TABLE roles ADD COLUMN IF NOT EXISTS tenant_id VARCHAR(64) NOT NULL DEFAULT 'public';
DO $$
  DECLARE currency TEXT;
  BEGIN
    FOR currency IN
      SELECT
        unnest(
          ARRAY ['AFN', 'BTN', 'CDF', 'ERN', 'IRR', 'ISK', 'KPW', 'SDG', 'SYP', 'TJS', 'TMT', 'ZWL']
        ) AS currency
      LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_enum
            WHERE enumlabel = currency
              AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'Currency')
          ) THEN EXECUTE format('ALTER TYPE "Currency" ADD VALUE %L', currency);
        END IF;
      END LOOP;
END $$;
UPDATE roles
SET groups = array_replace(groups, 'recon_ops', 'recon_ops_manage')
WHERE 'recon_ops' = ANY(groups);
-- Your SQL goes here
ALTER TABLE dynamic_routing_stats
ADD COLUMN IF NOT EXISTS global_success_based_connector VARCHAR(64);
-- Your SQL goes here
CREATE UNIQUE INDEX relay_profile_id_connector_reference_id_index ON relay (profile_id, connector_reference_id);
ALTER TABLE payment_attempt
ADD COLUMN IF NOT EXISTS processor_transaction_data TEXT;

ALTER TABLE refund
ADD COLUMN IF NOT EXISTS processor_refund_data TEXT;

ALTER TABLE refund
ADD COLUMN IF NOT EXISTS processor_transaction_data TEXT;

ALTER TABLE captures
ADD COLUMN IF NOT EXISTS processor_capture_data TEXT;
-- Your SQL goes here
CREATE TYPE "CardDiscovery" AS ENUM ('manual', 'saved_card', 'click_to_pay');

ALTER TABLE payment_attempt ADD COLUMN IF NOT EXISTS card_discovery "CardDiscovery";
-- Your SQL goes here
ALTER TABLE authentication
ADD COLUMN IF NOT EXISTS organization_id VARCHAR(32) NOT NULL DEFAULT 'default_org';
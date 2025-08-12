# Local variable for the secrets.
# We are still defining the key-value pairs here.
locals {
  secrets_with_values = {
    kms_admin_api_key                             = "hyperswitch-admin-api-key"
    kms_recon_admin_api_key                       = "hyperswitch-recon-admin-api-key"
    kms_jwt_secret                                = "hyperswitch-jwt-secret"
    kms_encrypted_db_pass                         = "hyperswitch-encrypted-db-pass"
    kms_encrypted_master_key                      = "hyperswitch-encrypted-master-key"
    kms_jwekey_locker_identifier1                 = "hyperswitch-jwekey-locker-identifier1"
    kms_jwekey_locker_identifier2                 = "hyperswitch-jwekey-locker-identifier2"
    kms_jwekey_locker_encryption_key1             = "hyperswitch-jwekey-locker-encryption-key1"
    kms_jwekey_locker_encryption_key2             = "hyperswitch-jwekey-locker-encryption-key2"
    kms_jwekey_locker_decryption_key1             = "hyperswitch-jwekey-locker-decryption-key1"
    kms_jwekey_locker_decryption_key2             = "hyperswitch-jwekey-locker-decryption-key2"
    kms_jwekey_vault_encryption_key               = "hyperswitch-jwekey-vault-encryption-key"
    kms_jwekey_vault_private_key                  = "hyperswitch-jwekey-vault-private-key"
    kms_jwekey_tunnel_private_key                 = "hyperswitch-jwekey-tunnel-private-key"
    kms_jwekey_rust_locker_encryption_key         = "hyperswitch-jwekey-rust-locker-encryption-key"
    kms_connector_onboarding_paypal_client_id     = "hyperswitch-paypal-client-id"
    kms_connector_onboarding_paypal_client_secret = "hyperswitch-paypal-client-secret"
    kms_connector_onboarding_paypal_partner_id    = "hyperswitch-paypal-partner-id"
    kms_forex_api_key                             = "hyperswitch-forex-api-key"
    kms_forex_fallback_api_key                    = "hyperswitch-forex-fallback-api-key"
    apple_pay_ppc                                 = "hyperswitch-apple-pay-ppc"
    apple_pay_ppc_key                             = "hyperswitch-apple-pay-ppc-key"
    apple_pay_merchant_conf_merchant_cert         = "hyperswitch-apple-pay-merchant-cert"
    apple_pay_merchant_conf_merchant_cert_key     = "hyperswitch-apple-pay-merchant-cert-key"
    apple_pay_merchant_conf_merchant_id           = "hyperswitch-apple-pay-merchant-id"
    pm_auth_key                                   = "hyperswitch-pm-auth-key"
    api_hash_key                                  = "hyperswitch-api-hash-key"
    kms_encrypted_api_hash_key                    = "hyperswitch-kms-encrypted-api-hash-key"
    encryption_key                                = "hyperswitch-encryption-key"
    google_pay_root_signing_keys                  = "hyperswitch-google-pay-keys"
    paze_private_key                              = "hyperswitch-paze-private-key"
    paze_private_key_passphrase                   = "hyperswitch-paze-private-key-passphrase"
  }
}

# The secret-manager module call is modified to use a for_each loop.
module "secret-manager" {
  source  = "GoogleCloudPlatform/secret-manager/google"
  version = "~> 0.8"
  project_id = var.project_id
  secrets = [
    for key, value in local.secrets_with_values : {
      name        = key
      secret_data = value
    }
  ]
}
